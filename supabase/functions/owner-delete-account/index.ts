// owner-delete-account: the owner deletes someone's account from the owner console (a user's e-mail request, abuse).
//
// Three checks on the server, none taken from the app:
// 1. the caller is the owner (`is_owner_account`),
// 2. the PIN matches the OWNER_DELETE_PIN secret, which lives only in Supabase (not in the app, not in git), so a
//    stolen session or phone alone deletes nobody; 5 wrong PINs in an hour lock it,
// 3. the owner typed that account's e-mail, so a wrong row in the list cannot be deleted by mistake.
// Every attempt goes to `owner_delete_log`. Deleting is the same as delete-account, except Sign in with Apple:
// revoking needs a code only the user's own device can give, so that link stays in their Apple ID settings.

import {
  corsHeaders,
  errorResponse,
  getAuthenticatedUser,
  getSupabaseAdmin,
  jsonResponse,
} from "../_shared/supabase-client.ts";
import { deleteAccountAndFiles } from "../_shared/account-deletion.ts";

const WRONG_PIN_LIMIT = 5;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Compares two PINs in a time that does not depend on where they differ. */
async function samePin(given: string, expected: string): Promise<boolean> {
  const digest = async (text: string) =>
    new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)));
  const [a, b] = await Promise.all([digest(given), digest(expected)]);
  let difference = 0;
  for (let i = 0; i < a.length; i++) difference |= a[i] ^ b[i];
  return difference === 0;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("invalid_input", "Použi POST.", 405);

  const user = await getAuthenticatedUser(req);
  if (!user) return errorResponse("unauthorized", "Vyžaduje sa prihlásenie.", 401);

  const admin = getSupabaseAdmin();
  const { data: isOwner, error: ownerError } = await admin.rpc("is_owner_account", { p_user: user.id });
  if (ownerError || isOwner !== true) return errorResponse("forbidden", "Toto môže len majiteľ.", 403);

  const expectedPin = Deno.env.get("OWNER_DELETE_PIN") ?? "";
  if (expectedPin.length < 6) {
    return errorResponse("server_error", "PIN na mazanie účtov nie je v Supabase nastavený (aspoň 6 znakov).", 500);
  }

  let body: { targetUserId?: unknown; confirmEmail?: unknown; pin?: unknown } = {};
  try {
    body = await req.json();
  } catch {
    // handled below
  }
  // The app sends Swift's upper-case UUID; auth ids are lower case.
  const targetId = typeof body.targetUserId === "string" ? body.targetUserId.toLowerCase() : "";
  const confirmEmail = typeof body.confirmEmail === "string" ? body.confirmEmail.trim().toLowerCase() : "";
  const pin = typeof body.pin === "string" ? body.pin : "";
  if (!UUID.test(targetId) || !confirmEmail || !pin) {
    return errorResponse("invalid_input", "Chýba účet, e-mail alebo PIN.", 400);
  }
  if (targetId === user.id) return errorResponse("invalid_input", "Vlastný účet sa tu zmazať nedá.", 400);

  const hourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count: wrongPins, error: countError } = await admin
    .from("owner_delete_log")
    .select("id", { count: "exact", head: true })
    .eq("owner_id", user.id)
    .eq("outcome", "wrong_pin")
    .gte("created_at", hourAgo);
  if (countError) {
    console.error("owner-delete-account: reading the log failed:", countError.message);
    return errorResponse("server_error", "Server teraz neodpovedá. Skús to o chvíľu.", 500);
  }
  if ((wrongPins ?? 0) >= WRONG_PIN_LIMIT) {
    return errorResponse("rate_limited", "Priveľa nesprávnych PIN-ov. Skús to znova o hodinu.", 429);
  }

  const { data: target, error: targetError } = await admin.auth.admin.getUserById(targetId);
  if (targetError || !target?.user) return errorResponse("not_found", "Taký účet už neexistuje.", 404);
  if ((target.user.email ?? "").toLowerCase() !== confirmEmail) {
    return errorResponse("invalid_input", "E-mail nesedí s týmto účtom.", 400);
  }

  const log = async (outcome: "wrong_pin" | "deleted" | "failed") => {
    const { error } = await admin.from("owner_delete_log").insert({ owner_id: user.id, target_user_id: targetId, outcome });
    if (error) console.error("owner-delete-account: writing the log failed:", error.message);
  };

  if (!(await samePin(pin, expectedPin))) {
    await log("wrong_pin");
    return errorResponse("forbidden", "Nesprávny PIN.", 403);
  }

  try {
    const removed = await deleteAccountAndFiles(admin, targetId);
    await log("deleted");
    console.log(`owner-delete-account: removed ${removed.files} file(s), ${removed.sharedVideos} shared video(s) and the user`);
    return jsonResponse({ ok: true });
  } catch (err) {
    await log("failed");
    console.error("owner-delete-account failed:", err instanceof Error ? err.message : err);
    return jsonResponse(
      { error: "delete_failed", message: "Účet sa nepodarilo zmazať. Skús to znova." },
      500,
    );
  }
});
