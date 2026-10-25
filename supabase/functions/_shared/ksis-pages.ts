/**
 * Readers for the public KSIS pages (szts.ksis.eu). Pure functions: HTML in, typed data out, no network.
 *
 * Built and tested against real pages saved on 9. 10. 2026 (anonymized copies in fixtures/ksis/).
 * When a page does not look exactly as expected, a reader throws KsisPageError("layout_changed")
 * instead of guessing, so the app never shows a number that KSIS did not publish.
 *
 * Pages:
 *   couples list      menu.php?akcia=CZP&cis_pr=…&hladany_text=…&aktivne=on   parseCouplesList
 *   couple detail     detail_paru.php?cp=<pair number>                         parseCoupleDetail
 *   couple page       par.php?id=<KSIS couple id>                              parseCouplePage
 *   results           sutaz.php?sutaz_id=…                                     parseResults
 *   judges' marks     hodnot_sut.php?sutaz_id=…                                parseMarks, coupleRounds
 *   registrations     zoznam_prihl.php?id_prop=…                               parseRegistrations
 *   Slovenský pohár   slp_poradie.php?rok=…&druh=SLPDO|SLPJUN&s_l=S|L           parseSlpStandings
 */
import * as cheerio from "npm:cheerio@1.0.0";
import type { CheerioAPI } from "npm:cheerio@1.0.0";

// ── Errors and shared helpers ────────────────────────────────────────────────────────────────────

export class KsisPageError extends Error {
  constructor(readonly kind: "blocked" | "layout_changed", message: string) {
    super(message);
    this.name = "KsisPageError";
  }
}

// Markers of a Cloudflare challenge page. Normal KSIS pages also load
// "/cdn-cgi/challenge-platform/…/jsd/main.js", so that path is deliberately not a marker.
const CHALLENGE_MARKERS = [
  "just a moment",
  "cf-wrapper",
  "challenges.cloudflare.com",
  "attention required! | cloudflare",
  "_cf_chl_opt",
  "prebieha bezpečnostné overenie",
];

export function isChallengePage(html: string): boolean {
  const lower = html.toLowerCase();
  return CHALLENGE_MARKERS.some((marker) => lower.includes(marker));
}

