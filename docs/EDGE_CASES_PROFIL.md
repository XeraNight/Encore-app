# Profil › Súťaže: prípady a stav kódu

Stav z 15. 11. 2026. Čo sa skúšalo, čo sa našlo, čo čaká na ÁNO. Testy: `EncoreTests/SutazeEdgeCaseTests.swift`. Plný beh: 214 testov, 213 prešlo a jeden bol zle napísaný môj test (opravený, trieda Súťaží prešla celá).

Značky: **test** = overené automatickým testom · **kód** = overené čítaním kódu · **iPhone** = dá sa overiť len na telefóne.

## 1. Opravené a commitnuté (dddd39c, a945f3b, 5c643cc)

| # | Nález | Oprava | Overenie |
|---|-------|--------|----------|
| F1 | Kalendár KSIS sa čítal jedným výrazom cez celú stránku. Pri stránke zlého tvaru sa výraz z každého riadku hľadal až do konca stránky: test s 1 MB nezmyslu sa točil 40 minút na 100 % CPU a appka by na hlavnom vlákne visela. | `KSISCalendarPage.parse` číta riadok po riadku a odmietne stránku nad 1,5 MB (skutočný kalendár má ~50 kB). | test `aMegabyteOfNonsenseIsAnsweredQuickly` (limit 1 minúta), `KSISCalendarTests` s reálnou stránkou |
| F2 | Súčet krížikov „1e30“ z uloženej stránky zhodil appku (`Int(sum)`). Uložiť ho vie len ten, kto pošle vymyslenú stránku, ale výsledky vidia aj spojenia. | `sumText` ukáže veľké číslo ako číslo, nikdy ho nepreklápa na `Int`. | test `aHugeSumFromASavedPageIsShownAndNeverStopsTheApp` |
| F3 | `CompetitionManager` sťahoval páry a všetky výsledky (aj s krížikmi) pri každom obnovení prihlásenia (každú hodinu). Ostatné správcovia na to majú `removeDuplicates`. | Znovu sa načíta len pri skutočnej zmene účtu. | kód, build |
| F4 | Aktualizácia si zapamätala „KSIS nemá miesto“ aj vtedy, keď prišla iná stránka než tá, o ktorú sa žiadalo (presmerovanie, kontrola KSIS). Pamätá sa to natrvalo. | Stránka iného druhu sa počíta ako neúspech a pri ďalšej aktualizácii sa pýta znova. | kód, build |
| F5 | Jeden nečitateľný riadok výsledkov alebo krížikov skryl všetky výsledky; pomalá odpoveď mohla prepísať čerstvejšiu. | `LossyList`, číslo načítania, `unlink` vždy načíta znova. | testy v `SutazeEdgeCaseTests` |

## 2. Čaká na ÁNO

Poradie podľa dôležitosti.

| # | Nález | Navrhovaná oprava | Súbory |
|---|-------|-------------------|--------|
| P1 | Server uloží všetko, čo stránka v odoslanom HTML povie: dĺžku textov, počet kôl a rozhodcov, hodnoty súčtov. Vymyslená stránka tak môže nafúknuť riadok alebo dať spojeniam obrovský text. | Hranice pri čítaní (dĺžka textu, počet kôl, rozsah súčtu) a kontrola veľkosti tela ešte pred čítaním. Nasadí Jakub (`supabase functions deploy ksis-page`). | `_shared/ksis-pages.ts`, `ksis-page/index.ts`, test |
| P2 | `anon` a `authenticated` majú na `competition_results` a `user_couples` aj `TRUNCATE`, `TRIGGER`, `REFERENCES` (a `anon` aj `SELECT`). Cez REST sa to zneužiť nedá a RLS čítanie drží, ale právo je zbytočné. | `revoke` týchto práv. SQL ukážem pred nasadením. | migrácia |
| P3 | Po `await` sa siaha na modely SwiftData, ktoré medzitým mohli byť zmazané (`follow`, `setIntent`, uloženie súťaže). Zmazaný model pri čítaní zhodí appku. Navyše 29-krát `try? save()` zahodí chybu (napr. plný disk). | Po `await` model znovu nájsť podľa `id`; jeden pomocník na uloženie, ktorý chybu zapíše do `Logger`. | `Planner/PlannerCompetitionsView.swift`, `Planner/PlannerServices.swift`, … |
| P4 | Webové okno KSIS otvorí Safari aj pri presmerovaní, nielen po ťuknutí. | Mimo KSIS iba po ťuknutí na odkaz. | `KSISBrowserView.swift` |
| P5 | `KSISEvent.id` bez čísla propozícií je „dátum + názov“; dve súťaže s rovnakým názvom v ten deň by sa zlúčili v zozname. | Pridať miesto konania do kľúča. | `KSISCalendar.swift` |
| P6 | Pripomienky: iOS drží najviac 64 naplánovaných. Pri veľa tréningoch by sa pripomienky súťaží (sú najďalej) zahodili. | Súťaže naplánovať ako prvé a ak je ich veľa, skrátiť obdobie tréningov. | `PlannerServices.swift` |
| P7 | Kalendár a Slovenský pohár sú v `UserDefaults`; dva takmer rovnaké obchody s dátami. | Jeden malý pomocník na súbor v Application Support (menej kódu, žiadny limit veľkosti). | `KSISCalendar.swift`, `SlovakCup.swift` |
| P8 | Výsledky sa po štarte bez internetu nenačítajú (nie sú na disku). | Uložiť posledný stav na disk podľa účtu, alebo to nechať. Rozhodnutie je tvoje. | `CompetitionManager.swift` |
| P9 | `ksis-page` nemá obmedzenie počtu volaní na človeka. | Počítadlo ako pri `send-email`, nová SQL funkcia (ukážem pred nasadením). | `ksis-page/index.ts`, migrácia |
| P10 | `KSISBrowserView` (1059 riadkov) a `KSISUpdateSheet` robia čiastočne to isté (páry, história, krížiky). | Ručné okno zúžiť na „Toto som ja“ a prehliadanie KSIS. Produktové rozhodnutie. | `KSISBrowserView.swift` |

