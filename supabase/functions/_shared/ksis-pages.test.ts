// Run: deno test --allow-read --allow-env supabase/functions/_shared/ksis-pages.test.ts
// Fixtures are real KSIS pages saved on 9. 10. and 25. 10. 2026 with every person name replaced (fixtures/ksis/,
// scripts/anonymize-ksis-fixture.js).
import { assert, assertEquals, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  coupleRounds,
  disciplineOf,
  historyToStore,
  isChallengePage,
  isSameCouple,
  KsisPageError,
  parseCoupleDetail,
  parseCouplePage,
  parseCouplesList,
  parseEarned,
  parseKsisDate,
  parseMarks,
  parseMembersList,
  parsePlace,
  parseRegistrations,
  parseResults,
  parseSearchResults,
  parseSlpStandings,
  parseStanding,
  registeredCategories,
  sideInCouple,
  sideInPair,
  splitPair,
  wdsfDisciplineOf,
  wdsfResultId,
} from "./ksis-pages.ts";

const fixture = (name: string): string =>
  Deno.readTextFileSync(decodeURIComponent(new URL(`../../../fixtures/ksis/${name}`, import.meta.url).pathname));

const PAIR_NUMBER = 95397;
const PAR_ID = 18978;
const COUPLE = { partner: "Tanečný Adam", partnerka: "Tanečná Eva" };

function assertLayoutChanged(read: () => unknown): void {
  const error = assertThrows(read, KsisPageError);
  assertEquals(error.kind, "layout_changed");
}

// ── Small values ─────────────────────────────────────────────────────────────────────────────────

Deno.test("places, standings and points read exactly as KSIS writes them", () => {
  assertEquals(parsePlace("3."), { from: 3, to: 3, text: "3." });
  assertEquals(parsePlace("12. - 13."), { from: 12, to: 13, text: "12. - 13." });
  assertEquals(parsePlace("1 - 2"), { from: 1, to: 2, text: "1 - 2" });
  assertEquals(parsePlace("10"), { from: 10, to: 10, text: "10" });
  assertEquals(parsePlace(""), null);
  assertEquals(parseStanding("89/5F"), { points: 89, finals: 5 });
  assertEquals(parseStanding("0/0F"), { points: 0, finals: 0 });
  assertEquals(parseStanding(""), null);
  assertEquals(parseEarned("18/F"), { points: 18, final: true });
  assertEquals(parseEarned("4"), { points: 4, final: false });
  assertEquals(parseEarned(""), null);
  assertEquals(splitPair("Kułach Michał  - Adamczyk Julia "), { partner: "Kułach Michał", partnerka: "Adamczyk Julia" });
  assertEquals(splitPair("Nováková-Horváthová Anna - X Y"), { partner: "Nováková-Horváthová Anna", partnerka: "X Y" });
  assertEquals(disciplineOf("Dospelí D ŠTT"), "STT");
  assertEquals(disciplineOf("Junior II C LAT"), "LAT");
  assertEquals(disciplineOf("Dospelí D"), null);
  // WDSF competitions held in Slovakia have a KSIS id and write the discipline short.
  assertEquals(disciplineOf("WDSF International Open ST"), "STT");
  assertEquals(disciplineOf("WDSF Rising Stars LA"), "LAT");
  // The ten-dance of the Slovak championship is its own discipline.
  assertEquals(disciplineOf("MSR Dospelí 10T"), "10T");
  // An E class has no discipline and KSIS does not keep its results: not saved.
  assertEquals(disciplineOf("Deti II E"), null);
});

Deno.test("Cloudflare challenge is recognised, the normal page script is not", () => {
  assert(isChallengePage("<html><head><title>Just a moment...</title></head></html>"));
  assert(isChallengePage("<h1>Prebieha bezpečnostné overenie</h1>"));
  assert(!isChallengePage(fixture("results_12094.html") +
    "<script>a.src='/cdn-cgi/challenge-platform/scripts/jsd/main.js'</script>"));
  const error = assertThrows(() => parseMarks("<title>Just a moment...</title>"), KsisPageError);
  assertEquals(error.kind, "blocked");
});

// ── Finding and linking the couple ───────────────────────────────────────────────────────────────

Deno.test("couples list: the couple found by its pair number", () => {
  assertEquals(parseCouplesList(fixture("couples_list_95397.html")), [{
    pairNumber: PAIR_NUMBER,
    ...COUPLE,
    club: "TK ELLEGANCE Košice",
    ageCategory: "Dospelí",
    sttClass: "D",
    latClass: "D",
    status: "Aktívny",
  }]);
});

Deno.test("couples list: a couple that no longer dances has no status and no classes", () => {
  assertEquals(parseCouplesList(fixture("couples_list_ended.html")), [{
    pairNumber: 90001,
    partner: "Bývalý Tanečník",
    partnerka: "Bývalá Tanečnica",
    club: "TK ELLEGANCE Košice",
    ageCategory: "Mládež",
    sttClass: "-",
    latClass: "-",
    status: "",
  }]);
});