/** Lowercase, no diacritics, single spaces: for comparing names written differently on KSIS pages. */
export function normalizeDancerName(name: string): string {
  if (!name) return "";
  return name
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

const clean = (text: string): string => text.replace(/ /g, " ").replace(/\s+/g, " ").trim();

function load(html: string, page: string): CheerioAPI {
  if (isChallengePage(html)) throw new KsisPageError("blocked", `${page}: Cloudflare challenge instead of the page`);
  return cheerio.load(html);
}

function layoutChanged(page: string, detail: string): KsisPageError {
  return new KsisPageError("layout_changed", `${page}: ${detail}`);
}

/** Text lines of a cell, split where KSIS puts <br>. */
function lines(cellHtml: string | null): string[] {
  return (cellHtml ?? "")
    .split(/<br\s*\/?>/i)
    .map((part) => clean(cheerio.load(part, null, false).text()))
    .filter((line) => line.length > 0);
}

function columnTitles($: CheerioAPI, table: string): string[][] {
  return $(table).first().find("thead th").toArray().map((th) => lines($(th).html()));
}

function expectColumns(page: string, actual: string[][], expected: string[]): void {
  expected.forEach((title, i) => {
    const found = actual[i]?.join(" ") ?? "";
    if (found !== title) throw layoutChanged(page, `column ${i + 1} is "${found}", expected "${title}"`);
  });
}

function intOrNull(text: string): number | null {
  const value = clean(text);
  return /^\d+$/.test(value) ? Number(value) : null;
}

function idFrom(href: string | undefined, param: string): number | null {
  const match = href?.match(new RegExp(`[?&]${param}=(\\d+)`));
  return match ? Number(match[1]) : null;
}

/** "12.09.2026" → "2026-09-12". */
export function parseKsisDate(text: string): string | null {
  const match = clean(text).match(/(\d{1,2})\.(\d{1,2})\.(\d{4})/);
  return match ? `${match[3]}-${match[2].padStart(2, "0")}-${match[1].padStart(2, "0")}` : null;
}

/** A placing; shared places keep both ends ("12. - 13." → 12…13). */
export interface KsisPlace {
  from: number;
  to: number;
  text: string;
}

/** "3.", "12. - 13.", "1 - 2", "10". */
export function parsePlace(text: string): KsisPlace | null {
  const value = clean(text);
  const match = value.match(/^(\d+)\.?(?:\s*-\s*(\d+)\.?)?$/);
  if (!match) return null;
  const from = Number(match[1]);
  return { from, to: match[2] ? Number(match[2]) : from, text: value };
}

/** Points and finals in a discipline, "89/5F". */
export interface KsisStanding {
  points: number;
  finals: number;
}

export function parseStanding(text: string): KsisStanding | null {
  const match = clean(text).match(/^(\d+)\s*\/\s*(\d+)\s*F$/i);
  return match ? { points: Number(match[1]), finals: Number(match[2]) } : null;
}

/** Points from one competition: "18/F" (danced the final) or "4". Empty when KSIS awarded none. */
export interface KsisEarned {
  points: number;
  final: boolean;
}

export function parseEarned(text: string): KsisEarned | null {
  const match = clean(text).match(/^(\d+)(\s*\/\s*F)?$/i);
  return match ? { points: Number(match[1]), final: Boolean(match[2]) } : null;
}

export interface KsisPairNames {
  partner: string;
  partnerka: string;
}

/** KSIS writes a couple as "Priezvisko Meno - Priezvisko Meno". */
export function splitPair(text: string): KsisPairNames {
  const value = clean(text);
  const cut = value.indexOf(" - ");
  return cut < 0 ? { partner: value, partnerka: "" } : { partner: value.slice(0, cut), partnerka: value.slice(cut + 3) };
}

export function isSameCouple(a: KsisPairNames, b: KsisPairNames): boolean {
  return normalizeDancerName(a.partner) === normalizeDancerName(b.partner) &&
    normalizeDancerName(a.partnerka) === normalizeDancerName(b.partnerka);
}

/** "Dospelí D ŠTT" → "STT". Only reads the discipline KSIS writes last; nothing else is inferred. */
export function disciplineOf(category: string): "STT" | "LAT" | null {
  const last = clean(category).split(" ").at(-1);
  return last === "ŠTT" ? "STT" : last === "LAT" ? "LAT" : null;
}

// ── Couples list (menu.php?akcia=CZP) ────────────────────────────────────────────────────────────

export interface KsisCoupleListRow extends KsisPairNames {
  /** "Č.pr" of the couple; KSIS uses the partner's personal number. */
  pairNumber: number;
  club: string;
  ageCategory: string;
  sttClass: string;
  latClass: string;
  status: string;
}

const COUPLES_LIST = "zoznam párov";

export function parseCouplesList(html: string): KsisCoupleListRow[] {
  const $ = load(html, COUPLES_LIST);
  expectColumns(COUPLES_LIST, columnTitles($, "table"), ["Č.pr", "Partner", "Partnerka", "Klub", "Vek.ktg", "ŠTT", "LAT", "Stav"]);
  return $("table").first().find("tbody tr").toArray().flatMap((tr) => {
    const cells = $(tr).find("td").toArray().map((td) => clean($(td).text()));
    if (cells.length === 0) return [];
    const pairNumber = intOrNull(cells[0]);
    if (cells.length < 8 || pairNumber === null) throw layoutChanged(COUPLES_LIST, "couple row");
    return [{
      pairNumber,
      partner: cells[1],
      partnerka: cells[2],
      club: cells[3],
      ageCategory: cells[4],
      sttClass: cells[5],
      latClass: cells[6],
      status: cells[7],
    }];
  });
}

/** KSIS numbers a couple with the partner's personal number; a partnerka is found by her name. */
export function sideInCouple(
  member: Pick<KsisMemberRow, "personNumber" | "name">,
  couple: Pick<KsisCoupleListRow, "pairNumber" | "partner" | "partnerka">,
): "partner" | "partnerka" | null {
  const name = normalizeDancerName(member.name);
  if (couple.pairNumber === member.personNumber || normalizeDancerName(couple.partner) === name) return "partner";
  return normalizeDancerName(couple.partnerka) === name ? "partnerka" : null;
}

// ── Members list (menu.php?akcia=CZ) ─────────────────────────────────────────────────────────────

export interface KsisMemberRow {
  /** "Č.pr", the personal number from the member's card. */
  personNumber: number;
  /** "Priezvisko Meno" as KSIS writes it. */
  name: string;
  club: string;
  section: string;
  /** "" when the member has no class in that discipline. */
  sttClass: string;
  latClass: string;
  /** KSIS writes "Aktívny"; a member who stopped has an empty status but keeps the last classes. */
  active: boolean;
}

const MEMBERS_LIST = "zoznam členov";

export function parseMembersList(html: string): KsisMemberRow[] {
  const $ = load(html, MEMBERS_LIST);
  expectColumns(MEMBERS_LIST, columnTitles($, "table"),
    ["Č.pr", "Meno", "Klub", "Sekcia", "ŠTT", "LAT", "ROZ", "FUN", "SCIT", "Tréner", "Čestný člen", "Stav"]);
  return $("table").first().find("tbody tr").toArray().flatMap((tr) => {
    const cells = $(tr).find("td").toArray().map((td) => clean($(td).text()));
    if (cells.length === 0) return [];
    const personNumber = intOrNull(cells[0]);
    if (cells.length < 12 || personNumber === null) throw layoutChanged(MEMBERS_LIST, "member row");
    return [{
      personNumber,
      name: cells[1],
      club: cells[2],
      section: cells[3],
      sttClass: cells[4],
      latClass: cells[5],
      active: cells[11] === "Aktívny",
    }];
  });
}

// ── Couple detail (detail_paru.php) ──────────────────────────────────────────────────────────────

export interface KsisPersonName {
  surname: string;
  firstName: string;
}

export interface KsisDisciplineStanding {
  className: string;
  points: number | null;
  finals: number | null;
  /** "Posledná zmena" as KSIS shows it. */
  lastChange: string | null;
}

export interface KsisCoupleDetail {
  pairNumber: number;
  partner: KsisPersonName;
  partnerka: KsisPersonName;
  club: string;
  ageCategory: string;
  /** The year KSIS shows next to the standings ("ŠTT 2026"). */
  year: number | null;
  stt: KsisDisciplineStanding;
  lat: KsisDisciplineStanding;
}

const COUPLE_DETAIL = "detail páru";

export function parseCoupleDetail(html: string): KsisCoupleDetail {
  const $ = load(html, COUPLE_DETAIL);
  const field = (id: string): string => {
    const input = $(`input#${id}`);
    if (input.length === 0) throw layoutChanged(COUPLE_DETAIL, `field ${id} missing`);
    return clean(input.attr("value") ?? "");
  };
  const pairNumber = intOrNull(field("c_preuk_m"));
  if (pairNumber === null) throw layoutChanged(COUPLE_DETAIL, "pair number missing");
  const standing = (discipline: "STT" | "LAT"): KsisDisciplineStanding => ({
    className: field(`vyk_${discipline}`),
    points: intOrNull(field(`body_${discipline}`)),
    finals: intOrNull(field(`finale_${discipline}`)),
    lastChange: parseKsisDate(field(`dpz_${discipline}`)),
  });
  const year = clean($("form").text()).match(/ŠTT\s+(\d{4})/);
  return {
    pairNumber,
    partner: { surname: field("priezviskoOn"), firstName: field("menoOn") },
    partnerka: { surname: field("priezviskoOna"), firstName: field("menoOna") },
    club: field("klub"),
    ageCategory: field("vekktg"),
    year: year ? Number(year[1]) : null,
    stt: standing("STT"),
    lat: standing("LAT"),
  };
}

// ── Couple page with the whole history (par.php) ─────────────────────────────────────────────────

export interface KsisClassLabel {
  className: string;
  standing: KsisStanding | null;
}

export interface KsisHistoryRow {
  date: string | null;
  eventId: number | null;
  eventName: string;
  /** Null for a WDSF competition: KSIS lists it with a link to worlddancesport.org and keeps no results of it. */
  sutazId: number | null;
  category: string;
  couples: number | null;
  place: KsisPlace | null;
  /** "Body": points from this competition. */
  earned: KsisEarned | null;
  /** "Body po": points and finals after this competition. */
  after: KsisStanding | null;
  /** The green check mark KSIS shows in the last column (meaning not documented, kept as is). */
  hasCheckMark: boolean;
}

export interface KsisCouplePage extends KsisPairNames {
  parId: number | null;
  club: string;
  ageCategory: string | null;
  stt: KsisClassLabel | null;
  lat: KsisClassLabel | null;
  history: KsisHistoryRow[];
}

const COUPLE_PAGE = "stránka páru";

export function parseCouplePage(html: string): KsisCouplePage {
  const $ = load(html, COUPLE_PAGE);
  const header = $("div.jumbotron");
  const title = clean(header.find("h3").first().text());
  if (!title) throw layoutChanged(COUPLE_PAGE, "couple title missing");
  const info = clean(header.find("h5").first().text());
  const classLabel = (label: string): KsisClassLabel | null => {
    const match = info.match(new RegExp(`Výkonnostná trieda ${label}:\\s*([^\\s(]+)(?:\\s*\\(([^)]*)\\))?`));
    return match ? { className: match[1], standing: match[2] ? parseStanding(match[2]) : null } : null;
  };
  const age = info.match(/Veková kategória:\s*(.+?)\s*(?:Výkonnostná|$)/);

  expectColumns(COUPLE_PAGE, columnTitles($, "table"), ["Dátum", "Podujatie", "Súťaž", "Počet párov", "Umiestnenie", "Body", "Body po"]);
  const history = $("table").first().find("tbody tr").toArray().flatMap((tr) => {
    const td = $(tr).find("td").toArray();
    if (td.length === 0) return [];
    const event = $(td[2]).find("a");
    const competition = $(td[3]).find("a");
    const href = competition.attr("href") ?? "";
    const sutazId = idFrom(href, "sutaz_id");
    if (td.length < 8 || (sutazId === null && !href.includes("worlddancesport.org"))) {
      throw layoutChanged(COUPLE_PAGE, "history row");
    }
    return [{
      date: parseKsisDate($(td[0]).text()),
      eventId: idFrom(event.attr("href"), "pod_id"),
      eventName: clean(event.text()),
      sutazId,
      category: clean(competition.text()),
      couples: intOrNull($(td[4]).text()),
      place: parsePlace($(td[5]).text()),
      earned: parseEarned($(td[6]).text()),
      after: parseStanding($(td[7]).text()),
      hasCheckMark: $(tr).find(".glyphicon-ok").length > 0,
    }];
  });

  return {
    ...splitPair(title),
    // The "Rozdeliť ŠTT a LAT" button links back to this page and is the only place with its id.
    parId: idFrom($("a[href*='par.php?id=']").first().attr("href"), "id"),
    club: clean(header.find("p").first().text()),
    ageCategory: age ? age[1] : null,
    stt: classLabel("ŠTT"),
    lat: classLabel("LAT"),
    history,
  };
}

// ── Competition header shared by results and marks ──────────────────────────────────────────────

export interface KsisJudge {
  letter: string;
  name: string;
  city: string | null;
}

export interface KsisCompetition {
  sutazId: number | null;
  eventId: number | null;
  eventName: string;
  category: string;
  date: string | null;
  venue: string | null;
  organizer: string | null;
  type: string | null;
  /** "Postupový kľúč: 13 ->9 ->6" → [13, 9, 6]. */
  advancement: number[];
  couples: number | null;
  judges: KsisJudge[];
  /**
   * Letters missing in the judges list (D in A, B, C, E, F, G). Such a judge is counted in "Suma" and in the
   * final, but KSIS publishes neither the name nor the marks (verified on competition 12094, docs/KSIS_*).
   */
  hiddenJudgeLetters: string[];
}

function missingLetters(letters: string[]): string[] {
  if (letters.length === 0) return [];
  const last = Math.max(...letters.map((letter) => letter.charCodeAt(0)));
  const missing: string[] = [];
  for (let code = "A".charCodeAt(0); code <= last; code++) {
    const letter = String.fromCharCode(code);
    if (!letters.includes(letter)) missing.push(letter);
  }
  return missing;
}

function parseCompetition($: CheerioAPI, page: string): KsisCompetition {
  const header = $("div.jumbotron");
  const h3 = header.find("h3").first();
  const titleOnly = h3.clone();
  titleOnly.find("small").remove();
  const title = clean(titleOnly.text());
  const cut = title.lastIndexOf(" - ");
  if (cut < 0) throw layoutChanged(page, "competition title");

  const field = (label: string): string | null => {
    const line = header.find("h5").toArray().map((h5) => clean($(h5).text())).find((text) => text.startsWith(label));
    return line ? clean(line.slice(label.length)) || null : null;
  };
  const judges = $("a[href*='rozhodca.php']").toArray().map((a) => {
    const match = clean($(a).text()).match(/^([A-Z])\s*-\s*(.+?)(?:\s*\(([^)]*)\))?$/);
    if (!match) throw layoutChanged(page, "judge entry");
    return { letter: match[1], name: match[2], city: match[3] ?? null };
  });

  return {
    sutazId: idFrom($("a[href*='sutaz_id=']").first().attr("href"), "sutaz_id"),
    eventId: idFrom(header.find("a[href*='pod_id=']").first().attr("href"), "pod_id"),
    eventName: title.slice(0, cut),
    category: title.slice(cut + 3),
    date: parseKsisDate(h3.find("small").text()),
    venue: field("Miesto:"),
    organizer: field("Organizátor:"),
    type: field("Typ súťaže:"),
    advancement: (field("Postupový kľúč:") ?? "").split("->").map((n) => n.trim()).filter((n) => /^\d+$/.test(n)).map(Number),
    couples: intOrNull(field("Počet párov") ?? ""),
    judges,
    hiddenJudgeLetters: missingLetters(judges.map((judge) => judge.letter)),
  };
}

