// delete-account: permanently deletes the signed-in user and everything they own.
//
// Why an edge function and not an RPC: Supabase refuses to delete an auth user that owns Storage
// objects, and deleting rows from storage.objects in SQL does not remove the files. So the files
// are removed through the Storage API first, then the auth user (database rows cascade).
//
// Order matters: if cleaning storage fails we stop and the account stays intact, so the app can
// tell the user honestly that nothing was deleted and let them retry.
//
// Sign in with Apple: Apple requires revoking the user's tokens on deletion. An account linked to
// Apple must send `appleAuthorizationCode` (the app re-authorizes with Apple right before); without
// it the function answers `apple_reauth_required` and deletes nothing. A failed revoke is logged
// but does not block the deletion: the user's right to be deleted comes first.

import {
  corsHeaders,
  errorResponse,
  getAuthenticatedUser,
  getSupabaseAdmin,
  jsonResponse,
} from "../_shared/supabase-client.ts";
import { getR2 } from "../_shared/r2.ts";
import { appleRevokeConfig, revokeAppleTokens } from "../_shared/apple-revoke.ts";

const BUCKET = "encore-media";
const PAGE = 100;

// deno-lint-ignore no-explicit-any
async function listAllFiles(admin: any, root: string): Promise<string[]> {
  const files: string[] = [];
  const pending = [root];
  while (pending.length > 0) {
    const dir = pending.pop()!;
    let offset = 0;
    for (;;) {
      const { data, error } = await admin.storage.from(BUCKET).list(dir, { limit: PAGE, offset });
      if (error) throw error;
      if (!data || data.length === 0) break;
      for (const item of data) {
        const path = `${dir}/${item.name}`;
        // Folders come back without an id
        if (item.id === null || item.id === undefined) pending.push(path);
        else files.push(path);
      }
      if (data.length < PAGE) break;
      offset += PAGE;
    }
  }
  return files;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("invalid_input", "Použi POST.", 405);

  const user = await getAuthenticatedUser(req);
  if (!user) return errorResponse("unauthorized", "Vyžaduje sa prihlásenie.", 401);

  // Explicit confirmation so a stray request can never delete an account
  let body: { confirm?: string; appleAuthorizationCode?: string } = {};
  try {
    body = await req.json();
  } catch {
    // handled below
  }
  if (body.confirm !== "DELETE") {
    return errorResponse("invalid_input", "Chýba potvrdenie zmazania.", 400);
  }

  const appleCode = typeof body.appleAuthorizationCode === "string" ? body.appleAuthorizationCode.trim() : "";
  if (user.providers.includes("apple") && !appleCode) {
    return errorResponse("apple_reauth_required", "Na zmazanie účtu sa ešte raz potvrď cez Apple.", 400);
  }

  try {
    const admin = getSupabaseAdmin();

    if (appleCode) {
      const config = appleRevokeConfig();
      if (!config) {
        console.warn("delete-account: Apple secrets are not set, tokens were not revoked");
      } else {
        try {
          await revokeAppleTokens(config, appleCode);
        } catch (err) {
          console.error("delete-account: Apple revoke failed:", err instanceof Error ? err.message : err);
        }
      }
    }

    const files = await listAllFiles(admin, user.id);
    for (let i = 0; i < files.length; i += PAGE) {
      const batch = files.slice(i, i + PAGE);
      const { error } = await admin.storage.from(BUCKET).remove(batch);
      if (error) throw error;
    }

    // Videos shared with partner and coach live in Cloudflare R2. Their rows would cascade away with
    // the user, the files would not, so they go first.
    const { data: shared, error: sharedError } = await admin.from("shared_videos").select("key").eq("owner_id", user.id);
    if (sharedError) throw sharedError;
    if (shared && shared.length > 0) {
      const r2 = getR2();
      for (const row of shared) await r2.remove(row.key);
    }

    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError) throw deleteError;

    console.log(`delete-account: removed ${files.length} file(s), ${shared?.length ?? 0} shared video(s) and the user`);
    return jsonResponse({ ok: true });
  } catch (err) {
    console.error("delete-account failed:", err instanceof Error ? err.message : err);
    return jsonResponse(
      { error: "delete_failed", message: "Účet sa nepodarilo zmazať. Nič nebolo zmazané, skús to znova." },
      500,
    );
  }
});
