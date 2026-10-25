// ksis-page: reads the KSIS page the user has open in the app's KSIS browser and, when asked, saves the
// user's own couple data from it. The app sends only the page (URL + HTML); the server parses it with the
// tested readers in _shared/ksis-pages.ts and never trusts structured data from the app. This server does
// not contact KSIS itself: Cloudflare blocks it (docs/KSIS_SAMPLES_NEEDED.md §1).
//
// POST JSON, one action per call:
//   read          { url, html }            -> { kind, ... }        nothing is stored
//   save          { url, html, consent? }  -> { kind, ..., saved } link the couple, standings, history, a result, crosses
//   unlink        { pairNumber }           -> { ok }                the couple and its results are deleted
//   delete_result { resultId }             -> { ok }
//
// Kinds: couples_list, couple_detail, couple_page, results, marks, registrations, slp_standings, blocked,
// unsupported.
// Only the user's own couple is stored; other couples on the page are read and forgotten.
// Errors: { error, message } with a Slovak message the app shows as is.

import { corsHeaders, errorResponse, getAuthenticatedUser, getSupabaseAdmin, jsonResponse } from "../_shared/supabase-client.ts";
import {
  coupleRounds,
  disciplineOf,
  isSameCouple,
  type KsisCompetition,
  KsisPageError,
  type KsisPairNames,
  parseCoupleDetail,
  parseCouplePage,
  parseCouplesList,
  parseMarks,
  parseRegistrations,
  parseResults,
  parseSlpStandings,
  registeredCategories,
  splitPair,
} from "../_shared/ksis-pages.ts";

const HOST = "szts.ksis.eu";
const MAX_HTML = 2_000_000;
const MAX_COUPLES = 3;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

type Kind = "couples_list" | "couple_detail" | "couple_page" | "results" | "marks" | "registrations" | "slp_standings";

type Body = {
  action?: string;
  url?: string;
  html?: string;
  consent?: boolean;
  pairNumber?: number;
  resultId?: string;
};

interface LinkedCouple {
  id: string;
  pair_number: number | null;
  couple_id: number | null;
  partner_names: string | null;
}

// deno-lint-ignore no-explicit-any
type Admin = any;

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
      case "read":
      case "save":
        return await handlePage(admin, user.id, body);
      case "unlink":
        return await unlink(admin, user.id, body.pairNumber);
      case "delete_result":
        return await deleteResult(admin, user.id, body.resultId);
      default:
        return errorResponse("invalid_input", "Neznáma akcia.", 400);
    }
  } catch (err) {
    console.error("ksis-page failed:", err instanceof Error ? err.message : err);
    return errorResponse("server_error", "Uloženie sa nepodarilo. Skús to znova.", 500);
  }
});

// ── Page dispatch ────────────────────────────────────────────────────────────────────────────────

function kindOf(url: URL): Kind | null {
  if (url.protocol !== "https:" || url.hostname !== HOST) return null;
  switch (url.pathname) {
    case "/menu.php":
      return url.searchParams.get("akcia") === "CZP" ? "couples_list" : null;
    case "/detail_paru.php":
      return "couple_detail";
    case "/par.php":
      return "couple_page";
    case "/sutaz.php":
      return "results";
    case "/hodnot_sut.php":
      return "marks";
    case "/zoznam_prihl.php":
      return "registrations";
    case "/slp_poradie.php":
      return "slp_standings";
    default:
      return null;
  }
}