Deno.test("members list: personal number, name, club and both classes, also for members who stopped", () => {
  const members = parseMembersList(fixture("members_list.html"));
  assertEquals(members.length, 4);
  assertEquals(members[0], {
    personNumber: PAIR_NUMBER,
    name: "Tanečný Adam",
    club: "TK ELLEGANCE Košice",
    section: "Sekcia TŠ",
    sttClass: "D",
    latClass: "D",
    active: true,
  });
  assertEquals(members[1].sttClass, "C");
  assertEquals(members[1].latClass, "D");
  assertEquals(members[2].active, false);
  assertEquals([members[2].sttClass, members[2].latClass], ["B", "B"]);
  assertEquals([members[3].section, members[3].sttClass], ["Sekcia IDO", ""]);
});

Deno.test("the side in a couple comes from the pair number or the partnerka's name", () => {
  const [adam, eva, former, other] = parseMembersList(fixture("members_list.html"));
  const [couple] = parseCouplesList(fixture("couples_list_95397.html"));
  const [ended] = parseCouplesList(fixture("couples_list_ended.html"));
  assertEquals(sideInCouple(adam, couple), "partner");
  assertEquals(sideInCouple(eva, couple), "partnerka");
  assertEquals(sideInCouple({ ...eva, name: "TANECNA  Eva" }, couple), "partnerka");
  assertEquals(sideInCouple(former, ended), "partner");
  assertEquals(sideInCouple(other, couple), null);
  assertEquals(sideInCouple({ ...eva, name: "Eva Tanečná" }, couple), "partnerka");
});

// ── Search ───────────────────────────────────────────────────────────────────────────────────────

const SEARCH_EMPTY = `<table class="table table-striped table-hover" border="0"><thead><tr><th class="titulka">Pár/Rozhodca/Funkcionár</th>` +
  `<th class="titulka">Klub</th><th class="titulka">Počet súťaží</th><th class="titulka"></th></tr></thead>` +
  `<tbody><tr><td colspan="2"> Nenašli sa žiadne záznamy...</td></tr></tbody></table>`;

Deno.test("search: every couple with its KSIS id; judges and couples without names are left out", () => {
  const rows = parseSearchResults(fixture("search_tanecny.html"));
  assertEquals(rows.map((row) => row.parId), [17340, 20046, 11404, 15104, 15104, 18978, 15129, 15129, 12001]);
  assertEquals(rows[0], { parId: 17340, partner: "Adam Tanečný", partnerka: "Eva Tanečná", club: "TK Ellegance Košice", competitions: 1 });
  assertEquals(rows.filter((row) => row.parId === 15104).map((row) => [row.club, row.competitions]), [
    ["TK DANSOVIA Bratislava", 85],
    ["TK ELLEGANCE Košice", 6],
  ]);
  assertEquals(parseSearchResults(SEARCH_EMPTY), []);
  assertLayoutChanged(() => parseSearchResults("<h3>Výsledky vyhladávania</h3>"));
});

Deno.test("search: the dancer's couples by name in either order, without diacritics and in capitals", () => {
  const rows = parseSearchResults(fixture("search_tanecny.html"));
  const ids = (name: string) => rows.filter((row) => sideInPair(name, row) !== null).map((row) => row.parId);
  // 20046 is a namesake abroad: the dancer unticks it. 15129 and 11404 only contain the searched text.
  assertEquals(ids("Tanečný Adam"), [17340, 20046, 15104, 15104, 18978, 12001]);
  assertEquals(ids("Tanečná Eva"), [17340, 18978]);
  assertEquals(sideInPair("Tanečná Eva", rows[0]), "partnerka");
  assertEquals(ids(""), []);
  // One couple under two ids.
  assert(isSameCouple(rows[0], rows[5]));
  assert(!isSameCouple(rows[0], rows[1]));
});

Deno.test("couple detail: class, points, finals and last change for both disciplines", () => {
  assertEquals(parseCoupleDetail(fixture("couple_detail_95397.html")), {
    pairNumber: PAIR_NUMBER,
    partner: { surname: "Tanečný", firstName: "Adam" },
    partnerka: { surname: "Tanečná", firstName: "Eva" },
    club: "TK ELLEGANCE Košice",
    ageCategory: "Dospelí",
    year: 2026,
    stt: { className: "D", points: 89, finals: 5, lastChange: "2026-09-12" },
    lat: { className: "D", points: 91, finals: 5, lastChange: "2026-09-12" },
  });
});