// ── Results (sutaz.php) ──────────────────────────────────────────────────────────────────────────

/**
 * How a competition gives points: class points ("Body", "Celkom"), Slovenský pohár points ("SLP"), or none
 * (WDSF competitions, ordinary cups).
 */
export type KsisScoring = "points" | "slp" | "none";

export interface KsisResultRow extends KsisPairNames {
  /** The round the couple finished in ("Finále", "Semifinále", "1.kolo"). */
  round: string;
  place: KsisPlace | null;
  /** "Č.p.": the start number at this competition. */
  startNumber: string;
  parId: number;
  club: string;
  /** "Body": points from this competition. */
  points: number | null;
  /** "Celkom": points and finals after this competition. */
  total: KsisStanding | null;
  /** Slovenský pohár: the place among Slovak couples and this round's SLP points. Null in other competitions. */
  slp: { place: KsisPlace | null; points: number | null } | null;
  hasCheckMark: boolean;
}

export interface KsisResults {
  competition: KsisCompetition;
  scoring: KsisScoring;
  rows: KsisResultRow[];
}

const RESULTS = "výsledková listina";

export function parseResults(html: string): KsisResults {
  const $ = load(html, RESULTS);
  const competition = parseCompetition($, RESULTS);
  const titles = columnTitles($, "table.table");
  expectColumns(RESULTS, titles, ["Umiestnenie", "Č.p.", "Pár", "Klub"]);
  const fifth = titles[4]?.join(" ") ?? "";
  const scoring: KsisScoring = fifth === "Body" ? "points" : fifth === "SLP" ? "slp" : fifth === "" ? "none" : (() => {
    throw layoutChanged(RESULTS, `column 5 is "${fifth}"`);
  })();
  if (scoring === "points") expectColumns(RESULTS, titles, ["Umiestnenie", "Č.p.", "Pár", "Klub", "Body", "Celkom"]);
  const rows: KsisResultRow[] = [];
  let round = "";
  for (const tr of $("table.table").first().find("tbody tr").toArray()) {
    const td = $(tr).find("td").toArray();
    if (td.length === 1 && $(td[0]).attr("colspan") !== undefined) {
      round = clean($(td[0]).text());
      continue;
    }
    const pair = $(td[2]).find("a[href*='par.php?id=']");
    const parId = idFrom(pair.attr("href"), "id");
    if (td.length < (scoring === "none" ? 4 : 6) || parId === null) throw layoutChanged(RESULTS, "result row");
    rows.push({
      round,
      place: parsePlace($(td[0]).text()),
      startNumber: clean($(td[1]).text()),
      parId,
      ...splitPair(pair.text()),
      club: clean($(td[3]).text()),
      points: scoring === "points" ? intOrNull($(td[4]).text()) : null,
      total: scoring === "points" ? parseStanding($(td[5]).text()) : null,
      slp: scoring === "slp" ? { place: parsePlace($(td[4]).text()), points: intOrNull($(td[5]).text()) } : null,
      hasCheckMark: $(tr).find(".glyphicon-ok").length > 0,
    });
  }
  return { competition, scoring, rows };
}

