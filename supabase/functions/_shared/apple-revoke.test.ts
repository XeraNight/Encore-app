// Run: deno test supabase/functions/_shared/apple-revoke.test.ts
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { appleClientSecret } from "./apple-revoke.ts";

function fromBase64url(text: string): Uint8Array<ArrayBuffer> {
  const padded = text.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(text.length / 4) * 4, "=");
  return Uint8Array.from(atob(padded), (char) => char.charCodeAt(0));
}

Deno.test("client secret is an ES256 JWT Apple can verify with the key's public half", async () => {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let binary = "";
  for (const byte of pkcs8) binary += String.fromCharCode(byte);
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(binary)}\n-----END PRIVATE KEY-----`;

  const jwt = await appleClientSecret(
    { teamId: "2MD5BS4DLM", keyId: "ABC123DEFG", clientId: "com.jakub.encore", privateKey: pem },
    1_800_000_000,
  );
  const [header, payload, signature] = jwt.split(".");

  assertEquals(JSON.parse(new TextDecoder().decode(fromBase64url(header))), { alg: "ES256", kid: "ABC123DEFG" });
  assertEquals(JSON.parse(new TextDecoder().decode(fromBase64url(payload))), {
    iss: "2MD5BS4DLM",
    iat: 1_800_000_000,
    exp: 1_800_000_300,
    aud: "https://appleid.apple.com",
    sub: "com.jakub.encore",
  });
  const valid = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    pair.publicKey,
    fromBase64url(signature),
    new TextEncoder().encode(`${header}.${payload}`),
  );
  assertEquals(valid, true);
});