Deno.test("couple page: standings and the whole history", () => {
  const page = parseCouplePage(fixture("couple_page_18978.html"));
  assertEquals(page.partner, COUPLE.partner);
  assertEquals(page.partnerka, COUPLE.partnerka);
  assertEquals(page.parId, PAR_ID);
  assertEquals(page.club, "TK ELLEGANCE Košice");
  assertEquals(page.ageCategory, "Dospelí");
  assertEquals(page.stt, { className: "D", standing: { points: 89, finals: 5 } });
  assertEquals(page.lat, { className: "D", standing: { points: 91, finals: 5 } });
  assertEquals(page.history.length, 18);

  assertEquals(page.history[0], {
    date: "2026-09-12",
    eventId: 1088,
    eventName: "Košice Grand Prix 2026 - Parket B",
    sutazId: 12094,
    category: "Dospelí D ŠTT",
    couples: 13,
    place: { from: 3, to: 3, text: "3." },
    earned: { points: 18, final: true },
    after: { points: 89, finals: 5 },
    hasCheckMark: true,
  });
  const shared = page.history.find((row) => row.sutazId === 11486);
  assertEquals(shared?.place, { from: 12, to: 13, text: "12. - 13." });
  assertEquals(shared?.earned, { points: 3, final: false });
  assertEquals(shared?.after, { points: 19, finals: 1 });
  // A competition without points: KSIS leaves "Body", "Body po" and the check mark empty.
  const last = page.history.at(-1);
  assertEquals(last?.sutazId, 11196);
  assertEquals(last?.couples, 3);
  assertEquals(last?.earned, null);
  assertEquals(last?.after, null);
  assertEquals(last?.hasCheckMark, false);
});

Deno.test("the newest result on the couple page agrees with the couple detail", () => {
  const page = parseCouplePage(fixture("couple_page_18978.html"));
  const detail = parseCoupleDetail(fixture("couple_detail_95397.html"));
  const newest = (discipline: "STT" | "LAT") => page.history.find((row) => disciplineOf(row.category) === discipline);
  assertEquals(newest("STT")?.after, { points: detail.stt.points!, finals: detail.stt.finals! });
  assertEquals(newest("LAT")?.after, { points: detail.lat.points!, finals: detail.lat.finals! });
});

// ── Results and judges ───────────────────────────────────────────────────────────────────────────

Deno.test("results: competition header, judges and every couple's placing", () => {
  const { competition, rows } = parseResults(fixture("results_12094.html"));
  assertEquals(competition.sutazId, 12094);
  assertEquals(competition.eventId, 1088);
  assertEquals(competition.eventName, "Košice Grand Prix 2026 - Parket B");
  assertEquals(competition.category, "Dospelí D ŠTT");
  assertEquals(competition.date, "2026-09-12");
  assertEquals(competition.venue, "Spoločenský pavilón, Trieda SNP 61, Košice");
  assertEquals(competition.organizer, "TK Ellegance Košice");
  assertEquals(competition.type, "Bodovacia");
  assertEquals(competition.advancement, [13, 9, 6]);
  assertEquals(competition.couples, 13);
  assertEquals(competition.judges.map((judge) => judge.letter), ["A", "B", "C", "E", "F", "G"]);
  assertEquals(competition.judges[0].city, "Ukrajina");
  assertEquals(competition.hiddenJudgeLetters, ["D"]);

  assertEquals(rows.length, 13);
  assertEquals(rows.map((row) => row.place?.from), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]);
  assertEquals(rows.filter((row) => row.round === "Finále").length, 6);
  assertEquals(rows.filter((row) => row.round === "Semifinále").length, 3);
  assertEquals(rows.filter((row) => row.round === "1.kolo").length, 4);

  const ours = rows.find((row) => row.parId === PAR_ID);
  assertEquals(ours, {
    round: "Finále",
    place: { from: 3, to: 3, text: "3." },
    startNumber: "61",
    parId: PAR_ID,
    ...COUPLE,
    club: "TK ELLEGANCE Košice",
    points: 18,
    total: { points: 89, finals: 5 },
    slp: null,
    hasCheckMark: true,
  });
  const noCheck = rows.find((row) => row.startNumber === "30");
  assertEquals(noCheck?.hasCheckMark, false);
  assertEquals(noCheck?.points, 6);
});

Deno.test("marks: dances, judge columns and rounds", () => {
  const marks = parseMarks(fixture("marks_12094.html"));
  assertEquals(marks.dances, ["WALTZ", "TANGO", "VIENNESE WALTZ", "QUICKSTEP"]);
  assertEquals(marks.judgeColumns, 6);
  assertEquals(marks.rounds.map((round) => [round.name, round.kind, round.entries.length]), [
    ["1.kolo", "crosses", 13],
    ["Semifinále", "crosses", 9],
    ["Finále", "final", 6],
  ]);
  assertEquals(marks.competition.hiddenJudgeLetters, ["D"]);
});