async function handlePage(admin: Admin, userId: string, body: Body): Promise<Response> {
  if (typeof body.url !== "string" || typeof body.html !== "string") {
    return errorResponse("invalid_input", "Chýba stránka.", 400);
  }
  if (body.html.length > MAX_HTML) return errorResponse("too_large", "Stránka je príliš veľká.", 413);

  let url: URL;
  try {
    url = new URL(body.url);
  } catch {
    return errorResponse("invalid_input", "Neplatná adresa stránky.", 400);
  }
  const kind = kindOf(url);
  if (!kind) return jsonResponse({ kind: "unsupported" });

  const save = body.action === "save";
  const linked = await linkedCouples(admin, userId);
  try {
    switch (kind) {
      case "couples_list":
        return jsonResponse(readCouplesList(body.html, linked));
      case "couple_detail":
        return await coupleDetail(admin, userId, body.html, linked, save, body.consent === true);
      case "couple_page":
        return await couplePage(admin, userId, body.html, linked, save);
      case "results":
        return await results(admin, userId, body.html, linked, save);
      case "marks":
        return await marks(admin, userId, url, body.html, linked, save);
      case "registrations":
        return jsonResponse(readRegistrations(body.html, linked));
      case "slp_standings":
        return jsonResponse(readSlpStandings(body.html, linked));
    }
  } catch (err) {
    if (err instanceof KsisPageError) {
      if (err.kind === "blocked") return jsonResponse({ kind: "blocked" });
      console.error("ksis-page layout:", err.message);
      return errorResponse("parse_failed", "Túto stránku KSIS sa nepodarilo prečítať. Ak sa to opakuje, napíš nám.", 422);
    }
    throw err;
  }
}

// ── The user's couples ───────────────────────────────────────────────────────────────────────────

async function linkedCouples(admin: Admin, userId: string): Promise<LinkedCouple[]> {
  const { data, error } = await admin
    .from("user_couples")
    .select("id, pair_number, couple_id, partner_names")
    .eq("user_id", userId);
  if (error) throw error;
  return data ?? [];
}

/** The linked couple behind a row: by the KSIS couple id, or by both names when the id is not known yet. */
function findOwn(linked: LinkedCouple[], parId: number | null, names: KsisPairNames): LinkedCouple | undefined {
  return linked.find((couple) => parId !== null && couple.couple_id === parId) ??
    linked.find((couple) => couple.partner_names !== null && isSameCouple(splitPair(couple.partner_names), names));
}

async function rememberCoupleId(admin: Admin, own: LinkedCouple, parId: number): Promise<void> {
  if (own.couple_id === parId) return;
  const { error } = await admin.from("user_couples").update({ couple_id: parId, updated_at: new Date().toISOString() }).eq("id", own.id);
  if (error) throw error;
  own.couple_id = parId;
}

function competitionSummary(c: KsisCompetition) {
  return {
    sutazId: c.sutazId,
    eventName: c.eventName,
    category: c.category,
    date: c.date,
    venue: c.venue,
    couples: c.couples,
    advancement: c.advancement,
  };
}

/** Grouping year for the diary. KSIS rules about seasons are not assumed. */
function yearOf(isoDate: string): string {
  return isoDate.slice(0, 4);
}

// ── Couples list ─────────────────────────────────────────────────────────────────────────────────

function readCouplesList(html: string, linked: LinkedCouple[]) {
  const couples = parseCouplesList(html).slice(0, 20).map((row) => ({
    ...row,
    isLinked: linked.some((couple) => couple.pair_number === row.pairNumber),
  }));
  return { kind: "couples_list", couples };
}

// ── Couple detail: link the couple, refresh class, points, finals ───────────────────────────────

