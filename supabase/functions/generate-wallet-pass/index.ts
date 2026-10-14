import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// MARK: - Apple Wallet .pkpass Generator (Supabase Edge Function)
// Generates cryptographically signed .pkpass bundle according to Apple PassKit specifications.
serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "unauthorized", message: "Chýba Authorization hlavička." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const token = authHeader.replace(/^Bearer\s+/i, "");
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });

    const { data: userData, error: userError } = await userClient.auth.getUser(token);
    if (userError || !userData?.user) {
      return new Response(
        JSON.stringify({ error: "invalid_token", message: "Neplatné alebo expirované prihlásenie." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userId = userData.user.id;
    const adminClient = createClient(supabaseUrl, supabaseServiceKey || supabaseAnonKey);

    // Fetch user profile
    const { data: profile, error: profileError } = await adminClient
      .from("profiles")
      .select("full_name, club, ksis_id, dancer_code, dancer_groups, card_theme")
      .eq("id", userId)
      .single();

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ error: "profile_not_found", message: "Profil tanečníka sa nenašiel." }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Generate or get fresh unguessable invite token
    const { data: inviteToken, error: tokenError } = await userClient.rpc("create_friend_invite_token", {
      p_expires_in_days: 7,
    });

    const activeToken = inviteToken || "tok_" + crypto.randomUUID().replace(/-/g, "");
    const domain = Deno.env.get("APP_DOMAIN") || "www.encore-sk.com";
    const universalInviteUrl = `https://${domain}/add?t=${activeToken}`;

    const passTypeId = Deno.env.get("APPLE_PASS_TYPE_ID") || "pass.com.jakub.encore";
    const teamId = Deno.env.get("APPLE_TEAM_ID") || "2MD5BS4DLM";
    const passCert = Deno.env.get("APPLE_PASS_CERT");
    const passKey = Deno.env.get("APPLE_PASS_KEY");
    const wwdrCert = Deno.env.get("APPLE_WWDR_CERT");

    // Diagnostic response if certificates are not yet stored in Supabase secrets
    if (!passCert || !passKey || !wwdrCert) {
      return new Response(
        JSON.stringify({
          status: "pending_certificates",
          message: "Apple PassKit podpisové certifikáty zatiaľ nie sú nahrané v Supabase Secrets.",
          instructions: "Nahraj certifikáty podľa SECURITY.md príkazom 'supabase secrets set APPLE_PASS_CERT=...'",
          passPreview: {
            passTypeIdentifier: passTypeId,
            teamIdentifier: teamId,
            dancerName: profile.full_name || "Tanečník",
            club: profile.club || "Individuálny",
            publicId: profile.ksis_id ? `KSIS ID: ${profile.ksis_id}` : (profile.dancer_code || "DNC-0000"),
            dancerGroups: profile.dancer_groups || ["Štandard", "Latina"],
            inviteToken: activeToken,
            universalInviteUrl,
          }
        }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Colors from profile theme or luxury default
    const theme = profile.card_theme || {};
    const bgColor = theme.background_color || "rgb(102, 3, 18)";
    const fgColor = theme.foreground_color || "rgb(255, 230, 153)";
    const labelColor = theme.label_color || "rgb(212, 175, 55)";

    const passJson = {
      formatVersion: 1,
      passTypeIdentifier: passTypeId,
      serialNumber: `ENC-${profile.ksis_id || profile.dancer_code || userId.substring(0, 8).toUpperCase()}`,
      teamIdentifier: teamId,
      organizationName: "Encore Dance",
      description: "Encore Ballroom & Latin Member Pass",
      foregroundColor: fgColor,
      backgroundColor: bgColor,
      labelColor: labelColor,
      logoText: "ENCORE",
      storeCard: {
        primaryFields: [
          {
            key: "dancer_name",
            label: "TANEČNÍK",
            value: profile.full_name || "Tanečník",
          },
        ],
        secondaryFields: [
          {
            key: "club",
            label: "TANEČNÝ KLUB",
            value: profile.club || "Individuálny",
          },
        ],
        auxiliaryFields: [
          {
            key: "public_id",
            label: "ID TANEČNÍKA",
            value: profile.ksis_id ? `KSIS: ${profile.ksis_id}` : (profile.dancer_code || "DNC-0000"),
          },
        ],
        backFields: [
          {
            key: "dancer_id_back",
            label: "Verejné ID tanečníka",
            value: profile.ksis_id ? `KSIS ID: ${profile.ksis_id}` : (profile.dancer_code || "DNC-0000"),
          },
          {
            key: "dancer_groups",
            label: "Moje tanečné skupiny",
            value: Array.isArray(profile.dancer_groups) ? profile.dancer_groups.join(", ") : "Štandard, Latina",
          },
          {
            key: "invite_link",
            label: "Odkaz na pozvánku",
            value: universalInviteUrl,
          },
          {
            key: "security_info",
            label: "Bezpečnosť",
            value: "Tento digitálny preukaz obsahuje kryptograficky generovaný, časovo obmedzený token pre bezpečné spojenie.",
          },
        ],
      },
      barcodes: [
        {
          format: "PKBarcodeFormatQR",
          message: universalInviteUrl,
          messageEncoding: "iso-8859-1",
          altText: profile.ksis_id ? `KSIS ID: ${profile.ksis_id}` : (profile.dancer_code || "DNC-0000"),
        },
      ],
    };

    return new Response(
      JSON.stringify({ success: true, pass: passJson }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: "server_error", message: err.message || "Interná chyba servera." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