// ── Judges' marks (hodnot_sut.php) ───────────────────────────────────────────────────────────────

/**
 * "crosses": every judge marks X (cross) or "." per dance. "final": every judge places the couple 1–n.
 * "scores": the WDSF absolute judging system (adult Slovenský pohár finals, WDSF World Open): one score per
 * dance; the judges' components are in a breakdown KSIS adds under each couple, which is not read.
 */
export type KsisRoundKind = "crosses" | "final" | "scores";

export interface KsisMarksEntry extends KsisPairNames {
  startNumber: string;
  parId: number;
  club: string;
  /** One string per dance, one character per published judge column. */
  marks: string[];
  /** "Suma" exactly as KSIS shows it. */
  sum: number;
  /** "Umiest.." in this round. */
  place: KsisPlace | null;
  /** "Postup": Y → true, "-" → false, empty → null (final, or not published yet). */
  advanced: boolean | null;
}

export interface KsisMarksRound {
  name: string;
  kind: KsisRoundKind;
  entries: KsisMarksEntry[];
}

export interface KsisMarks {
  competition: KsisCompetition;
  dances: string[];
  /** Judge columns KSIS publishes per dance. */
  judgeColumns: number;
  rounds: KsisMarksRound[];
}

const MARKS = "hodnotenie porotcov";