async function coupleDetail(admin: Admin, userId: string, html: string, linked: LinkedCouple[], save: boolean, consent: boolean) {
  const detail = parseCoupleDetail(html);
  const partner = `${detail.partner.surname} ${detail.partner.firstName}`.trim();
  const partnerka = `${detail.partnerka.surname} ${detail.partnerka.firstName}`.trim();
  const existing = linked.find((couple) => couple.pair_number === detail.pairNumber);
  const couple = {
    pairNumber: detail.pairNumber,
    partner,
    partnerka,
    club: detail.club,
    ageCategory: detail.ageCategory,
    year: detail.year,
    stt: detail.stt,
    lat: detail.lat,
  };
  if (!save) return jsonResponse({ kind: "couple_detail", couple, isLinked: existing !== undefined });

  if (!existing && !consent) {
    return errorResponse("invalid_input", "Potvrď, že partner(ka) súhlasí so zobrazením spoločných výsledkov.", 400);
  }
  if (!existing && linked.length >= MAX_COUPLES) {
    return errorResponse("forbidden", `Prepojiť sa dajú najviac ${MAX_COUPLES} páry.`, 403);
  }

  const now = new Date().toISOString();
  const row = {
    pair_number: detail.pairNumber,
    partner_names: `${partner} - ${partnerka}`,
    partner_name: `${partner} & ${partnerka}`,
    club: detail.club || null,
    age_category: detail.ageCategory || null,
    stt_class: detail.stt.className || null,
    stt_points: detail.stt.points,
    stt_finals: detail.stt.finals,
    stt_last_change: detail.stt.lastChange,
    lat_class: detail.lat.className || null,
    lat_points: detail.lat.points,
    lat_finals: detail.lat.finals,
    lat_last_change: detail.lat.lastChange,
    ksis_refreshed_at: now,
    updated_at: now,
  };
  const { error } = existing
    ? await admin.from("user_couples").update(row).eq("id", existing.id)
    : await admin.from("user_couples").insert({ ...row, user_id: userId, discipline: "ALL", partner_consent: true });
  if (error) throw error;
  return jsonResponse({ kind: "couple_detail", couple, isLinked: true, saved: 1 });
}

// ── Couple page: the KSIS couple id and the whole history ────────────────────────────────────────

async function couplePage(admin: Admin, userId: string, html: string, linked: LinkedCouple[], save: boolean) {
  const page = parseCouplePage(html);
  const own = findOwn(linked, page.parId, page);
  const couple = {
    parId: page.parId,
    partner: page.partner,
    partnerka: page.partnerka,
    club: page.club,
    ageCategory: page.ageCategory,
    stt: page.stt,
    lat: page.lat,
  };
  // WDSF competitions have no KSIS competition id and no results in KSIS, so they are not stored.
  const stored = page.history.filter((row) => row.sutazId !== null && disciplineOf(row.category) !== null && row.date !== null);
  const competitions = stored.length;
  if (!save) {
    return jsonResponse({ kind: "couple_page", couple, competitions, isOwn: own !== undefined, isLinked: linked.length > 0 });
  }
  if (!own || page.parId === null) {
    return errorResponse("forbidden", "Toto nie je stránka tvojho prepojeného páru.", 403);
  }

  const now = new Date().toISOString();
  const { error: coupleError } = await admin.from("user_couples").update({
    couple_id: page.parId,
    stt_class: page.stt?.className ?? null,
    stt_points: page.stt?.standing?.points ?? null,
    stt_finals: page.stt?.standing?.finals ?? null,
    lat_class: page.lat?.className ?? null,
    lat_points: page.lat?.standing?.points ?? null,
    lat_finals: page.lat?.standing?.finals ?? null,
    ksis_refreshed_at: now,
    updated_at: now,
  }).eq("id", own.id);
  if (coupleError) throw coupleError;

  const rows = stored.flatMap((entry) => {
    const discipline = disciplineOf(entry.category);
    if (!discipline || !entry.date) return [];
    return [{
      user_id: userId,
      sutaz_id: entry.sutazId,
      couple_id: page.parId,
      event_name: entry.eventName,
      category_name: entry.category,
      discipline,
      date: entry.date,
      couple_count: entry.couples ?? 0,
      placement_text: entry.place?.text ?? "",
      placement: entry.place?.from ?? null,
      points_earned: entry.earned?.points ?? 0,
      cumulative_stats: entry.after ? `${entry.after.points}/${entry.after.finals}F` : null,
      cumulative_points: entry.after?.points ?? 0,
      cumulative_finals: entry.after?.finals ?? 0,
      season: yearOf(entry.date),
      source: "auto",
      is_deleted: false,
      deleted_at: null,
      imported_at: now,
    }];
  });
  if (rows.length > 0) {
    const { error } = await admin.from("competition_results").upsert(rows, { onConflict: "user_id,sutaz_id,couple_id" });
    if (error) throw error;
  }
  return jsonResponse({ kind: "couple_page", couple, competitions, isOwn: true, isLinked: true, saved: rows.length });
}

