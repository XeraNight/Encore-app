// media-share: videos shared with partner and coach, stored in Cloudflare R2.
//
// The app never holds R2 keys. This function decides who may upload or watch and hands out
// short-lived presigned links; the video bytes go straight between the iPhone and R2.
// The original video always stays in the owner's Fotky; R2 keeps only the 720p copy.
//
// POST JSON, one action per call:
//   upload   { nodeId, sizeBytes } -> { key, uploadUrl, expiresIn }   limit per plan checked first
//   confirm  { key }               -> { videoPath, usedBytes, quotaBytes }  file checked, figure updated
//   download { key }               -> { downloadUrl, expiresIn }      owner, partner or coach only
//   remove   { key }               -> { ok }                          owner only
//
// Errors: { error, message } with a Slovak message the app can show as is.

import { errorResponse, getAuthenticatedUser, getSupabaseAdmin, jsonResponse, corsHeaders } from "../_shared/supabase-client.ts";
import { getR2 } from "../_shared/r2.ts";

const MAX_BYTES = 100 * 1024 * 1024;   // same as the canvas_nodes / bucket limit
const UPLOAD_TTL = 15 * 60;
const DOWNLOAD_TTL = 60 * 60;
const STALE_PENDING_MS = 60 * 60 * 1000;
const MAX_PENDING = 3;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const KEY = /^[0-9a-f-]{36}\/[0-9a-f-]{36}\.mp4$/;

type Body = { action?: string; nodeId?: string; sizeBytes?: number; key?: string };

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("invalid_input", "Použi POST.", 405);

  const user = await getAuthenticatedUser(req);
  if (!user) return errorResponse("unauthorized", "Vyžaduje sa prihlásenie.", 401);

  let body: Body = {};
  try {
    body = await req.json();
  } catch {
    return errorResponse("invalid_input", "Neplatná požiadavka.", 400);
  }

  try {
    const admin = getSupabaseAdmin();

    const { data: profile } = await admin.from("profiles").select("account_status").eq("id", user.id).maybeSingle();
    if (profile?.account_status === "banned" || profile?.account_status === "suspended") {
      return errorResponse("forbidden", "Tvoj účet je zablokovaný.", 403);
    }

    switch (body.action) {
      case "upload": return await upload(admin, user.id, body);
      case "confirm": return await confirm(admin, user.id, body);
      case "download": return await download(admin, user.id, body);
      case "remove": return await remove(admin, user.id, body);
      default: return errorResponse("invalid_input", "Neznáma akcia.", 400);
    }
  } catch (err) {
    console.error("media-share failed:", err instanceof Error ? err.message : err);
    return errorResponse("server_error", "Zdieľanie videa sa nepodarilo. Skús to znova.", 500);
  }
});

// deno-lint-ignore no-explicit-any
type Admin = any;

/** The figure must belong to a routine of this user. */
async function ownsNode(admin: Admin, userId: string, nodeId: string): Promise<boolean> {
  const { data } = await admin
    .from("canvas_nodes")
    .select("id, routines!inner(user_id)")
    .eq("id", nodeId)
    .eq("routines.user_id", userId)
    .maybeSingle();
  return data !== null;
}

async function usage(admin: Admin, userId: string, exceptNodeId?: string) {
  const { data, error } = await admin.from("shared_videos").select("size_bytes, canvas_node_id").eq("owner_id", userId);
  if (error) throw error;
  // A replaced video of the same figure is deleted on confirm, so it does not count against the new one.
  const used = (data ?? [])
    .filter((row: { canvas_node_id: string | null }) => !exceptNodeId || row.canvas_node_id !== exceptNodeId)
    .reduce((sum: number, row: { size_bytes: number }) => sum + Number(row.size_bytes), 0);
  const { data: quota, error: quotaError } = await admin.rpc("shared_video_quota_bytes", { p_user: userId });
  if (quotaError) throw quotaError;
  return { used, quota: Number(quota) };
}

/** Removes the user's abandoned uploads and copies whose figure was deleted. */
async function cleanUp(admin: Admin, userId: string) {
  const r2 = getR2();
  const staleBefore = new Date(Date.now() - STALE_PENDING_MS).toISOString();
  const { data } = await admin
    .from("shared_videos")
    .select("key")
    .eq("owner_id", userId)
    .or(`and(status.eq.pending,created_at.lt.${staleBefore}),canvas_node_id.is.null`);
  for (const row of data ?? []) {
    await r2.remove(row.key);
    await admin.from("shared_videos").delete().eq("key", row.key);
  }
}

