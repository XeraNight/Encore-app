// ksis-page: reads the KSIS page the user has open in the app's KSIS browser and, when asked, saves the
// user's own couple data from it. The app sends only the page (URL + HTML); the server parses it with the
// tested readers in _shared/ksis-pages.ts and never trusts structured data from the app. This server does
// not contact KSIS itself: Cloudflare blocks it (docs/KSIS_SAMPLES_NEEDED.md §1).
//
// POST JSON, one action per call:
//   read          { url, html }            -> { kind, ... }        nothing is stored
//   save          { url, html, consent? }  -> { kind, ..., saved } link the couple, standings, history, a result, crosses
//   save          { url, html, personNumber } on the members list: "Toto som ja"
//   save          { url, html, consent?, parIds?, otherName? } on the search: the dancer's couples and their KSIS
//                                           ids, also under another name they danced as (a maiden name); new couples
//                                           only those in parIds, and only with consent
//   unlink        { coupleId }             -> { ok }                that couple and its results are deleted
//   delete_result { resultId }             -> { ok }
//
// Kinds: members_list, couples_list, search, couple_detail, couple_page, results, marks, registrations, slp_standings,
// blocked, unsupported.
// Only the user's own couples are stored; other couples and members on the page are read and forgotten.
// Who the account is: the dancer picks themselves in the members list (ksis_dancers; no verification since
// 20261031_ksis_without_verification, the owner unlinks a fake on a report). Their couples follow from KSIS: the couple's
// number is the partner's personal number, a partnerka is found by her name. Couples are a history with one current.
// Errors: { error, message } with a Slovak message the app shows as is.

import { countNewResults, resultKey } from "../_shared/ksis-limit.ts";
import {
  corsHeaders,
  errorResponse,
  getAuthenticatedUser,
  getSupabaseAdmin,
  jsonResponse,
} from "../_shared/supabase-client.ts";
import {
  coupleRounds,
  disciplineOf,
  historyToStore,
  isPlausibleDate,
  isSameCouple,
  type KsisCompetition,
  KsisPageError,
  type KsisPairNames,
  normalizeDancerName,
  parseCoupleDetail,
  parseCouplePage,
  parseCouplesList,
  parseMarks,
  parseMembersList,
  parseRegistrations,
  parseResults,
  parseSearchResults,
  parseSlpStandings,
  registeredCategories,
  type KsisSearchCouple,
  sideInCouple,
  sideInPair,
  splitPair,
  type StoredHistoryRow,
} from "../_shared/ksis-pages.ts";

const HOST = "szts.ksis.eu";
const MAX_HTML = 2_000_000;
/** The body is the page as JSON: at most a few bytes per character. Larger is not read at all. */
const MAX_BODY = 6_000_000;
/** One dancer's update is about a hundred calls and browsing KSIS adds some; a script is stopped well above that. */
const RATE_MAX = 240;
const RATE_WINDOW = "10 minutes";
/** A dancer has a few hundred results and about ten couples in a career. */
const MAX_RESULTS_PER_USER = 2000;
const MAX_COUPLES_PER_USER = 15;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

type Kind = "members_list" | "couples_list" | "search" | "couple_detail" | "couple_page" | "results" | "marks" | "registrations" | "slp_standings";

type Body = {
  action?: string;
  url?: string;
  html?: string;
  consent?: boolean;
  /** "Toto som ja" on the members list. */
  personNumber?: number;
  /** The new couples the dancer ticked on the search; their other couples are saved without asking. */
  parIds?: unknown;
  /** Another name the dancer danced as, "Priezvisko Meno" (a maiden name), for the search. */
  otherName?: unknown;
  /** The saved couple to unlink (user_couples.id). */
  coupleId?: string;
  resultId?: string;
};

interface LinkedCouple {
  id: string;
  pair_number: number | null;
  couple_id: number | null;
  partner_names: string | null;
  side: string | null;
  couple_key: string | null;
  is_current: boolean;
}