// ── Results: one competition ─────────────────────────────────────────────────────────────────────

async function results(admin: Admin, userId: string, html: string, linked: LinkedCouple[], save: boolean) {
  const page = parseResults(html);
  const competition = competitionSummary(page.competition);
  const row = page.rows.find((candidate) => findOwn(linked, candidate.parId, candidate) !== undefined);
  const own = row ? findOwn(linked, row.parId, row) : undefined;
  const ownRow = row
    ? { parId: row.parId, round: row.round, place: row.place, startNumber: row.startNumber, points: row.points, total: row.total, slp: row.slp }
    : null;
  if (!save) return jsonResponse({ kind: "results", competition, scoring: page.scoring, own: ownRow });

  if (!row || !own) return errorResponse("not_found", "Tvoj prepojený pár v tejto súťaži nie je.", 404);
  const discipline = disciplineOf(page.competition.category);
  if (!discipline || !page.competition.date || page.competition.sutazId === null) {
    return errorResponse("parse_failed", "Pri tejto súťaži chýba disciplína alebo dátum, nedá sa uložiť.", 422);
  }
  await rememberCoupleId(admin, own, row.parId);

  const { error } = await admin.from("competition_results").upsert({
    user_id: userId,
    sutaz_id: page.competition.sutazId,
    couple_id: row.parId,
    event_name: page.competition.eventName,
    category_name: page.competition.category,
    discipline,
    date: page.competition.date,
    couple_count: page.competition.couples ?? page.rows.length,
    placement_text: row.place?.text ?? "",
    placement: row.place?.from ?? null,
    points_earned: row.points ?? 0,
    cumulative_stats: row.total ? `${row.total.points}/${row.total.finals}F` : null,
    cumulative_points: row.total?.points ?? 0,
    cumulative_finals: row.total?.finals ?? 0,
    start_number: row.startNumber,
    season: yearOf(page.competition.date),
    source: "auto",
    is_deleted: false,
    deleted_at: null,
    imported_at: new Date().toISOString(),
  }, { onConflict: "user_id,sutaz_id,couple_id" });
  if (error) throw error;
  return jsonResponse({ kind: "results", competition, scoring: page.scoring, own: ownRow, saved: 1 });
}

// ── Marks: crosses by judge, round by round (also what "live" shows on competition day) ─────────