export function parseMarks(html: string): KsisMarks {
  const $ = load(html, MARKS);
  const competition = parseCompetition($, MARKS);
  const titles = columnTitles($, "table.table");
  const tail = titles.slice(-3).map((title) => title.join(" "));
  const danceTitles = titles.slice(2, -3);
  if (titles[0]?.join(" ") !== "kolo Č.p." || titles[1]?.join(" ") !== "Pár Klub" || tail.join("|") !== "Suma|Umiest..|Postup") {
    throw layoutChanged(MARKS, "columns");
  }
  // Each dance column is titled "WALTZ" + "ABCDEF": one letter per published judge column.
  const judgeColumns = danceTitles[0]?.[1]?.length ?? 0;
  if (judgeColumns === 0 || danceTitles.some((title) => title.length !== 2 || title[1].length !== judgeColumns)) {
    throw layoutChanged(MARKS, "dance columns");
  }
  const dances = danceTitles.map((title) => title[0]);

  const rounds: KsisMarksRound[] = [];
  // Only the table's own rows: a scores round nests a breakdown table under every couple.
  for (const tr of $("table.table").first().children("tbody").children("tr").toArray()) {
    const td = $(tr).children("td").toArray();
    if (td.length === 1 && $(td[0]).find("table").length > 0) continue;
    if (td.length === 1 && $(td[0]).attr("colspan") !== undefined) {
      rounds.push({ name: clean($(td[0]).text()), kind: "crosses", entries: [] });
      continue;
    }
    const round = rounds.at(-1);
    const pair = $(td[1]).find("a[href*='par.php?id=']");
    const parId = idFrom(pair.attr("href"), "id");
    if (!round || parId === null || td.length !== dances.length + 5) throw layoutChanged(MARKS, "marks row");
    const [sumText, placeText, advancedText] = td.slice(-3).map((cell) => clean($(cell).text()));
    const sum = Number(sumText);
    if (sumText === "" || !Number.isFinite(sum)) throw layoutChanged(MARKS, `sum in ${round.name}`);
    round.entries.push({
      startNumber: clean($(td[0]).text()),
      parId,
      ...splitPair(pair.text()),
      club: lines($(td[1]).html())[1] ?? "",
      marks: td.slice(2, 2 + dances.length).map((cell) => clean($(cell).text())),
      sum,
      place: parsePlace(placeText),
      advanced: advancedText === "Y" ? true : advancedText === "-" ? false : null,
    });
  }

  for (const round of rounds) {
    const marks = round.entries.flatMap((entry) => entry.marks);
    if (marks.length > 0 && marks.every((mark) => /^\d+\.\d+$/.test(mark))) {
      round.kind = "scores";
      continue;
    }
    if (marks.some((mark) => mark.length !== judgeColumns)) throw layoutChanged(MARKS, `marks length in ${round.name}`);
    if (marks.every((mark) => /^[X.]+$/.test(mark))) round.kind = "crosses";
    else if (marks.every((mark) => /^[1-9]+$/.test(mark))) round.kind = "final";
    else throw layoutChanged(MARKS, `unexpected marks in ${round.name}`);
  }
  return { competition, dances, judgeColumns, rounds: rounds.filter((round) => round.entries.length > 0) };
}