Deno.test("our couple round by round: crosses by judge, Suma, place and Postup", () => {
  const [first, semi, final] = coupleRounds(parseMarks(fixture("marks_12094.html")), PAR_ID);

  // 1. kolo: all 24 published crosses; KSIS "Suma" 28 also counts hidden judge D (4 dances × 1).
  assertEquals(first.round, "1.kolo");
  assertEquals(first.visibleCrosses, 24);
  assertEquals(first.sum, 28);
  assertEquals(first.hiddenCrosses, 4);
  assertEquals(first.place, { from: 1, to: 2, text: "1 - 2" });
  assertEquals(first.advanced, true);
  assertEquals(first.couplesInRound, 13);
  assertEquals(first.advancedCount, 9);
  assert(first.dances.every((dance) => dance.crosses === 6));
  // Published columns belong to the judges in list order: the 4th column is judge E, not D.
  assertEquals(first.dances[0].marks.map((mark) => mark.letter), ["A", "B", "C", "E", "F", "G"]);

  // Semifinále: two dots (waltz from A, quickstep from B) → 22 published + 4 hidden = 26.
  assertEquals(semi.visibleCrosses, 22);
  assertEquals(semi.sum, 26);
  assertEquals(semi.hiddenCrosses, 4);
  assertEquals(semi.dances[0].marks.filter((mark) => mark.mark === ".").map((mark) => mark.letter), ["A"]);
  assertEquals(semi.dances[3].marks.filter((mark) => mark.mark === ".").map((mark) => mark.letter), ["B"]);
  assertEquals(semi.advanced, true);
  assertEquals(semi.advancedCount, 6);

  // Finále: each judge's placing per dance, KSIS total 15 and 3rd place.
  assertEquals(final.kind, "final");
  assertEquals(final.dances.map((dance) => dance.marks.map((mark) => mark.mark).join("")), ["331426", "144133", "633546", "363544"]);
  assertEquals(final.sum, 15);
  assertEquals(final.place, { from: 3, to: 3, text: "3" });
  assertEquals(final.advanced, null);
  assertEquals(final.visibleCrosses, null);
  assertEquals(final.hiddenCrosses, null);
});

Deno.test("every couple's Suma fits the published crosses plus one hidden judge", () => {
  const marks = parseMarks(fixture("marks_12094.html"));
  const parIds = new Set(marks.rounds.flatMap((round) => round.entries.map((entry) => entry.parId)));
  for (const parId of parIds) {
    for (const round of coupleRounds(marks, parId)) {
      if (round.kind === "crosses") assert(round.hiddenCrosses !== null, `round ${round.round} of a couple does not fit`);
    }
  }
});

Deno.test("Postup matches the advancement key 13 → 9 → 6", () => {
  const marks = parseMarks(fixture("marks_12094.html"));
  const advanced = marks.rounds.map((round) => round.entries.filter((entry) => entry.advanced).length);
  assertEquals(marks.rounds.map((round) => round.entries.length), marks.competition.advancement);
  assertEquals(advanced.slice(0, 2), marks.competition.advancement.slice(1));
});

Deno.test("results and marks agree on the final", () => {
  const { rows } = parseResults(fixture("results_12094.html"));
  const final = parseMarks(fixture("marks_12094.html")).rounds.at(-1)!;
  for (const entry of final.entries) {
    const row = rows.find((candidate) => candidate.parId === entry.parId);
    assertEquals(row?.round, "Finále");
    assertEquals(row?.startNumber, entry.startNumber);
    assertEquals(row?.place?.from, entry.place?.from);
  }
});

Deno.test("a changed page is reported instead of guessed", () => {
  assertLayoutChanged(() => parseMarks(fixture("marks_12094.html").replace(">Suma<", ">Súčet<")));
  assertLayoutChanged(() => parseMarks(fixture("marks_12094.html").replace('<td class="hodn">XXXXXX</td>', '<td class="hodn">XXXXX</td>')));
  assertLayoutChanged(() => parseMarks(fixture("marks_12094.html").replace('<td class="hodn">XXXXXX</td>', '<td class="hodn">XX?XXX</td>')));
  assertLayoutChanged(() => parseResults(fixture("results_12094.html").replace(">Celkom<", ">Spolu<")));
  assertLayoutChanged(() => parseResults(fixture("results_12094.html").replace(">Body<", ">Bodíky<")));
  assertLayoutChanged(() => parseSlpStandings(fixture("slp_standings_dospeli_stt.html").replace("2 (30)", "2 30")));
  assertLayoutChanged(() => parseCoupleDetail(fixture("couple_detail_95397.html").replace('id="body_STT"', 'id="points_STT"')));
  assertLayoutChanged(() => parseCouplesList(fixture("couples_list_95397.html").replace(">Partnerka<", ">Tanečnica<")));
  assertLayoutChanged(() => parseMembersList(fixture("members_list.html").replace(">Sekcia</th>", ">Oddiel</th>")));
});

// ── Registrations ────────────────────────────────────────────────────────────────────────────────