async function marks(admin: Admin, userId: string, url: URL, html: string, linked: LinkedCouple[], save: boolean) {
  // The other views ("podľa rozhodcov", "podľa párov", "podľa umiestnenia") have a different table.
  const sutazParam = url.searchParams.get("sutaz_id");
  if (["hodn", "typ", "ord"].some((key) => (url.searchParams.get(key) ?? "") !== "")) {
    return jsonResponse({
      kind: "marks",
      needsDefaultView: true,
      defaultUrl: `https://${HOST}/hodnot_sut.php?sutaz_id=${encodeURIComponent(sutazParam ?? "")}`,
    });
  }

  const page = parseMarks(html);
  const entries = page.rounds.flatMap((round) => round.entries);
  const entry = entries.find((candidate) => findOwn(linked, candidate.parId, candidate) !== undefined);
  const own = entry ? findOwn(linked, entry.parId, entry) : undefined;
  const rounds = entry ? coupleRounds(page, entry.parId) : null;
  const judges = [
    ...page.competition.judges.map((judge) => ({ ...judge, hidden: false })),
    ...page.competition.hiddenJudgeLetters.map((letter) => ({ letter, name: null, city: null, hidden: true })),
  ].sort((a, b) => a.letter.localeCompare(b.letter));
  const reply = {
    kind: "marks",
    competition: competitionSummary(page.competition),
    dances: page.dances,
    judges,
    startNumber: entry?.startNumber ?? null,
    rounds,
  };
  if (!save) return jsonResponse(reply);

  if (!entry || !own || !rounds) return errorResponse("not_found", "Tvoj prepojený pár v tomto hodnotení nie je.", 404);
  const sutazId = page.competition.sutazId ?? Number(sutazParam);
  if (!Number.isInteger(sutazId) || sutazId <= 0) {
    return errorResponse("parse_failed", "Pri tomto hodnotení chýba číslo súťaže.", 422);
  }
  await rememberCoupleId(admin, own, entry.parId);

  const { data: existing, error: findError } = await admin
    .from("competition_results")
    .select("id")
    .eq("user_id", userId)
    .eq("sutaz_id", sutazId)
    .eq("couple_id", entry.parId)
    .maybeSingle();
  if (findError) throw findError;
  if (!existing) {
    return errorResponse(
      "not_found",
      "Najprv ulož výsledok tejto súťaže: otvor Výsledkovú listinu alebo stránku svojho páru.",
      404,
      { needsResult: true },
    );
  }
  const { error } = await admin
    .from("competition_results")
    .update({ rounds, judges, start_number: entry.startNumber })
    .eq("id", existing.id);
  if (error) throw error;
  return jsonResponse({ ...reply, saved: 1 });
}

// ── Registrations ────────────────────────────────────────────────────────────────────────────────

function readRegistrations(html: string, linked: LinkedCouple[]) {
  const page = parseRegistrations(html);
  const categories = new Set<string>();
  for (const couple of linked) {
    if (!couple.partner_names) continue;
    for (const name of registeredCategories(page, splitPair(couple.partner_names))) categories.add(name);
  }
  return {
    kind: "registrations",
    event: { name: page.eventName, date: page.date, venue: page.venue },
    categories: [...categories],
    isLinked: linked.length > 0,
  };
}

// ── Slovenský pohár standings: read live, nothing stored ─────────────────────────────────────────

function readSlpStandings(html: string, linked: LinkedCouple[]) {
  const page = parseSlpStandings(html);
  const own = page.entries.find((entry) => findOwn(linked, entry.parId, entry) !== undefined);
  return {
    kind: "slp_standings",
    standings: page,
    ownParId: own?.parId ?? null,
    isLinked: linked.length > 0,
  };
}

// ── Unlink and delete ────────────────────────────────────────────────────────────────────────────

async function unlink(admin: Admin, userId: string, pairNumber: unknown): Promise<Response> {
  const pair = Number(pairNumber);
  if (!Number.isInteger(pair) || pair <= 0) return errorResponse("invalid_input", "Neplatné číslo páru.", 400);

  const { data: row, error } = await admin
    .from("user_couples")
    .select("id, couple_id")
    .eq("user_id", userId)
    .eq("pair_number", pair)
    .maybeSingle();
  if (error) throw error;
  if (!row) return jsonResponse({ ok: true });

  if (row.couple_id !== null) {
    const { error: resultsError } = await admin.from("competition_results").delete().eq("user_id", userId).eq("couple_id", row.couple_id);
    if (resultsError) throw resultsError;
  }
  const { error: deleteError } = await admin.from("user_couples").delete().eq("id", row.id);
  if (deleteError) throw deleteError;
  return jsonResponse({ ok: true });
}

async function deleteResult(admin: Admin, userId: string, resultId: unknown): Promise<Response> {
  if (typeof resultId !== "string" || !UUID.test(resultId)) return errorResponse("invalid_input", "Neplatný výsledok.", 400);
  const { error } = await admin.from("competition_results").delete().eq("id", resultId).eq("user_id", userId);
  if (error) throw error;
  return jsonResponse({ ok: true });
}
