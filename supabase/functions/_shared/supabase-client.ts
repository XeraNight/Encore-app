import { createClient } from "npm:@supabase/supabase-js@2";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, retry-after",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

export interface AuthUser {
  id: string;
  email?: string;
  user_metadata?: Record<string, unknown>;
  /** Sign-in methods linked to the account ("email", "google", "apple"). */
  providers: string[];
}

/**
 * Creates Supabase admin client initialized with service_role key.
 */
export function getSupabaseAdmin() {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "https://iukblwlttvrcdclmlyxu.supabase.co";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!serviceRoleKey) {
    throw new Error("SUPABASE_SERVICE_ROLE_KEY environment variable is not set.");
  }

  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

/**
 * Extracts and verifies the Bearer JWT token from the Authorization header.
 * Returns the authenticated user or null.
 */
export async function getAuthenticatedUser(req: Request): Promise<AuthUser | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return null;
  }

  const token = authHeader.slice(7).trim();
  if (!token) return null;

  try {
    const supabase = getSupabaseAdmin();
    const { data: { user }, error } = await supabase.auth.getUser(token);

    if (error || !user) {
      return null;
    }

    const providers = Array.isArray(user.app_metadata?.providers)
      ? (user.app_metadata.providers as string[])
      : (user.identities ?? []).map((identity) => identity.provider);
    return {
      id: user.id,
      email: user.email,
      user_metadata: user.user_metadata,
      providers,
    };
  } catch {
    return null;
  }
}

/**
 * Standard structured JSON response helper.
 */
export function jsonResponse(data: unknown, status = 200, headers: Record<string, string> = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
      ...headers,
    },
  });
}

/**
 * Standard structured error response helper.
 * Error codes: unauthorized | forbidden | invalid_input | rate_limited | blocked | parse_failed | not_found | not_official | conflict_deleted
 */
export function errorResponse(
  errorCode:
    | "unauthorized"
    | "apple_reauth_required"
    | "forbidden"
    | "invalid_input"
    | "rate_limited"
    | "blocked"
    | "parse_failed"
    | "not_found"
    | "not_official"
    | "conflict_deleted"
    | "server_error"
    | "too_large"
    | "upload_missing"
    | "size_mismatch",
  message: string,
  status = 400,
  extra: Record<string, unknown> = {},
  headers: Record<string, string> = {}
) {
  return new Response(
    JSON.stringify({
      error: errorCode,
      message,
      ...extra,
    }),
    {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json; charset=utf-8",
        ...headers,
      },
    }
  );
}