Deno.test("registrations: event, categories and couples", () => {
  const registrations = parseRegistrations(fixture("registrations_2271.html"));
  assertEquals(registrations.eventName, "DANCE CUP mesta Kežmarok,Ĺanový kvietok 2026-37 ročník");
  assertEquals(registrations.date, "2026-10-10");
  assertEquals(registrations.total, 192);
  assertEquals(registrations.categories.length, 18);
  assertEquals(registrations.categories[0].name, "Junior I D ŠTT");
  assertEquals(registrations.categories[0].couples.length, 14);
  assertEquals(registrations.categories[0].couples[1].club, "");
  assertEquals(registrations.categories[0].couples[1].country, "POL");
  const names = registrations.categories.flatMap((category) => category.couples.flatMap((c) => [c.partner, c.partnerka]));
  assert(names.every((name) => name === name.trim() && !name.includes("  ")));
});

Deno.test("registrations: the couple is found in its categories, diacritics and case do not matter", () => {
  const registrations = parseRegistrations(fixture("registrations_2271.html"));
  assertEquals(registeredCategories(registrations, COUPLE), ["Dospelí D ŠTT", "Dospelí D LAT"]);
  assertEquals(registeredCategories(registrations, { partner: "TANECNY ADAM", partnerka: "tanecna eva" }), ["Dospelí D ŠTT", "Dospelí D LAT"]);
  assertEquals(registeredCategories(registrations, { partner: COUPLE.partnerka, partnerka: COUPLE.partner }), []);
});

// ── Slovenský pohár, WDSF and absolute judging (pages saved on 25. 10. 2026) ────────────────────

Deno.test("Slovenský pohár round: the SLP place and points instead of class points", () => {
  const page = parseResults(fixture("results_slp_12250.html"));
  assertEquals(page.scoring, "slp");
  assertEquals(page.competition.category, "SP JUN ŠTT");
  assertEquals(page.rows.length, 22);
  const own = page.rows.find((row) => isSameCouple(row, COUPLE));
  // 22 Slovak couples: the winner gets 14 plus 21 beaten couples (Súťažný poriadok, článok 23).
  assertEquals(own?.slp, { place: { from: 1, to: 1, text: "1." }, points: 35 });
  assertEquals(own?.points, null);
  assertEquals(page.rows.at(-1)?.slp?.points, 0);
});

Deno.test("WDSF and cup results: placings without points", () => {
  const page = parseResults(fixture("results_wdsf_12131.html"));
  assertEquals(page.scoring, "none");
  assertEquals(page.rows.length, 17);
  assertEquals(page.rows[0].place?.from, 1);
  assert(page.rows.every((row) => row.points === null && row.total === null && row.slp === null));
});

Deno.test("shadow jury: listed apart, never takes a judge's column", () => {
  const page = parseMarks(fixture("marks_ajs_12248.html"));
  assertEquals(page.competition.judges.map((judge) => judge.letter).join(""), "ABCDEFGHIJKL");
  assertEquals(page.competition.shadowJudges.map((judge) => [judge.letter, judge.name]), [["A", "Rozhodca 13"]]);
  assertEquals(page.competition.hiddenJudgeLetters, []);
  assertEquals(page.judgeColumns, 12);
  const first = coupleRounds(page, page.rounds[0].entries[0].parId)[0];
  assertEquals(first.dances[0].marks.map((mark) => mark.letter).join(""), "ABCDEFGHIJKL");
  assertEquals(first.dances[0].marks[11].name, "Rozhodca 12");
});

Deno.test("absolute judging: crosses rounds stay, the final has one score per dance", () => {
  const page = parseMarks(fixture("marks_ajs_12248.html"));
  assertEquals(page.rounds.map((round) => `${round.name}:${round.kind}:${round.entries.length}`), [
    "1.kolo:crosses:25",
    "2.kolo:crosses:20",
    "Semifinále:crosses:12",
    "Finále:scores:6",
  ]);
  for (const entry of page.rounds[3].entries) {
    const final = coupleRounds(page, entry.parId).find((round) => round.kind === "scores");
    assert(final);
    // "Suma" is the sum of the dances' scores.
    const sum = final.dances.reduce((total, dance) => total + (dance.score ?? 0), 0);
    assert(Math.abs(sum - entry.sum) < 0.002, `${sum} vs ${entry.sum}`);
    assert(final.dances.every((dance) => dance.marks.length === 0 && dance.crosses === null));
  }
});

Deno.test("couple page with WDSF competitions: kept, without a KSIS competition id", () => {
  const page = parseCouplePage(fixture("couple_page_18967.html"));
  assertEquals(page.ageCategory, "Dospelí");
  assertEquals(page.stt, { className: "A", standing: { points: 12, finals: 1 } });
  assertEquals(page.lat, { className: "A", standing: { points: 44, finals: 2 } });
  assertEquals(page.history.length, 41);
  assertEquals(page.history.filter((row) => row.sutazId === null).length, 14);
  assertEquals([page.history[0].category, page.history[0].sutazId], ["SP ŠTT", 12171]);
});