export interface KsisJudgeMark {
  /** Judge letter and name; null when the published columns cannot be matched to the judges list. */
  letter: string | null;
  name: string | null;
  /** "X" or "." in a crosses round, the judge's placing ("3") in the final. */
  mark: string;
}

export interface KsisDanceMarks {
  dance: string;
  /** Every published judge's mark; empty in a scores round. */
  marks: KsisJudgeMark[];
  /** Crosses from the published judges (crosses rounds only). */
  crosses: number | null;
  /** The dance's score in a scores round. */
  score: number | null;
}

export interface KsisCoupleRound {
  round: string;
  kind: KsisRoundKind;
  dances: KsisDanceMarks[];
  /** "Suma" exactly as KSIS shows it: crosses in a round, the sum of dance placings in the final. */
  sum: number;
  place: KsisPlace | null;
  advanced: boolean | null;
  couplesInRound: number;
  /** How many couples went through from this round; null until KSIS shows "Postup" for everyone. */
  advancedCount: number | null;
  /** Crosses from the judges KSIS publishes (crosses rounds only). */
  visibleCrosses: number | null;
  /**
   * Crosses from hidden judges = Suma − published crosses. Null in the final, and whenever the numbers
   * do not fit the hidden judges (then the app shows only the KSIS "Suma").
   */
  hiddenCrosses: number | null;
}

