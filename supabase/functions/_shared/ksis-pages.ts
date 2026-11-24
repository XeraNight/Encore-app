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
 *   search            search.php?hladany_text=…                                parseSearchResults
 *   results           sutaz.php?sutaz_id=…                                     parseResults
 *   judges' marks     hodnot_sut.php?sutaz_id=…                                parseMarks, coupleRounds
 *   registrations     zoznam_prihl.php?id_prop=…                               parseRegistrations
 *   Slovenský pohár   slp_poradie.php?rok=…&druh=SLPDO|SLPJUN&s_l=S|L           parseSlpStandings
 */
import * as cheerio from "npm:cheerio@1.0.0";
import type { CheerioAPI } from "npm:cheerio@1.0.0";

// ── Errors and shared helpers ────────────────────────────────────────────────────────────────────

export class KsisPageError extends Error {
  /** `page` is the name of the page kind ("stránka páru"), for a message the dancer can read. */
  constructor(readonly kind: "blocked" | "layout_changed", message: string, readonly page = "") {
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

/** No name, title or place of a real page is longer: a page cannot put a megabyte into one. */
const MAX_TEXT = 400;
const clean = (text: string): string => text.replace(/ /g, " ").replace(/\s+/g, " ").trim().slice(0, MAX_TEXT);

function load(html: string, page: string): CheerioAPI {
  if (isChallengePage(html)) throw new KsisPageError("blocked", `${page}: Cloudflare challenge instead of the page`, page);
  return cheerio.load(html);
}

function layoutChanged(page: string, detail: string): KsisPageError {
  return new KsisPageError("layout_changed", `${page}: ${detail}`, page);
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
    if (found !== title) {
      const headers = actual.slice(0, 12).map((lines) => lines.join(" ").slice(0, 24)).join(" | ");
      throw layoutChanged(page, `column ${i + 1} is "${found}", expected "${title}"; headers [${headers}]`);
    }
  });
}

/** What the page's tables looked like, for the log when a reader gives up: only the column titles, never the content. */
function outline($: CheerioAPI): string {
  const tables = $("table").toArray().slice(0, 4).map((table, index) => {
    const titles = $(table).find("th").toArray().slice(0, 12).map((th) => clean($(th).text()).slice(0, 24));
    return `table ${index + 1} [${titles.join(" | ")}] ${$(table).find("tr").length} rows`;
  });
  return tables.length > 0 ? tables.join("; ") : "no table";
}

// deno-lint-ignore no-explicit-any
type TableElement = any;

/** Where each column title starts among the cells of a row: a title can span more columns ("Dátum" takes two). */
function columnStarts($: CheerioAPI, table: TableElement): Map<string, number> {
  const starts = new Map<string, number>();
  let position = 0;
  for (const th of $(table).find("th").toArray()) {
    const title = lines($(th).html()).join(" ");
    if (title !== "" && !starts.has(title)) starts.set(title, position);
    position += Math.max(1, Number($(th).attr("colspan")) || 1);
  }
  return starts;
}

/** A whole number of at most nine digits: what the database columns hold, and more than any pair number or count. */
function intOrNull(text: string): number | null {
  const value = clean(text);
  return /^\d{1,9}$/.test(value) ? Number(value) : null;
}

function idFrom(href: string | undefined, param: string): number | null {
  const match = href?.match(new RegExp(`[?&]${param}=(\\d{1,9})(?!\\d)`));
  return match ? Number(match[1]) : null;
}

/** "12.09.2026" → "2026-09-12"; a day that does not exist ("31.02.2026") is no date. */
export function parseKsisDate(text: string): string | null {
  const match = clean(text).match(/(\d{1,2})\.(\d{1,2})\.(\d{4})/);
  if (!match) return null;
  const [day, month, year] = [Number(match[1]), Number(match[2]), Number(match[3])];
  const real = new Date(Date.UTC(year, month - 1, day));
  if (real.getUTCFullYear() !== year || real.getUTCMonth() !== month - 1 || real.getUTCDate() !== day) return null;
  return `${match[3]}-${match[2].padStart(2, "0")}-${match[1].padStart(2, "0")}`;
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
  const match = value.match(/^(\d{1,4})\.?(?:\s*-\s*(\d{1,4})\.?)?$/);
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
  const match = clean(text).match(/^(\d{1,6})\s*\/\s*(\d{1,6})\s*F$/i);
  return match ? { points: Number(match[1]), finals: Number(match[2]) } : null;
}

/** Points from one competition: "18/F" (danced the final) or "4". Empty when KSIS awarded none. */
export interface KsisEarned {
  points: number;
  final: boolean;
}