interface Dancer {
  person_number: number;
  name: string;
}

// deno-lint-ignore no-explicit-any
type Admin = any;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("invalid_input", "Použi POST.", 405);

  const user = await getAuthenticatedUser(req);
  if (!user) return errorResponse("unauthorized", "Vyžaduje sa prihlásenie.", 401);
  if (Number(req.headers.get("content-length") ?? 0) > MAX_BODY) {
    return errorResponse("too_large", "Stránka je príliš veľká.", 413);
  }

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
    if (!await withinRateLimit(admin, user.id)) {
      return errorResponse("rate_limited", "Čítaš príliš rýchlo. Počkaj chvíľu a skús to znova.", 429);
    }

    switch (body.action) {
      case "read":
      case "save":
        return await handlePage(admin, user.id, body);
      case "unlink":
        return await unlink(admin, user.id, body.coupleId);
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

/** Counts the call. The limit protects this function: when counting itself fails, the dancer's update goes on. */
async function withinRateLimit(admin: Admin, userId: string): Promise<boolean> {
  const { error } = await admin.rpc("check_user_rate_limit", {
    p_user: userId,
    p_action: "ksis_page",
    p_max: RATE_MAX,
    p_window: RATE_WINDOW,
  });
  if (!error) return true;
  if (error.hint === "rate_limited") return false;
  console.error("ksis-page rate limit check failed:", error.message);
  return true;
}

/** Room for `adding` more couples of this dancer, or the answer that says there is none. */
function tooManyCouples(linked: LinkedCouple[], adding: number): Response | null {
  if (adding === 0 || linked.length + adding <= MAX_COUPLES_PER_USER) return null;
  return errorResponse("too_large", "Máš uložených príliš veľa párov.", 413);
}

// ── Page dispatch ────────────────────────────────────────────────────────────────────────────────

function kindOf(url: URL): Kind | null {
  if (url.protocol !== "https:" || url.hostname !== HOST || url.port !== "" || url.username !== "" || url.password !== "") {
    return null;
  }
  switch (url.pathname) {
    case "/menu.php":
      switch (url.searchParams.get("akcia")) {
        case "CZ":
          return "members_list";
        case "CZP":
          return "couples_list";
        default:
          return null;
      }
    case "/search.php":
      return "search";
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
  const consent = body.consent === true;
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
  const [linked, dancer] = await Promise.all([linkedCouples(admin, userId), dancerOf(admin, userId)]);
  try {
    switch (kind) {
      case "members_list":
        return await membersList(admin, userId, body.html, dancer, save, body.personNumber);
      case "couples_list":
        return await couplesList(admin, userId, body.html, linked, dancer, save, consent);
      case "search":
        return await search(admin, userId, body.html, linked, dancer, save, consent, body.parIds, body.otherName);
      case "couple_detail":
        return await coupleDetail(admin, userId, body.html, linked, dancer, save, consent);
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
      const which = err.page ? `Stránku „${err.page}“` : "Túto stránku";
      return errorResponse(
        "parse_failed",
        `${which} KSIS sa nepodarilo prečítať, zobrazuje ju inak, než appka čaká. Ak sa to opakuje, napíš nám.`,
        422,
        { page: kind },
      );
    }
    throw err;
  }
}

// ── The user's couples ───────────────────────────────────────────────────────────────────────────

async function linkedCouples(admin: Admin, userId: string): Promise<LinkedCouple[]> {
  const { data, error } = await admin
    .from("user_couples")
    .select("id, pair_number, couple_id, partner_names, side, couple_key, is_current")
    .eq("user_id", userId);
  if (error) throw error;
  return data ?? [];
}

async function dancerOf(admin: Admin, userId: string): Promise<Dancer | null> {
  const { data, error } = await admin
    .from("ksis_dancers")
    .select("person_number, name")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  return data ?? null;
}

const asMember = (dancer: Dancer) => ({ personNumber: dancer.person_number, name: dancer.name });

const dancerReply = (dancer: Dancer | null) =>
  dancer ? { personNumber: dancer.person_number, name: dancer.name } : null;

/** A couple is its number and its partnerka: a partner who changes partnerka may keep the number. */
function coupleKey(pairNumber: number, partnerka: string): string {
  return `${pairNumber}|${normalizeDancerName(partnerka)}`;
}

/** The saved couple behind a KSIS couple; rows saved before the key match by the number alone, and couples found by
 * the search (no number yet) by both names. */
function savedCouple(linked: LinkedCouple[], pairNumber: number, names: KsisPairNames): LinkedCouple | undefined {
  const key = coupleKey(pairNumber, names.partnerka);
  return linked.find((couple) => couple.couple_key === key) ??
    linked.find((couple) => couple.couple_key === null && couple.pair_number === pairNumber) ??
    linked.find((couple) =>
      couple.couple_key === null && couple.pair_number === null && couple.partner_names !== null &&
      isSameCouple(splitPair(couple.partner_names), names)
    );
}

/** Makes room for a new current couple; the one before stays in the history. */
async function endCurrentCouple(admin: Admin, userId: string): Promise<void> {
  const { error } = await admin.from("user_couples").update({ is_current: false }).eq("user_id", userId).eq("is_current", true);
  if (error) throw error;
}

const NEEDS_DANCER = "Najprv sa nájdi v zozname členov: Členská základňa → Zoznam členov.";
const NEEDS_CONSENT = "Potvrď, že partner(ka) súhlasí so zobrazením spoločných výsledkov.";

/** The linked couple behind a row: by the KSIS couple id, or by both names when the couple has no id yet. A couple
 * with an id is never given another one: one couple can have two ids in KSIS, and each keeps its own history. */
function findOwn(linked: LinkedCouple[], parId: number | null, names: KsisPairNames): LinkedCouple | undefined {
  return linked.find((couple) => parId !== null && couple.couple_id === parId) ??
    linked.find((couple) =>
      couple.couple_id === null && couple.partner_names !== null && isSameCouple(splitPair(couple.partner_names), names)
    );
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

// ── Members list: "Toto som ja" ──────────────────────────────────────────────────────────────────

const DANCE_SECTION = "Sekcia TŠ";

async function membersList(
  admin: Admin,
  userId: string,
  html: string,
  dancer: Dancer | null,
  save: boolean,
  personNumber: unknown,
) {
  const members = parseMembersList(html).filter((member) => member.section === DANCE_SECTION);
  const reply = (current: Dancer | null) => ({
    kind: "members_list",
    members: members.slice(0, 30).map((member) => ({ ...member, isMe: current?.person_number === member.personNumber })),
    dancer: dancerReply(current),
  });
  if (!save) return jsonResponse(reply(dancer));

  const member = members.find((candidate) => candidate.personNumber === Number(personNumber));
  if (!member) return errorResponse("invalid_input", "Tohto tanečníka na stránke nevidím. Vyhľadaj ho znova.", 400);
  if (dancer && dancer.person_number !== member.personNumber) {
    // The couples and results of the dancer picked before are not this dancer's.
    const { error: resultsError } = await admin.from("competition_results").delete().eq("user_id", userId);
    if (resultsError) throw resultsError;
    const { error: couplesError } = await admin.from("user_couples").delete().eq("user_id", userId);
    if (couplesError) throw couplesError;
  }
  const { error } = await admin.from("ksis_dancers").upsert({
    user_id: userId,
    person_number: member.personNumber,
    name: member.name,
    club: member.club || null,
    stt_class: member.sttClass || null,
    lat_class: member.latClass || null,
    updated_at: new Date().toISOString(),
  }, { onConflict: "user_id" });
  if (error) throw error;
  const current: Dancer = { person_number: member.personNumber, name: member.name };
  return jsonResponse({ ...reply(current), saved: 1 });
}

// ── Couples list: the dancer's couples, the current one and the ones before ──────────────────────

async function couplesList(
  admin: Admin,
  userId: string,
  html: string,
  linked: LinkedCouple[],
  dancer: Dancer | null,
  save: boolean,
  consent: boolean,
) {
  const rows = parseCouplesList(html);
  const sideOf = (row: (typeof rows)[number]) => (dancer ? sideInCouple(asMember(dancer), row) : null);
  // The dancer's rows first: a common surname lists more couples than the reply carries.
  const ordered = [...rows.filter((row) => sideOf(row) !== null), ...rows.filter((row) => sideOf(row) === null)];
  const reply = (saved: LinkedCouple[]) => ({
    kind: "couples_list",
    couples: ordered.slice(0, 30).map((row) => ({
      ...row,
      side: sideOf(row),
      isLinked: savedCouple(saved, row.pairNumber, row) !== undefined,
    })),
    dancer: dancerReply(dancer),
  });
  if (!save) return jsonResponse(reply(linked));

  if (!dancer) return errorResponse("needs_dancer", NEEDS_DANCER, 409);
  const mine = rows.filter((row) => sideOf(row) !== null);
  if (mine.length === 0) {
    return errorResponse("not_found", "Na tejto stránke nie je tvoj pár. Vyhľadaj svoje priezvisko a odškrtni Aktívne.", 404);
  }
  const newRows = mine.filter((row) => savedCouple(linked, row.pairNumber, row) === undefined).length;
  if (!consent && newRows > 0) return errorResponse("invalid_input", NEEDS_CONSENT, 400);
  const noRoom = tooManyCouples(linked, newRows);
  if (noRoom) return noRoom;

  // KSIS writes "Aktívny" at the couple that dances now; a couple that ended has no status.
  const current = mine.find((row) => row.status === "Aktívny");
  if (current) await endCurrentCouple(admin, userId);
  const now = new Date().toISOString();
  for (const row of mine) {
    const values = {
      pair_number: row.pairNumber,
      couple_key: coupleKey(row.pairNumber, row.partnerka),
      side: sideOf(row),
      partner_names: `${row.partner} - ${row.partnerka}`,
      partner_name: `${row.partner} & ${row.partnerka}`,
      club: row.club || null,
      age_category: row.ageCategory || null,
      is_current: row === current,
      updated_at: now,
    };
    const saved = savedCouple(linked, row.pairNumber, row);
    const { error } = saved
      ? await admin.from("user_couples").update(values).eq("id", saved.id)
      : await admin.from("user_couples").insert({ ...values, user_id: userId, discipline: "ALL", partner_consent: true });
    if (error) throw error;
  }
  return jsonResponse({ ...reply(await linkedCouples(admin, userId)), saved: mine.length });
}

// ── Search: every couple of the dancer, the ended ones too, each with its KSIS id ────────────────

interface FoundCouple extends KsisSearchCouple {
  side: "partner" | "partnerka";
}

/** What saving does with a found couple. */
type Step =
  /** Saved with this id already. */
  | { couple: FoundCouple; action: "known" }
  /** Saved by its names without an id: the id is added. */
  | { couple: FoundCouple; action: "claim"; row: LinkedCouple }
  /** A second id of a saved couple (KSIS keeps some couples twice): saved too, its partner already said yes. */
  | { couple: FoundCouple; action: "same" }
  /** Not saved: needs the partner's yes and the dancer's tick, a namesake abroad looks the same. */
  | { couple: FoundCouple; action: "new" };

/** A name the dancer gives for themselves: letters, spaces, a hyphen or an apostrophe, at most 80 characters. */
function otherNameOf(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const name = value.trim().replace(/\s+/g, " ");
  return name.length >= 3 && name.length <= 80 && /^[\p{L} .'-]+$/u.test(name) ? name : null;
}

/** The dancer's rows, one per id: a couple that changed club has a row per club. Most competitions first, so the id
 * with the history takes a saved couple's place when KSIS keeps the couple twice. */
function foundCouples(rows: KsisSearchCouple[], names: string[]): FoundCouple[] {
  const byId = new Map<number, FoundCouple[]>();
  for (const row of rows) {
    const side = names.map((name) => sideInPair(name, row)).find((found) => found !== null) ?? null;
    if (side) byId.set(row.parId, [...(byId.get(row.parId) ?? []), { ...row, side }]);
  }
  return [...byId.values()]
    .map((same) => {
      const main = same.reduce((best, row) => (row.competitions > best.competitions ? row : best));
      return { ...main, competitions: same.reduce((sum, row) => sum + row.competitions, 0) };
    })
    .sort((a, b) => b.competitions - a.competitions);
}

function plan(found: FoundCouple[], linked: LinkedCouple[]): Step[] {
  const claimed = new Set<string>();
  return found.map((couple): Step => {
    if (linked.some((saved) => saved.couple_id === couple.parId)) return { couple, action: "known" };
    const byNames = linked.filter((saved) => saved.partner_names !== null && isSameCouple(splitPair(saved.partner_names), couple));
    const free = byNames.find((saved) => saved.couple_id === null && !claimed.has(saved.id));
    if (free) {
      claimed.add(free.id);
      return { couple, action: "claim", row: free };
    }
    return { couple, action: byNames.length > 0 ? "same" : "new" };
  });
}

async function search(
  admin: Admin,
  userId: string,
  html: string,
  linked: LinkedCouple[],
  dancer: Dancer | null,
  save: boolean,
  consent: boolean,
  parIds: unknown,
  otherName: unknown,
) {
  const rows = parseSearchResults(html);
  const other = otherNameOf(otherName);
  const names = dancer ? [dancer.name, ...(other ? [other] : [])] : [];
  const steps = dancer ? plan(foundCouples(rows, names), linked) : [];
  const reply = (list: Step[]) => ({
    kind: "search",
    found: list.slice(0, 40).map(({ couple, action }) => ({
      parId: couple.parId,
      partner: couple.partner,
      partnerka: couple.partnerka,
      club: couple.club,
      competitions: couple.competitions,
      side: couple.side,
      status: action,
    })),
    dancer: dancerReply(dancer),
  });
  if (!save) return jsonResponse(reply(steps));

  if (!dancer) return errorResponse("needs_dancer", NEEDS_DANCER, 409);
  const ticked = new Set(Array.isArray(parIds) ? parIds.filter((id): id is number => Number.isInteger(id)) : []);
  const chosen = steps.filter((step) => step.action !== "new" || ticked.has(step.couple.parId));
  const newSteps = chosen.filter((step) => step.action === "new" || step.action === "same").length;
  if (!consent && chosen.some((step) => step.action === "new")) return errorResponse("invalid_input", NEEDS_CONSENT, 400);
  const noRoom = tooManyCouples(linked, newSteps);
  if (noRoom) return noRoom;

  const now = new Date().toISOString();
  let saved = 0;
  for (const step of chosen) {
    const { couple } = step;
    if (step.action === "known") continue;
    const { error } = step.action === "claim"
      ? await admin.from("user_couples").update({ couple_id: couple.parId, updated_at: now }).eq("id", step.row.id)
      : await admin.from("user_couples").insert({
        user_id: userId,
        couple_id: couple.parId,
        side: couple.side,
        partner_names: `${couple.partner} - ${couple.partnerka}`,
        partner_name: `${couple.partner} & ${couple.partnerka}`,
        club: couple.club || null,
        is_current: false,
        discipline: "ALL",
        partner_consent: true,
        updated_at: now,
      });
    if (error) throw error;
    saved += 1;
  }
  return jsonResponse({ ...reply(plan(foundCouples(rows, names), await linkedCouples(admin, userId))), saved });
}

// ── Couple detail: class, points, finals of one of the dancer's couples ─────────────────────────

async function coupleDetail(
  admin: Admin,
  userId: string,
  html: string,
  linked: LinkedCouple[],
  dancer: Dancer | null,
  save: boolean,
  consent: boolean,
) {
  const detail = parseCoupleDetail(html);
  const partner = `${detail.partner.surname} ${detail.partner.firstName}`.trim();
  const partnerka = `${detail.partnerka.surname} ${detail.partnerka.firstName}`.trim();
  const saved = savedCouple(linked, detail.pairNumber, { partner, partnerka });
  const side = dancer ? sideInCouple(asMember(dancer), { pairNumber: detail.pairNumber, partner, partnerka }) : null;
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
  const reply = (isLinked: boolean) => ({ kind: "couple_detail", couple, isLinked, isMine: side !== null, dancer: dancerReply(dancer) });
  if (!save) return jsonResponse(reply(saved !== undefined));

  if (!saved) {
    if (!dancer) return errorResponse("needs_dancer", NEEDS_DANCER, 409);
    if (!side) return errorResponse("forbidden", `Toto nie je pár tanečníka ${dancer.name}.`, 403);
    if (!consent) return errorResponse("invalid_input", NEEDS_CONSENT, 400);
    const noRoom = tooManyCouples(linked, 1);
    if (noRoom) return noRoom;
  }

  const now = new Date().toISOString();
  const row = {
    pair_number: detail.pairNumber,
    couple_key: coupleKey(detail.pairNumber, partnerka),
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
    ...(side ? { side } : {}),
  };
  if (saved) {
    const { error } = await admin.from("user_couples").update(row).eq("id", saved.id);
    if (error) throw error;
  } else {
    // A couple with a class dances now and becomes the current one; one that ended goes to the history.
    const dancesNow = [detail.stt.className, detail.lat.className].some((name) => name !== "" && name !== "-");
    if (dancesNow) await endCurrentCouple(admin, userId);
    const { error } = await admin
      .from("user_couples")
      .insert({ ...row, user_id: userId, is_current: dancesNow, discipline: "ALL", partner_consent: true });
    if (error) throw error;
  }
  return jsonResponse({ ...reply(true), saved: 1 });
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
  const stored = historyToStore(page.history);
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

  const resultRow = ({ entry, date, discipline, sutazId }: StoredHistoryRow) => ({
    user_id: userId,
    sutaz_id: sutazId,
    couple_id: page.parId,
    event_name: entry.eventName,
    category_name: entry.category,
    discipline,
    date,
    couple_count: entry.couples ?? 0,
    placement_text: entry.place?.text ?? "",
    placement: entry.place?.from ?? null,
    points_earned: entry.earned?.points ?? 0,
    cumulative_stats: entry.after ? `${entry.after.points}/${entry.after.finals}F` : null,
    cumulative_points: entry.after?.points ?? 0,
    cumulative_finals: entry.after?.finals ?? 0,
    season: yearOf(date),
    source: "auto",
    is_deleted: false,
    deleted_at: null,
    imported_at: now,
  });
  const rows = stored.filter((item) => !item.isWdsf).map(resultRow);
  // A WDSF result has no KSIS page to read the place from: the event's own name ("Kosice,Slovakia") is the place.
  // Its own save, because one batch needs the same columns in every row and the others keep the place they have.
  const wdsfRows = stored.filter((item) => item.isWdsf).map((item) => ({ ...resultRow(item), venue: item.entry.eventName }));
  if (rows.length + wdsfRows.length > 0) {
    const { count, error: countError } = await admin
      .from("competition_results")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId);
    if (countError) throw countError;
    // The save overwrites a result the user already has, so only the new ones count against the cap. Looked up only
    // when the whole batch would go over it: a dancer far from the cap costs no second query.
    if ((count ?? 0) + rows.length + wdsfRows.length > MAX_RESULTS_PER_USER) {
      const added = await countNewOfUser(admin, userId, [...rows, ...wdsfRows]);
      if ((count ?? 0) + added > MAX_RESULTS_PER_USER) {
        return errorResponse("too_large", "Máš uložených príliš veľa súťaží.", 413);
      }
    }
  }
  if (rows.length > 0) {
    const { error } = await admin.from("competition_results").upsert(rows, { onConflict: "user_id,sutaz_id,couple_id" });
    if (error) throw error;
  }
  if (wdsfRows.length > 0) {
    const { error } = await admin.from("competition_results").upsert(wdsfRows, { onConflict: "user_id,sutaz_id,couple_id" });
    if (error) throw error;
  }
  // WDSF rows follow the page: one that is no longer there (KSIS gave it a number, or wrote it otherwise) goes. A page
  // without any row leaves them alone: it may be a page that did not load as it should.
  if (page.history.length > 0) {
    let stale = admin.from("competition_results").delete().eq("user_id", userId).eq("couple_id", page.parId).lt("sutaz_id", 0);
    if (wdsfRows.length > 0) stale = stale.not("sutaz_id", "in", `(${wdsfRows.map((row) => row.sutaz_id).join(",")})`);
    const { error: staleError } = await stale;
    if (staleError) throw staleError;
  }
  return jsonResponse({ kind: "couple_page", couple, competitions, isOwn: true, isLinked: true, saved: rows.length + wdsfRows.length });
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
  if (!isPlausibleDate(page.competition.date)) {
    return errorResponse("invalid_input", "Táto súťaž má dátum, ktorý ešte nenastal alebo je príliš starý.", 400);
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
    // "Miesto:" for the map of where the couple danced; a page without it keeps what was saved.
    ...(page.competition.venue ? { venue: page.competition.venue } : {}),
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
  ].sort((a, b) => a.letter.localeCompare(b.letter)).concat(
    page.competition.shadowJudges.map((judge) => ({ ...judge, hidden: false, shadow: true })),
  );
  const reply = {
    kind: "marks",
    competition: competitionSummary(page.competition),
    dances: page.dances,
    judges,
    startNumber: entry?.startNumber ?? null,
    rounds,
  };
  if (!save) return jsonResponse(reply);

  if (page.rounds.length === 0) {
    return errorResponse("not_found", "KSIS zatiaľ nezverejnil hodnotenie porotcov k tejto súťaži.", 404);
  }
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
    .update({
      rounds,
      judges,
      start_number: entry.startNumber,
      ...(page.competition.venue ? { venue: page.competition.venue } : {}),
    })
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

async function unlink(admin: Admin, userId: string, coupleId: unknown): Promise<Response> {
  if (typeof coupleId !== "string" || !UUID.test(coupleId)) return errorResponse("invalid_input", "Neplatný pár.", 400);

  const { data: row, error } = await admin
    .from("user_couples")
    .select("id, couple_id")
    .eq("user_id", userId)
    .eq("id", coupleId)
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

/** How many of the rows are not saved for the user yet. The saved ones are looked up by competition, in small groups. */
async function countNewOfUser(
  admin: ReturnType<typeof getSupabaseAdmin>,
  userId: string,
  batch: { sutaz_id: number; couple_id: number | null }[],
): Promise<number> {
  const saved = new Set<string>();
  const ids = [...new Set(batch.map((row) => row.sutaz_id))];
  for (let start = 0; start < ids.length; start += 200) {
    const { data, error } = await admin
      .from("competition_results")
      .select("sutaz_id, couple_id")
      .eq("user_id", userId)
      .in("sutaz_id", ids.slice(start, start + 200));
    if (error) throw error;
    for (const row of data ?? []) saved.add(resultKey(row as { sutaz_id: number; couple_id: number | null }));
  }
  return countNewResults(batch, saved);
}