## 3. Prípady, ktoré sú overené

**Dáta zo servera, ktoré nie sú také, ako sa čaká (test):** krížiky, ktoré sa nedajú prečítať, neskryjú výsledok · `null` krížiky a rozhodcovia · neznáme polia z novšieho servera · jeden zlý riadok neskryje ostatné · prázdny zoznam · umiestnenie v každom tvare (`3.`, `12. – 13.`, prázdne) · neexistujúci dátum · výsledok bez dátumu nepadne do sezón · chýbajúce povinné pole je chyba, nie pád.

**Páry a mená (test):** ten istý pár cez medzery a poradie mien · pár bez mien · názov páru nikdy nie je prázdny · partner = druhé meno · pár bez tried ukáže prázdno, nie pomlčky · chýbajúca značka „aktuálny“ = aktuálny.

**Adresy a hľadanie (test):** meno so špeciálnymi znakmi · číslo ide do poľa čísla, ostatné do mena · prázdne hľadanie otvorí obyčajnú stránku · päťmiestne čísla párov · priezvisko = prvé slovo · kódovanie toho, čo tanečník napíše.

**Sezóny (test):** sezóna sa mení 1. septembra · názvy sezón sa nerozbijú · bez výsledkov je prázdna sezóna · krížiky zapísané čudne sa počítajú len keď sú krížiky.

**Plán a výsledky dňa (test):** dva výsledky v ten istý deň patria k tomu dňu · deň bez výsledkov nemá žeton miesta · vyhráva najlepšie miesto · súťaž neskoro večer sedí na svoj deň · prepojenie sa týka len minulých súťaží bez prepojenia · neznámy zámer súťaže sa otvorí ako „Zvažujem“.

**Kalendár KSIS (test):** prázdna stránka nie je kalendár · kontrola KSIS v akejkoľvek veľkosti písmen nie je kalendár · 1 MB nezmyslu · stránka načítaná z polovice nikdy nedá polovičnú udalosť · tá istá stránka dvakrát.

## 4. Čítaním kódu (bez testu)

- **Server, zápis:** zapisuje len edge funkcia (`authenticated` nemá INSERT/UPDATE/DELETE), RLS je `RESTRICTIVE` pre zablokované účty, výsledky spojení čítajú len tí, ktorí majú zapnuté zdieľanie (`shares_results_with`). Jedinečné kľúče držia „jeden aktuálny pár“ aj „jeden výsledok na súťaž a pár“.
- **Aktualizácia:** zatvorenie okna zruší čakanie na stránku aj otázky, uložené zostane. Dvojité ťuknutie na „Čítať ďalej“ je pri bežnom ťuknutí bezpečné (kým sa stav nezmení, stráži ho `isFinished`).
- **Žiadne pollovanie ani Realtime** v Súťažiach a Kalendári; sieť sa používa len na ťuknutie.
- **Delenie nulou, indexy, `!`:** prehľadané celé `Competitions/` a `Planner/`, všetko je strážené.

## 5. Len na iPhone

- Zabiť appku (z prehľadu aplikácií) uprostred aktualizácie z KSIS a otvoriť znova: uložené stránky zostanú, zvyšok sa dočíta.
- Prepnúť do inej appky počas „Aktualizovať“ a vrátiť sa po minúte.
- Lietadlový režim na začiatku aj uprostred aktualizácie.
- Overenie Cloudflare v okne KSIS a návrat do aktualizácie.
- Zmeniť čas telefónu (deň súťaže sa posunie, „minulé“ a „nadchádzajúce“ sa prehodia).
- Dve zariadenia: uložiť výsledok na jednom, na druhom potiahnuť na obnovenie.
