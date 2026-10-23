// delete-account: permanently deletes the signed-in user and everything they own
// (`_shared/account-deletion.ts`). If cleaning storage fails the account stays intact, so the app can
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
import { appleRevokeConfig, revokeAppleTokens } from "../_shared/apple-revoke.ts";
import { deleteAccountAndFiles } from "../_shared/account-deletion.ts";

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

    const removed = await deleteAccountAndFiles(admin, user.id);
    console.log(`delete-account: removed ${removed.files} file(s), ${removed.sharedVideos} shared video(s) and the user`);
    return jsonResponse({ ok: true });
  } catch (err) {
    console.error("delete-account failed:", err instanceof Error ? err.message : err);
    return jsonResponse(
      { error: "delete_failed", message: "Účet sa nepodarilo zmazať. Nič nebolo zmazané, skús to znova." },
      500,
    );
  }
});