export function parseEarned(text: string): KsisEarned | null {
  const match = clean(text).match(/^(\d{1,6})(\s*\/\s*F)?$/i);
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

/** A name whatever the order of its words: KSIS lists write "Priezvisko Meno", the search and WDSF "Meno Priezvisko". */
export function nameKey(name: string): string {
  return normalizeDancerName(name).split(" ").filter((word) => word.length > 0).sort().join(" ");
}

export function isSameCouple(a: KsisPairNames, b: KsisPairNames): boolean {
  return nameKey(a.partner) === nameKey(b.partner) && nameKey(a.partnerka) === nameKey(b.partnerka);
}

/** Which of the two the dancer is, by name alone; nil when neither. */
export function sideInPair(dancerName: string, couple: KsisPairNames): "partner" | "partnerka" | null {
  const name = nameKey(dancerName);
  if (name === "") return null;
  if (nameKey(couple.partner) === name) return "partner";
  return nameKey(couple.partnerka) === name ? "partnerka" : null;
}

export type Discipline = "STT" | "LAT" | "10T";

/**
 * "Dospelí D ŠTT" → "STT". Only reads the discipline KSIS writes last: "ŠTT" and "LAT", "ST" and "LA" in the WDSF
 * categories held in Slovakia, and "10T" for the ten-dance of the Slovak championship; nothing else is inferred.
 */
export function disciplineOf(category: string): Discipline | null {
  const last = clean(category).split(" ").at(-1);
  if (last === "10T") return "10T";
  return last === "ŠTT" || last === "ST" ? "STT" : last === "LAT" || last === "LA" ? "LAT" : null;
}

/** WDSF categories on the couple's page are written in English: "Rising Stars Standard", "Adult Latin". */
export function wdsfDisciplineOf(category: string): "STT" | "LAT" | null {
  const last = clean(category).split(" ").at(-1);
  return last === "Standard" ? "STT" : last === "Latin" ? "LAT" : null;
}

/**
 * A WDSF result has no KSIS competition id, but a saved result needs a number that is the same every time for the
 * same row. It is negative, so it never meets a real id (FNV-1a over the date, event and category).
 */
export function wdsfResultId(row: { date: string | null; eventName: string; category: string }): number {
  let hash = 0x811c9dc5;
  for (const char of `${row.date}|${row.eventName}|${row.category}`) {
    hash = Math.imul(hash ^ (char.codePointAt(0) ?? 0), 0x01000193) >>> 0;
  }
  return -((hash % 2_147_483_646) + 1);
}

/** A competition not danced yet, or from before KSIS, is not a result anybody has. */
export function isPlausibleDate(isoDate: string): boolean {
  const tomorrow = new Date(Date.now() + 36 * 60 * 60 * 1000).toISOString().slice(0, 10);
  return isoDate >= "1995-01-01" && isoDate <= tomorrow;
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
  return couple.pairNumber === member.personNumber ? "partner" : sideInPair(member.name, couple);
}

// ── Search (search.php?hladany_text=…) ───────────────────────────────────────────────────────────

export interface KsisSearchCouple extends KsisPairNames {
  /** par.php?id=. One couple can have two ids, and an id can carry a later partnerka as well. */
  parId: number;
  club: string;
  /** "Počet súťaží" of this row; a couple that changed club has one row per club. */
  competitions: number;
}

const SEARCH = "vyhľadávanie";

/**
 * Couples, judges and officials whose name contains the text, diacritics ignored, in one table without pages.
 * Only couples are read. Unlike the couples list it keeps the couples that ended, and it is the only list with their ids.
 */
export function parseSearchResults(html: string): KsisSearchCouple[] {
  const $ = load(html, SEARCH);
  const table = "table.table";
  if ($(table).length === 0) throw layoutChanged(SEARCH, "no results table");
  expectColumns(SEARCH, columnTitles($, table), ["Pár/Rozhodca/Funkcionár", "Klub", "Počet súťaží"]);
  return $(table).first().find("tbody tr").toArray().flatMap((tr) => {
    const td = $(tr).find("td");
    const link = $(td[0]).find("a[href*='par.php?id=']");
    const parId = idFrom(link.attr("href"), "id");
    const names = splitPair(link.text());
    const competitions = intOrNull($(td[2]).text());
    // A judge, an official, "Nenašli sa žiadne záznamy" and KSIS's couples without names are not couples to keep.
    if (parId === null || names.partner === "" || names.partnerka === "" || competitions === null) return [];
    return [{ parId, ...names, club: clean($(td[1]).text()), competitions }];
  });
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
  /** Rows of the history that could not be read and were left out, each as a short description without its content. */
  skippedRows: string[];
}

const COUPLE_PAGE = "stránka páru";

const MAX_HISTORY_ROWS = 1000;
const HISTORY_TITLES = ["Dátum", "Podujatie", "Súťaž", "Počet párov", "Umiestnenie", "Body", "Body po"];

/**
 * The competitions in the couple page's table, found by the column titles and not by position: a column added or
 * moved does not hide the history. A couple without competitions has a page without that table, which is an empty
 * history; a table with some of the known titles but not all of them, or with rows and none of them, is a changed page.
 *
 * A row that cannot be read (an old competition KSIS keeps without its page, a note row of another shape) is left out
 * and described in `skipped`; the rest of the history is kept. When more than a quarter of the rows cannot be read, or
 * none can, the page is a changed one: one such row used to throw away a career of 90 competitions.
 */
function coupleHistory($: CheerioAPI): { history: KsisHistoryRow[]; skipped: string[] } {
  const tables: TableElement[] = $("table").toArray();
  const starts = tables.map((table) => columnStarts($, table));
  const found = starts.findIndex((titles) => HISTORY_TITLES.every((title) => titles.has(title)));
  if (found < 0) {
    const knownTitles = starts.some((titles) => HISTORY_TITLES.some((title) => titles.has(title)));
    // A note in place of rows ("no records") is no data; a table with real rows and no title we know is a changed page.
    const hasRows = tables.some((table) =>
      $(table).find("tr").toArray().some((tr) => {
        const td = $(tr).children("td").toArray();
        return td.length > 1 || (td.length === 1 && $(td[0]).attr("colspan") === undefined);
      })
    );
    if (knownTitles || hasRows) throw layoutChanged(COUPLE_PAGE, `history table changed; ${outline($)}`);
    return { history: [], skipped: [] };
  }
  const at = (title: string): number => starts[found].get(title) ?? 0;
  const last = Math.max(...HISTORY_TITLES.map(at));
  const skipped: string[] = [];
  // A career has a few hundred competitions; the newest come first.
  const history = $(tables[found]).find("tr").toArray().slice(0, MAX_HISTORY_ROWS + 1).flatMap((tr, index) => {
    const td = $(tr).children("td").toArray();
    if (td.length === 0) return [];
    // A note in place of a row ("no records") is not a competition.
    if (td.length === 1 && $(td[0]).attr("colspan") !== undefined) return [];
    const event = $(td[at("Podujatie")]).find("a");
    const competition = $(td[at("Súťaž")]).find("a");
    const href = competition.attr("href") ?? "";
    const sutazId = idFrom(href, "sutaz_id");
    if (td.length <= last || (sutazId === null && !href.includes("worlddancesport.org"))) {
      skipped.push(`row ${index + 1}: ${td.length} cells, ${sutazId !== null ? "competition link with a number" : linkKind(href)}`);
      return [];
    }
    return [{
      date: parseKsisDate($(td[at("Dátum")]).text()),
      eventId: idFrom(event.attr("href"), "pod_id"),
      eventName: clean(event.text()),
      sutazId,
      category: clean(competition.text()),
      couples: intOrNull($(td[at("Počet párov")]).text()),
      place: parsePlace($(td[at("Umiestnenie")]).text()),
      earned: parseEarned($(td[at("Body")]).text()),
      after: parseStanding($(td[at("Body po")]).text()),
      hasCheckMark: $(tr).find(".glyphicon-ok").length > 0,
    }];
  });
  if (skipped.length > 0 && (history.length === 0 || skipped.length * 4 > history.length + skipped.length)) {
    throw layoutChanged(COUPLE_PAGE, `history row; ${skipped.slice(0, 3).join("; ")}; ${outline($)}`);
  }
  return { history, skipped };
}

/** What a history row's competition link is, for the report: no link, a link to another site (its host only), or a KSIS one without a number. */
function linkKind(href: string): string {
  if (href === "") return "no competition link";
  try {
    const host = new URL(href, "https://szts.ksis.eu/").hostname;
    return host === "szts.ksis.eu" ? "KSIS link without sutaz_id" : `link to ${host}`;
  } catch {
    return "link that is no address";
  }
}

export function parseCouplePage(html: string): KsisCouplePage {
  const $ = load(html, COUPLE_PAGE);
  const header = $("div.jumbotron");
  const title = clean(header.find("h3").first().text());
  if (!title) throw layoutChanged(COUPLE_PAGE, "couple title missing");
  const info = clean(header.find("h5").first().text());
  const classLabel = (label: string): KsisClassLabel | null => {
    const match = info.match(new RegExp(`Výkonnostná trieda ${label}:\\s*([^\\s(]+)(?:\\s*\\(([^)]*)\\))?`));
    // KSIS writes "-" for no class (a couple that has no competition): that is no class.
    return match && match[1] !== "-" ? { className: match[1], standing: match[2] ? parseStanding(match[2]) : null } : null;
  };
  const age = info.match(/Veková kategória:\s*(.+?)\s*(?:Výkonnostná|$)/);

  const { history, skipped } = coupleHistory($);

  return {
    ...splitPair(title),
    // The "Rozdeliť ŠTT a LAT" button links back to this page and is the only place with its id.
    parId: idFrom($("a[href*='par.php?id=']").first().attr("href"), "id"),
    club: clean(header.find("p").first().text()),
    ageCategory: age && age[1] !== "-" ? age[1] : null,
    stt: classLabel("ŠTT"),
    lat: classLabel("LAT"),
    history,
    skippedRows: skipped,
  };
}

/** A row of the couple's history that is kept as a result. */
export interface StoredHistoryRow {
  entry: KsisHistoryRow;
  date: string;
  discipline: Discipline;
  /** KSIS's own number, or a negative one made from the row for a WDSF result (`wdsfResultId`). */
  sutazId: number;
  isWdsf: boolean;
}

/**
 * The rows of a couple's history that are kept: every competition KSIS has a number for (once each), and the WDSF
 * ones KSIS lists without a number, which give only the place and the number of couples. A WDSF competition held in
 * Slovakia is listed twice, with a number and without; the one with the number is kept.
 */
export function historyToStore(history: KsisHistoryRow[]): StoredHistoryRow[] {
  const seen = new Set<number>();
  const ksis: StoredHistoryRow[] = [];
  const wdsfRows: KsisHistoryRow[] = [];
  for (const entry of history) {
    if (entry.date === null || !isPlausibleDate(entry.date)) continue;
    if (entry.sutazId === null) {
      wdsfRows.push(entry);
      continue;
    }
    const discipline = disciplineOf(entry.category);
    if (!discipline || seen.has(entry.sutazId)) continue;
    seen.add(entry.sutazId);
    ksis.push({ entry, date: entry.date, discipline, sutazId: entry.sutazId, isWdsf: false });
  }
  const wdsf = wdsfRows.flatMap((entry): StoredHistoryRow[] => {
    const discipline = wdsfDisciplineOf(entry.category);
    if (!discipline || entry.date === null || entry.place === null) return [];
    const listedWithNumber = ksis.some((known) =>
      known.date === entry.date && known.discipline === discipline && known.entry.couples === entry.couples &&
      known.entry.place?.text === entry.place?.text
    );
    const sutazId = wdsfResultId(entry);
    if (listedWithNumber || seen.has(sutazId)) return [];
    seen.add(sutazId);
    return [{ entry, date: entry.date, discipline, sutazId, isWdsf: true }];
  });
  return [...ksis, ...wdsf];
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
   * "Tieňová porota", listed under the judges with letters from A again. KSIS publishes no marks of theirs and
   * "Suma" holds none (checked on 47 rounds of 30 competitions), so they never take a column.
   */
  shadowJudges: KsisJudge[];
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
  const judges: KsisJudge[] = [];
  const shadowJudges: KsisJudge[] = [];
  for (const a of $("a[href*='rozhodca.php']").toArray()) {
    const match = clean($(a).text()).match(/^([A-Z])\s*-\s*(.+?)(?:\s*\(([^)]*)\))?$/);
    if (!match) throw layoutChanged(page, "judge entry");
    const judge = { letter: match[1], name: match[2], city: match[3] ?? null };
    const isShadow = $(a).prevAll("i").toArray().some((label) => /tieňová porota/i.test($(label).text()));
    (isShadow ? shadowJudges : judges).push(judge);
  }

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
    shadowJudges,
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
/** "Suma" of a round is crosses or placings (tens) or a score (hundreds); nothing near this. */
const MAX_SUM = 100_000;

export function parseMarks(html: string): KsisMarks {
  const $ = load(html, MARKS);
  const competition = parseCompetition($, MARKS);
  // A competition whose marks KSIS has not published has its header and no table.
  if ($("table.table").length === 0) return { competition, dances: [], judgeColumns: 0, rounds: [] };
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
    if (sumText === "" || !Number.isFinite(sum) || Math.abs(sum) > MAX_SUM) throw layoutChanged(MARKS, `sum in ${round.name}`);
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
    if (marks.length > 0 && marks.every((mark) => /^\d{1,6}\.\d{1,6}$/.test(mark))) {
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
  // A series that has not started has its title and no table yet.
  if ($("table.table").length === 0) {
    return { year: intOrNull(rest.slice(0, cut)), category: rest.slice(cut + 3), countedRounds: counted ? Number(counted[1]) : null, rounds: [], entries: [] };
  }

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