Deno.test("Slovenský pohár standings: places, every round and the sum of the 4 best", () => {
  const page = parseSlpStandings(fixture("slp_standings_dospeli_stt.html"));
  assertEquals([page.year, page.category, page.countedRounds], [2026, "Dospelí Štandard", 4]);
  assertEquals(page.rounds.length, 5);
  assertEquals(page.rounds[0], { sutazId: 11575, venue: "ŠPORTOVÁ HALA ARÉNA POPRAD", date: "2026-03-28" });
  assertEquals(page.entries.length, 54);
  const own = page.entries.find((entry) => isSameCouple(entry, COUPLE));
  assertEquals(own?.place, { from: 2, to: 3, text: "2. - 3." });
  assertEquals(own?.rounds.map((round) => round?.points ?? null), [14, null, 7, 28, 29]);
  assertEquals(own?.rounds[2]?.place, { from: 9, to: 12, text: "9-12" });
  for (const entry of page.entries) {
    const best = entry.rounds.flatMap((round) => round ? [round.points] : []).sort((a, b) => b - a).slice(0, 4);
    assertEquals(best.reduce((sum, points) => sum + points, 0), entry.total);
  }
});

// ── Pages that are not as expected ───────────────────────────────────────────────────────────────

Deno.test("couple page without a history table is an empty history, not a changed page", () => {
  // A couple KSIS also knows under a second id, with no competition under it.
  const page = parseCouplePage(fixture("couple_page_18978.html").replace(/<table[\s\S]*<\/table>/, ""));
  assertEquals(page.history, []);
  assertEquals([page.partner, page.partnerka], [COUPLE.partner, COUPLE.partnerka]);
});

Deno.test("couple page: a table that only says there is nothing is an empty history", () => {
  const note = '<table class="table"><tbody><tr><td colspan="10">Nenašli sa žiadne záznamy</td></tr></tbody></table>';
  const page = parseCouplePage(fixture("couple_page_18978.html").replace(/<table[\s\S]*<\/table>/, note));
  assertEquals(page.history, []);
});

Deno.test("couple page: a column added in front of the history does not hide it", () => {
  const original = parseCouplePage(fixture("couple_page_18978.html"));
  const html = fixture("couple_page_18978.html")
    .replace("<thead><tr>", '<thead><tr><th class="titulka"></th>')
    .replaceAll("<tr><td>", "<tr><td></td><td>");
  const page = parseCouplePage(html);
  assertEquals(page.history.length, 18);
  assertEquals(page.history, original.history);
});

// A career of 90 competitions was thrown away for one row KSIS keeps without its competition page.
const OTHER_SITE = '<a href="https://www.idsf.net/old/12094">Dospelí D ŠTT</a>';
const FIRST_COMPETITION = '<a href="https://szts.ksis.eu/sutaz.php?sutaz_id=12094">Dospelí D ŠTT</a>';

Deno.test("couple page: a row whose competition has no KSIS page is left out and the rest is kept", () => {
  const original = parseCouplePage(fixture("couple_page_18978.html"));
  const page = parseCouplePage(fixture("couple_page_18978.html").replace(FIRST_COMPETITION, OTHER_SITE));
  assertEquals(page.history.length, original.history.length - 1);
  assertEquals(page.history, original.history.filter((row) => row.sutazId !== 12094));
  assertEquals(page.skippedRows, ["row 2: 10 cells, link to www.idsf.net"]);
});

Deno.test("couple page: a row with no link and a row with too few cells are left out, described without their content", () => {
  const noLink = fixture("couple_page_18978.html").replace(FIRST_COMPETITION, "Dospelí D ŠTT");
  assertEquals(parseCouplePage(noLink).skippedRows, ["row 2: 10 cells, no competition link"]);
  const short = fixture("couple_page_18978.html").replace(
    /<td>16<\/td><td>3\.<\/td><td style="width:20px">21\/F<\/td><td style="width:20px">91\/5F<\/td><td style="width:20px"><\/td><td style="width:10px">.*?<\/td><\/tr>/,
    "<td>16</td></tr>",
  );
  const page = parseCouplePage(short);
  assertEquals(page.history.length, 17);
  assertEquals(page.skippedRows, ["row 3: 5 cells, competition link with a number"]);
});

Deno.test("couple page: when more than a quarter of the rows cannot be read it is a changed page", () => {
  let changed = 0;
  const html = fixture("couple_page_18978.html").replace(/sutaz\.php\?sutaz_id=/g, (match) => (changed++ < 6 ? "other.php?id=" : match));
  const error = assertThrows(() => parseCouplePage(html), KsisPageError);
  assertEquals(error.kind, "layout_changed");
  assert(error.message.includes("history row"), error.message);
});

Deno.test("couple page: a few rows over the quarter's limit are still read (4 of 18)", () => {
  let changed = 0;
  const html = fixture("couple_page_18978.html").replace(/sutaz\.php\?sutaz_id=/g, (match) => (changed++ < 4 ? "other.php?id=" : match));
  const page = parseCouplePage(html);
  assertEquals(page.history.length, 14);
  assertEquals(page.skippedRows.length, 4);
});