async function upload(admin: Admin, userId: string, body: Body) {
  const nodeId = body.nodeId ?? "";
  const size = Number(body.sizeBytes);
  if (!UUID.test(nodeId)) return errorResponse("invalid_input", "Chýba figúra.", 400);
  if (!Number.isInteger(size) || size <= 0) return errorResponse("invalid_input", "Neplatná veľkosť videa.", 400);
  if (size > MAX_BYTES) return errorResponse("too_large", "Video je väčšie ako 100 MB. Skráť ho a skús znova.", 413);
  if (!(await ownsNode(admin, userId, nodeId))) {
    return errorResponse("forbidden", "Zdieľať môžeš len videá vo svojich zostavách.", 403);
  }

  await cleanUp(admin, userId);

  const { count } = await admin
    .from("shared_videos")
    .select("key", { count: "exact", head: true })
    .eq("owner_id", userId)
    .eq("status", "pending");
  if ((count ?? 0) >= MAX_PENDING) {
    return errorResponse("rate_limited", "Počkaj, kým sa dokončia rozbehnuté nahrávania.", 429);
  }

  const { used, quota } = await usage(admin, userId, nodeId);
  if (used + size > quota) {
    return jsonResponse({
      error: "quota_exceeded",
      message: "Miesto na zdieľané videá je plné. Zruš zdieľanie starších videí alebo si zvýš plán.",
      usedBytes: used,
      quotaBytes: quota,
    }, 413);
  }

  const key = `${userId}/${crypto.randomUUID()}.mp4`;
  const { error } = await admin.from("shared_videos").insert({
    key, owner_id: userId, canvas_node_id: nodeId, size_bytes: size, status: "pending",
  });
  if (error) throw error;

  const uploadUrl = await getR2().presign(key, "PUT", UPLOAD_TTL, {
    "content-type": "video/mp4",
    "content-length": String(size),
  });
  return jsonResponse({ key, uploadUrl, expiresIn: UPLOAD_TTL });
}

async function confirm(admin: Admin, userId: string, body: Body) {
  const key = body.key ?? "";
  if (!KEY.test(key)) return errorResponse("invalid_input", "Neplatné video.", 400);

  const { data: row } = await admin
    .from("shared_videos")
    .select("key, owner_id, canvas_node_id, size_bytes, status")
    .eq("key", key)
    .maybeSingle();
  if (!row || row.owner_id !== userId) return errorResponse("not_found", "Video sa nenašlo.", 404);
  if (row.canvas_node_id && !(await ownsNode(admin, userId, row.canvas_node_id))) {
    return errorResponse("forbidden", "Zdieľať môžeš len videá vo svojich zostavách.", 403);
  }

  const r2 = getR2();
  const actual = await r2.size(key);
  if (actual === null) return errorResponse("upload_missing", "Nahrávanie sa nedokončilo. Skús to znova.", 409);
  if (actual > MAX_BYTES || actual > Number(row.size_bytes)) {
    await r2.remove(key);
    await admin.from("shared_videos").delete().eq("key", key);
    return errorResponse("size_mismatch", "Video sa nepodarilo overiť. Skús to znova.", 400);
  }

  const { error } = await admin.from("shared_videos").update({ status: "ready", size_bytes: actual }).eq("key", key);
  if (error) throw error;

  // The figure now points at this copy; this user's older copy of the same figure is deleted (never anyone else's).
  const videoPath = `r2:${key}`;
  if (row.canvas_node_id) {
    const { data: older } = await admin
      .from("shared_videos")
      .select("key")
      .eq("canvas_node_id", row.canvas_node_id)
      .eq("owner_id", userId)
      .neq("key", key);
    for (const old of older ?? []) {
      await r2.remove(old.key);
      await admin.from("shared_videos").delete().eq("key", old.key);
    }
    await admin.from("canvas_nodes").update({ video_path: videoPath }).eq("id", row.canvas_node_id);
  }

  const { used, quota } = await usage(admin, userId);
  return jsonResponse({ videoPath, usedBytes: used, quotaBytes: quota });
}

async function download(admin: Admin, userId: string, body: Body) {
  const key = body.key ?? "";
  if (!KEY.test(key)) return errorResponse("invalid_input", "Neplatné video.", 400);

  const { data: allowed, error } = await admin.rpc("can_view_shared_video", { p_key: key, p_viewer: userId });
  if (error) throw error;
  if (!allowed) return errorResponse("forbidden", "Toto video ti nebolo zdieľané.", 403);

  const downloadUrl = await getR2().presign(key, "GET", DOWNLOAD_TTL);
  return jsonResponse({ downloadUrl, expiresIn: DOWNLOAD_TTL });
}

async function remove(admin: Admin, userId: string, body: Body) {
  const key = body.key ?? "";
  if (!KEY.test(key)) return errorResponse("invalid_input", "Neplatné video.", 400);

  const { data: row } = await admin.from("shared_videos").select("owner_id").eq("key", key).maybeSingle();
  if (!row || row.owner_id !== userId) return errorResponse("not_found", "Video sa nenašlo.", 404);

  await getR2().remove(key);
  await admin.from("shared_videos").delete().eq("key", key);
  await admin.from("canvas_nodes").update({ video_path: null }).eq("video_path", `r2:${key}`);
  return jsonResponse({ ok: true });
}
