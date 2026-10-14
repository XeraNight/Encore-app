// Revokes a user's Sign in with Apple tokens, as Apple requires when an account is deleted
// (App Review guideline 5.1.1(v), "Revoke tokens" in the Sign in with Apple REST API).
//
// The app re-authorizes with Apple right before deletion and sends the fresh `authorizationCode`.
// Here it is exchanged for a refresh token, which is then revoked. Both calls are authenticated
// with a short-lived client secret: a JWT signed (ES256) with the Sign in with Apple key (.p8).
//
// Secrets: APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY (contents of the .p8 file),
// APPLE_CLIENT_ID (the app's bundle id, com.jakub.encore).

const APPLE = "https://appleid.apple.com";

export interface AppleRevokeConfig {
  teamId: string;
  keyId: string;
  clientId: string;
  privateKey: string;
}

/** The configuration from the function secrets, or null while they are not set. */
export function appleRevokeConfig(): AppleRevokeConfig | null {
  const teamId = Deno.env.get("APPLE_TEAM_ID");
  const keyId = Deno.env.get("APPLE_KEY_ID");
  const clientId = Deno.env.get("APPLE_CLIENT_ID");
  const privateKey = Deno.env.get("APPLE_PRIVATE_KEY");
  if (!teamId || !keyId || !clientId || !privateKey) return null;
  return { teamId, keyId, clientId, privateKey };
}

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** ES256 JWT that Apple accepts as `client_secret` for five minutes. */
export async function appleClientSecret(config: AppleRevokeConfig, now = Math.floor(Date.now() / 1000)): Promise<string> {
  const pem = config.privateKey.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (char) => char.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const encode = (value: unknown) => base64url(new TextEncoder().encode(JSON.stringify(value)));
  const input = `${encode({ alg: "ES256", kid: config.keyId })}.${encode({
    iss: config.teamId,
    iat: now,
    exp: now + 300,
    aud: APPLE,
    sub: config.clientId,
  })}`;
  // WebCrypto returns the raw r||s signature, which is exactly what JWT ES256 expects.
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(input));
  return `${input}.${base64url(new Uint8Array(signature))}`;
}

async function postForm(path: string, form: Record<string, string>): Promise<Response> {
  return await fetch(`${APPLE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(form),
  });
}

/** Exchanges the authorization code and revokes the resulting refresh token. Throws on failure. */
export async function revokeAppleTokens(config: AppleRevokeConfig, authorizationCode: string): Promise<void> {
  const clientSecret = await appleClientSecret(config);
  const tokenResponse = await postForm("/auth/token", {
    client_id: config.clientId,
    client_secret: clientSecret,
    code: authorizationCode,
    grant_type: "authorization_code",
  });
  if (!tokenResponse.ok) throw new Error(`Apple token exchange failed (${tokenResponse.status})`);
  const tokens = await tokenResponse.json() as { refresh_token?: string; access_token?: string };
  const token = tokens.refresh_token ?? tokens.access_token;
  if (!token) throw new Error("Apple token exchange returned no token");

  const revokeResponse = await postForm("/auth/revoke", {
    client_id: config.clientId,
    client_secret: clientSecret,
    token,
    token_type_hint: tokens.refresh_token ? "refresh_token" : "access_token",
  });
  if (!revokeResponse.ok) throw new Error(`Apple revoke failed (${revokeResponse.status})`);
}