Deno.test("couple page: when no row can be read it is a changed page", () => {
  const html = fixture("couple_page_18978.html").replace(/sutaz\.php\?sutaz_id=/g, "other.php?id=");
  const error = assertThrows(() => parseCouplePage(html), KsisPageError);
  assertEquals(error.kind, "layout_changed");
});

Deno.test("couple page: a history table with other titles is a changed page and the report names the titles", () => {
  const html = fixture("couple_page_18978.html").replace(">Dátum<", ">Termín<");
  const error = assertThrows(() => parseCouplePage(html), KsisPageError);
  assertEquals(error.kind, "layout_changed");
  assertEquals(error.page, "stránka páru");
  assert(error.message.includes("Termín"), error.message);
});

Deno.test("a changed column title in another page's table is reported with all the titles", () => {
  const html = fixture("couples_list_95397.html").replace(">Klub<", ">Oddiel<");
  const error = assertThrows(() => parseCouplesList(html), KsisPageError);
  assertEquals(error.kind, "layout_changed");
  assert(error.message.includes("Oddiel"), error.message);
});

Deno.test("marks KSIS has not published: no rounds, not a changed page", () => {
  const page = parseMarks(fixture("marks_12094.html").replace(/<table[\s\S]*<\/table>/, ""));
  assertEquals(page.rounds, []);
  assertEquals(page.competition.sutazId, 12094);
});

Deno.test("a cup series that has not started: no entries, not a changed page", () => {
  const page = parseSlpStandings(fixture("slp_standings_dospeli_stt.html").replace(/<table[\s\S]*<\/table>/, ""));
  assertEquals([page.category, page.entries, page.rounds], ["Dospelí Štandard", [], []]);
});

Deno.test("dates and numbers that cannot be real are not read", () => {
  assertEquals(parseKsisDate("31.02.2026"), null);
  assertEquals(parseKsisDate("99.99.2026"), null);
  assertEquals(parseKsisDate("29.02.2028"), "2028-02-29");
  assertEquals(parsePlace("9".repeat(30)), null);
  assertEquals(parseStanding(`${"9".repeat(30)}/5F`), null);
  assertEquals(parseEarned("9".repeat(30)), null);
});

Deno.test("a page cannot put a huge text or a huge sum into what is saved", () => {
  const page = parseCouplePage(fixture("couple_page_18978.html").replace("Košice Grand Prix 2026 - Parket B", "x".repeat(100_000)));
  assert(page.history.every((row) => row.eventName.length <= 400));
  assertLayoutChanged(() => parseMarks(fixture("marks_12094.html").replace("<td>15</td><td>10</td><td>-</td>", "<td>1e30</td><td>10</td><td>-</td>")));
});

Deno.test("couple page: a table with rows and none of the known titles is a changed page", () => {
  const other = '<table class="table"><thead><tr><th>Termín</th><th>Názov</th></tr></thead><tbody><tr><td>12.09.2026</td><td>GP</td></tr></tbody></table>';
  const error = assertThrows(() => parseCouplePage(fixture("couple_page_18978.html").replace(/<table[\s\S]*<\/table>/, other)), KsisPageError);
  assertEquals(error.kind, "layout_changed");
  assert(error.message.includes("Termín | Názov"), error.message);
});

// ── What is kept from a couple's history ────────────────────────────────────────────────────────

Deno.test("history to keep: each KSIS number once, the 10-dance, WDSF without a number, the Slovak WDSF only once", () => {
  const stored = historyToStore(parseCouplePage(fixture("couple_page_18967.html")).history);
  const ksis = stored.filter((row) => !row.isWdsf);
  const wdsf = stored.filter((row) => row.isWdsf);
  // 27 rows with a KSIS number: the national ones, 4 WDSF held in Slovakia ("ST", "LA") and the ten-dance of the championship.
  assertEquals(ksis.length, 27);
  assertEquals(ksis.filter((row) => row.discipline === "10T").map((row) => row.sutazId), [11517]);
  // 14 rows without a number; 4 of them are the same competitions as the Slovak ones with a number (place and couples agree).
  assertEquals(wdsf.length, 10);
  assert(wdsf.every((row) => row.sutazId < 0 && row.sutazId >= -2_147_483_646));
  assertEquals(new Set(stored.map((row) => row.sutazId)).size, stored.length);
  assert(!wdsf.some((row) => row.date === "2025-09-27" || row.date === "2025-09-28"));
  // Abroad there is only the WDSF record, and it is kept.
  const budapest = wdsf.find((row) => row.entry.eventName.startsWith("Budapest") && row.discipline === "LAT");
  assertEquals([budapest?.entry.place?.text, budapest?.entry.couples], ["27.", 32]);
  // A couple without any WDSF row keeps nothing of the kind.
  assertEquals(historyToStore(parseCouplePage(fixture("couple_page_18978.html")).history).filter((row) => row.isWdsf), []);
});