/** Everything one couple got in each round, with every published judge's mark by name. */
export function coupleRounds(page: KsisMarks, parId: number): KsisCoupleRound[] {
  const { judges, hiddenJudgeLetters } = page.competition;
  // KSIS titles the published columns A, B, C… by position; they belong to the judges in list order.
  const named = judges.length === page.judgeColumns;
  const maxHidden = hiddenJudgeLetters.length * page.dances.length;

  return page.rounds.flatMap((round) => {
    const entry = round.entries.find((candidate) => candidate.parId === parId);
    if (!entry) return [];
    const dances = page.dances.map((dance, i) => {
      if (round.kind === "scores") return { dance, marks: [], crosses: null, score: Number(entry.marks[i]) };
      const marks = [...entry.marks[i]].map((mark, column) => ({
        letter: named ? judges[column].letter : null,
        name: named ? judges[column].name : null,
        mark,
      }));
      return { dance, marks, crosses: round.kind === "crosses" ? marks.filter((m) => m.mark === "X").length : null, score: null };
    });
    const visible = round.kind === "crosses" ? dances.reduce((total, dance) => total + (dance.crosses ?? 0), 0) : null;
    const hidden = visible === null ? null : entry.sum - visible;
    const advancedFlags = round.entries.map((candidate) => candidate.advanced);
    return [{
      round: round.name,
      kind: round.kind,
      dances,
      sum: entry.sum,
      place: entry.place,
      advanced: entry.advanced,
      couplesInRound: round.entries.length,
      advancedCount: advancedFlags.every((flag) => flag !== null) ? advancedFlags.filter((flag) => flag).length : null,
      visibleCrosses: visible,
      hiddenCrosses: hidden !== null && Number.isInteger(hidden) && hidden >= 0 && hidden <= maxHidden ? hidden : null,
    }];
  });
}

// ── Registrations (zoznam_prihl.php) ─────────────────────────────────────────────────────────────

export interface KsisRegisteredCouple extends KsisPairNames {
  order: number;
  club: string;
  country: string;
}

export interface KsisRegistrationCategory {
  name: string;
  couples: KsisRegisteredCouple[];
}

export interface KsisRegistrations {
  eventName: string;
  date: string | null;
  venue: string | null;
  /** "Počet prihlásených párov … : 192". */
  total: number | null;
  categories: KsisRegistrationCategory[];
}

const REGISTRATIONS = "zoznam prihlášok";
const REGISTRATIONS_TITLE = "Zoznam prihlásených párov na";

export function parseRegistrations(html: string): KsisRegistrations {
  const $ = load(html, REGISTRATIONS);
  const header = $("div.jumbotron");
  const h3 = header.find("h3").first();
  const titleOnly = h3.clone();
  titleOnly.find("small").remove();
  const title = clean(titleOnly.text());
  if (!title.startsWith(REGISTRATIONS_TITLE)) throw layoutChanged(REGISTRATIONS, "title");
  const total = clean(header.find("h5").first().text()).match(/:\s*(\d+)$/);

  const categories = $("table").toArray().flatMap((table) => {
    const name = clean($(table).find("thead th").first().text());
    if (!name) return [];
    const couples = $(table).find("tbody tr").toArray().map((tr) => {
      const cells = $(tr).find("td").toArray().map((td) => clean($(td).text()));
      const order = cells[0]?.match(/^(\d+)\.$/);
      if (cells.length < 4 || !order) throw layoutChanged(REGISTRATIONS, `row in ${name}`);
      return { order: Number(order[1]), ...splitPair(cells[1]), club: cells[2], country: cells[3] };
    });
    return [{ name, couples }];
  });

  return {
    eventName: title.slice(REGISTRATIONS_TITLE.length).trim(),
    date: parseKsisDate(h3.find("small").text()),
    venue: clean(header.find("p").first().text()) || null,
    total: total ? Number(total[1]) : null,
    categories,
  };
}