Deno.test("a WDSF result gets the same negative number every time and a different one for another row", () => {
  const row = { date: "2026-04-19", eventName: "Budapest,Hungary", category: "Rising Stars Standard" };
  assertEquals(wdsfResultId(row), wdsfResultId({ ...row }));
  assert(wdsfResultId(row) < 0 && wdsfResultId(row) >= -2_147_483_646);
  assert(wdsfResultId(row) !== wdsfResultId({ ...row, category: "Rising Stars Latin" }));
  assert(wdsfResultId(row) !== wdsfResultId({ ...row, date: "2026-04-18" }));
  assertEquals(wdsfDisciplineOf("Rising Stars Standard"), "STT");
  assertEquals(wdsfDisciplineOf("Adult Latin"), "LAT");
  assertEquals(wdsfDisciplineOf("Adult Ten Dance"), null);
});

Deno.test("a result from the future or from long before KSIS is not kept", () => {
  const history = parseCouplePage(fixture("couple_page_18978.html")).history;
  const future = { ...history[0], date: "2999-01-01", sutazId: 999_999 };
  const ancient = { ...history[0], date: "1980-01-01", sutazId: 999_998 };
  const kept = historyToStore([future, ancient, ...history]);
  assert(!kept.some((row) => row.sutazId === 999_999 || row.sutazId === 999_998));
  assertEquals(kept.length, history.length);
});

Deno.test("couple page of a couple without competitions: no age and no class, not a dash", () => {
  // As KSIS shows the second id of a couple that never danced under it.
  const html = fixture("couple_page_18978.html")
    .replace(/<table[\s\S]*<\/table>/, "<p>Nenašli sa žiadne záznamy...</p>")
    .replace(/<h5>[\s\S]*?<\/h5>/, "<h5>Veková kategória: -<br> Výkonnostná trieda ŠTT: -<br> Výkonnostná trieda LAT: -<br> </h5>");
  const page = parseCouplePage(html);
  assertEquals([page.ageCategory, page.stt, page.lat, page.history], [null, null, null, []]);
});

// ── Ten-dance and WDSF competitions: real pages (anonymized) ────────────────────────────────────

const OTHER_PAR_ID = 18967;

Deno.test("ten-dance of the Slovak championship: results without points, ten dances, crosses then scores", () => {
  const results = parseResults(fixture("results_10t_11517.html"));
  assertEquals(results.competition.category, "MSR Dospelí 10T");
  assertEquals(disciplineOf(results.competition.category), "10T");
  assertEquals([results.scoring, results.rows.length, results.competition.couples], ["none", 12, 12]);
  const own = results.rows.find((row) => isSameCouple(row, COUPLE));
  assertEquals([own?.round, own?.place?.text, own?.parId], ["Semifinále", "10. - 11.", OTHER_PAR_ID]);

  const marks = parseMarks(fixture("marks_10t_11517.html"));
  assertEquals(marks.dances, [
    "WALTZ", "TANGO", "VIENNESE WALTZ", "SLOW FOXTROT", "QUICKSTEP", "SAMBA", "CHA CHA CHA", "RUMBA", "PASO DOBLE", "JIVE",
  ]);
  assertEquals([marks.judgeColumns, marks.competition.judges.length, marks.competition.shadowJudges.length], [12, 12, 5]);
  assertEquals(marks.rounds.map((round) => `${round.name}:${round.kind}:${round.entries.length}`), ["Semifinále:crosses:12", "Finále:scores:6"]);
  // The couple that went out in the semifinal has the crosses of the ten dances; a finalist has one score per dance.
  const [semi] = coupleRounds(marks, OTHER_PAR_ID);
  assertEquals([semi.kind, semi.sum, semi.place?.text, semi.advanced, semi.dances.length], ["crosses", 4, "10 - 11", false, 10]);
  const finalist = coupleRounds(marks, marks.rounds[1].entries[0].parId).find((round) => round.kind === "scores");
  assert(finalist);
  assertEquals(finalist.dances.length, 10);
  assert(finalist.dances.every((dance) => dance.score !== null && dance.score > 0 && dance.marks.length === 0));
});

Deno.test("WDSF competition held in Slovakia: a KSIS competition with crosses and a final of placings", () => {
  const marks = parseMarks(fixture("marks_wdsf_11197.html"));
  assertEquals(marks.competition.category, "WDSF Rising Stars ST");
  assertEquals(disciplineOf(marks.competition.category), "STT");
  assertEquals([marks.dances.length, marks.judgeColumns, marks.competition.shadowJudges.length], [5, 11, 0]);
  assertEquals(marks.rounds.map((round) => `${round.name}:${round.kind}:${round.entries.length}`), ["Semifinále:crosses:10", "Finále:final:6"]);
  const [semi] = coupleRounds(marks, OTHER_PAR_ID);
  assertEquals([semi.kind, semi.sum, semi.place?.text, semi.advanced], ["crosses", 11, "8", false]);
});