/** Categories the couple is registered in. Names are compared without diacritics and case. */
export function registeredCategories(registrations: KsisRegistrations, couple: KsisPairNames): string[] {
  return registrations.categories
    .filter((category) => category.couples.some((registered) => isSameCouple(registered, couple)))
    .map((category) => category.name);
}

// ── Slovenský pohár standings (slp_poradie.php) ──────────────────────────────────────────────────

export interface KsisSlpRound {
  sutazId: number | null;
  venue: string;
  date: string | null;
}

export interface KsisSlpEntry extends KsisPairNames {
  place: KsisPlace | null;
  parId: number;
  club: string;
  /** One per round, in the order of `rounds`; null where the couple did not dance. */
  rounds: ({ place: KsisPlace | null; points: number } | null)[];
  /** "Body": the sum KSIS shows. */
  total: number;
}

export interface KsisSlpStandings {
  year: number | null;
  /** As KSIS titles the table: "Dospelí Štandard", "Juniori Latin". */
  category: string;
  /** "Do výslednej sumy sú započítané len 4 najlepšie súťaže" → 4; null when the page does not say. */
  countedRounds: number | null;
  rounds: KsisSlpRound[];
  entries: KsisSlpEntry[];
}

const SLP = "poradie Slovenského pohára";
const SLP_TITLE = "Poradie Slovenského pohára za rok ";

export function parseSlpStandings(html: string): KsisSlpStandings {
  const $ = load(html, SLP);
  const header = $("div.jumbotron");
  const title = clean(header.find("h3").first().text());
  const rest = title.startsWith(SLP_TITLE) ? title.slice(SLP_TITLE.length) : "";
  const cut = rest.indexOf(" - ");
  if (cut < 0) throw layoutChanged(SLP, "title");
  const counted = clean(header.find("p").first().text()).match(/(\d+)\s+najlepš/);

  const table = $("table.table").first();
  const headers = table.find("thead th").toArray();
  const titles = headers.map((th) => lines($(th).html()).join(" "));
  if (titles[0] !== "Poradie" || titles[1] !== "Pár" || titles.at(-1) !== "Body") throw layoutChanged(SLP, "columns");
  // Each round column is the venue and the date, linking to that round's results.
  const rounds = headers.slice(2, -1).map((th) => {
    const parts = lines($(th).html());
    return { sutazId: idFrom($(th).find("a").attr("href"), "sutaz_id"), venue: parts[0] ?? "", date: parseKsisDate(parts.at(-1) ?? "") };
  });

  const entries = table.find("tbody tr").toArray().map((tr) => {
    const td = $(tr).find("td").toArray();
    const pair = $(td[1]).find("a[href*='par.php?id=']");
    const parId = idFrom(pair.attr("href"), "id");
    const total = intOrNull($(td.at(-1)).text());
    if (td.length !== rounds.length + 3 || parId === null || total === null) throw layoutChanged(SLP, "row");
    return {
      place: parsePlace($(td[0]).text()),
      parId,
      ...splitPair(pair.text()),
      club: lines($(td[1]).html())[1] ?? "",
      // "5 (14)": 5th among Slovak couples, 14 points; "9-12 (7)" for a shared place.
      rounds: td.slice(2, -1).map((cell) => {
        const text = clean($(cell).text());
        if (!text) return null;
        const match = text.match(/^(.+?)\s*\((\d+)\)$/);
        if (!match) throw layoutChanged(SLP, `round cell "${text}"`);
        return { place: parsePlace(match[1]), points: Number(match[2]) };
      }),
      total,
    };
  });
  return { year: intOrNull(rest.slice(0, cut)), category: rest.slice(cut + 3), countedRounds: counted ? Number(counted[1]) : null, rounds, entries };
}
