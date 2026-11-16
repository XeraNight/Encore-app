# Profil › Súťaže: prípady a stav kódu

Stav z 15. 11. 2026. Čo sa skúšalo, čo sa našlo, čo čaká na ÁNO. Testy: `EncoreTests/SutazeEdgeCaseTests.swift`. Plný beh Swift: 215 rôznych testov prešlo. Deno (`ksis-pages.test.ts`): 40 prešlo.

Značky: **test** = overené automatickým testom · **kód** = overené čítaním kódu · **iPhone** = dá sa overiť len na telefóne.

## 1. Opravené skôr (dddd39c, a945f3b, 5c643cc)

| # | Nález | Oprava | Overenie |
|---|-------|--------|----------|
| F1 | Kalendár KSIS sa čítal jedným výrazom cez celú stránku. Pri stránke zlého tvaru sa výraz z každého riadku hľadal až do konca stránky: test s 1 MB nezmyslu sa točil 40 minút na 100 % CPU a appka by na hlavnom vlákne visela. | `KSISCalendarPage.parse` číta riadok po riadku a odmietne stránku nad 1,5 MB (skutočný kalendár má ~50 kB). | test `aMegabyteOfNonsenseIsAnsweredQuickly` (limit 1 minúta), `KSISCalendarTests` s reálnou stránkou |
| F2 | Súčet krížikov „1e30“ z uloženej stránky zhodil appku (`Int(sum)`). Uložiť ho vie len ten, kto pošle vymyslenú stránku, ale výsledky vidia aj spojenia. | `sumText` ukáže veľké číslo ako číslo, nikdy ho nepreklápa na `Int`. | test `aHugeSumFromASavedPageIsShownAndNeverStopsTheApp` |
| F3 | `CompetitionManager` sťahoval páry a všetky výsledky (aj s krížikmi) pri každom obnovení prihlásenia (každú hodinu). Ostatné správcovia na to majú `removeDuplicates`. | Znovu sa načíta len pri skutočnej zmene účtu. | kód, build |
| F4 | Aktualizácia si zapamätala „KSIS nemá miesto“ aj vtedy, keď prišla iná stránka než tá, o ktorú sa žiadalo (presmerovanie, kontrola KSIS). Pamätá sa to natrvalo. | Stránka iného druhu sa počíta ako neúspech a pri ďalšej aktualizácii sa pýta znova. | kód, build |
| F5 | Jeden nečitateľný riadok výsledkov alebo krížikov skryl všetky výsledky; pomalá odpoveď mohla prepísať čerstvejšiu. | `LossyList`, číslo načítania, `unlink` vždy načíta znova. | testy v `SutazeEdgeCaseTests` |

## 2. Čo si Jakub vyžiadal 15. 11. večer (P1 až P10), stav

Všetko je commitnuté a **nasadené 16. 11. 2026**: migrácia `ksis_rate_limit_and_grants` je použitá (práv `TRUNCATE`/`TRIGGER`/`REFERENCES` pre `anon` a `authenticated`: 96 → 0) a `ksis-page` beží vo verzii 13. Aplikačné zmeny (kópia výsledkov na iPhone, hlásenie problémov, Plánovač) sú až v ďalšom TestFlight builde; server je so starým buildom 323 zlučiteľný.

| # | Čo | Rozhodnutie a stav |
|---|----|--------------------|
| P1 | Server uloží všetko, čo povie odoslané HTML | Hotové: text sa reže na 400 znakov, čísla na 9 číslic, súčet kola na 100 000, história na 1000 riadkov, neexistujúci dátum nie je dátum, telo nad 6 MB sa nečíta, adresa bez portu a mena. Čaká na nasadenie funkcie. |
| P2 | Zbytočné práva v databáze | Hotové v migrácii `20261116_ksis_rate_limit_and_grants.sql`: `TRUNCATE`, `TRIGGER`, `REFERENCES` preč pre `anon` a `authenticated` na **všetkých** tabuľkách `public` (nielen na dvoch: 96 práv na 19 tabuľkách, po migrácii 0) aj pre nové tabuľky; `anon` už nečíta výsledky ani páry. Skúška v transakcii, ktorá sa vrátila späť. Čaká na použitie migrácie. |
| P3 | Model zmazaný počas čakania na Apple Kalendár | Hotové: `isGone` po každom čakaní (tréning, súťaž, deň, séria) a `saveOrLog()` namiesto `try? save()` v celom Plánovači (29 miest). **Mimo Plánovača je ďalších 46 `try? save()`**, mechanická zmena, ak povieš. |
| P4 | Safari z okna KSIS | Hotové: otvorí sa len po ťuknutí na odkaz. |
| P5 | Kľúč udalosti kalendára | Hotové: bez čísla propozícií je to deň + názov + miesto a riadok uvedený dvakrát je jedna súťaž. |
| P6 | Pripomienky nad 64 | Hotové: pripomienky sa najprv zoberú do rady, appka drží 60 a pripomienky súťaží majú prednosť. |
| P7 | Dva obchody s dátami v `UserDefaults` | Hotové: `LocalFile` (súbor zapísaný naraz, nezálohuje sa) pre kalendár aj pohár a aj pre výsledky. |
| P8 | Výsledky bez internetu po štarte | Rozhodnuté: **áno**. Posledné odpovede servera (páry, výsledky s krížikmi) sa držia po účtoch v súboroch, po štarte sa ukážu hneď a odpoveď servera ich nahradí. Zmiznú pri odhlásení a pri zmazaní výsledku. Výsledky sa dekódujú mimo hlavného vlákna. |
| P9 | Počet volaní `ksis-page` | Hotové: 240 volaní za 10 minút na človeka (aktualizácia má asi sto), `429 rate_limited` zastaví aktualizáciu so správou. Ak sa počítadlo pokazí, aktualizácia ide ďalej. Čaká na migráciu a nasadenie. |
| P10 | Ručné okno KSIS a aktualizácia | Rozhodnuté: **ostáva**. Je to jediná cesta na „Toto som ja“, na prechádzanie KSIS a na živé krížiky v deň súťaže. Duplicitné je asi 120 riadkov (výber párov). Zužovať ho pred v1 je väčšie riziko než zisk; vrátime sa po spätnej väzbe. |

## 2a. Prečo „Niektoré stránky sa nepodarilo uložiť“ a čo Trenčín (vyriešené 16. 11.)

- Server odmietal **stránku páru** pre KSIS číslo **17340** (druhé číslo vášho páru): `stránka páru: column 1 is ""` (HTTP 422). Jakub stránku otvoril v prehliadači: ukazuje „Nenašli sa žiadne záznamy…“, teda pár bez súťaží. Prázdna história sa teraz berie ako prázdna, nie ako zmenená stránka (server v13). Po nasadení prešlo 28 volaní aktualizácie so stavom 200 a žiadne 422 a počítadlo `rate_limits` zaznamenalo 38 volaní, teda obmedzenie v ostrej prevádzke funguje.
- Číslo 18978: 12 súťaží, v každej ŠTT aj LAT, teda 24 riadkov, a to sedí s KSIS.
- „Trenčín“ na mape je v skutočnosti **Nové Mesto nad Váhom** (O Pohár Primátora Mesta Nové Mesto nad Váhom, 16. 11. 2025). **KSIS ukladá adresu najviac na 50 znakov**: „… 91501 Nové Mest“, takže appka mesto nespoznala a súťaž bola „Mimo mapy“. Štyri z deviatich dlhých adries v databáze majú takto odrezané mesto (aj Zvol, Kež, Trna). Oprava: odrezané mesto sa rozpozná, ak ide o adresu od 49 znakov, od začiatku slova, aspoň tri písmená a práve jedno mesto, ktoré tak začína (`SlovakCity.find`).

## 2b. Čo sa pri čítaní KSIS môže stať a čo appka urobí

| Prípad | Čo sa stane |
|--------|-------------|
| Overenie Cloudflare namiesto stránky | Aktualizácia čaká, kým ho dancer prejde; server vráti `blocked` a nič neuloží |
| Prišla iná stránka než tá, o ktorú sa žiadalo (presmerovanie) | Počíta sa ako neúspešné čítanie, nič sa nepamätá natrvalo, pri ďalšej aktualizácii sa pýta znova |
| Pár bez súťaží (druhé číslo páru) | Prázdna história, nie chyba |
| Stĺpec pridaný alebo posunutý v tabuľke histórie | Stĺpce sa nájdu podľa názvov |
| Tabuľka so zmenenými názvami | „Stránku „stránka páru“ KSIS sa nepodarilo prečítať…“ a log s názvami |
| Hodnotenie porotcov ešte nezverejnené | „KSIS zatiaľ nezverejnil hodnotenie“; nedávna súťaž (do 14 dní) sa pýta znova, staršia sa zapamätá |
| Séria pohára ešte nezačala | Prázdna tabuľka, nie chyba |
| Tá istá súťaž dvakrát na stránke páru | Uloží sa raz (inak by zlyhalo celé uloženie) |
| Dátum, ktorý ešte nenastal alebo je pred rokom 1995 | Neuloží sa |
| Obrovský text, číslo alebo súčet | Text sa reže, číslo nad 9 číslic a súčet nad 100 000 sa neprečíta |
| Príliš rýchle čítanie (skript) | 429, aktualizácia sa zastaví so správou |
| Appka zabitá uprostred aktualizácie | Uložené stránky zostanú, zvyšok pri ďalšej aktualizácii (**iPhone**) |
| Štart bez internetu | Posledné výsledky z iPhonu, kalendár aj pohár |
| Sieť padne uprostred aktualizácie | Aktualizácia sa zastaví, uložené zostáva |
| Odhlásenie alebo iný účet | Odpovede na ceste sa zahodia a kópia na iPhone sa zmaže |
| Dve zariadenia | Server ukladá podľa kľúča; každé zariadenie ukáže svoj posledný stiahnutý stav |

## 2c. Ďalšie prípady, ktoré môžu nastať (16. 11.)

**Opravené:**

| Prípad | Čo sa dialo | Oprava |
|--------|-------------|--------|
| Telefón s buddhistickým alebo japonským kalendárom | Rok pohára z `Calendar.current` bol iné číslo (2569) a KSIS dostal rok, ktorý neexistuje | `SlovakCup.currentYear`, jedno miesto namiesto štyroch kópií |
| WDSF súťaž na Slovensku („… ST“, „… LA“) | Má KSIS číslo aj výsledky, ale poznali sa len „ŠTT“ a „LAT“, takže ju server mlčky zahodil | „ST“ a „LA“ sa ukladajú ako Štandard a Latina |
| 429 od samotnej platformy (bez nášho tela) | Aktualizácia ďalej pýtala jednu stránku za druhou | Je to `rate_limited`, aktualizácia sa zastaví |

**Overené čítaním kódu, nie je treba nič robiť:** KSIS odpovie chybovou stránkou so stavom 200 (pomenovaná chyba, nič sa nepamätá) · dve zariadenia ukladajú naraz (kľúče; jedno zariadenie dostane chybu a opakuje) · účet sa prepne počas aktualizácie (odpovede sa zahodia, kópia je po účtoch) · poškodený alebo napoly zapísaný súbor kópie (zápis naraz, nečitateľné sa ignoruje) · plný disk (zapíše sa do logu) · dve súťaže s rovnakým názvom v ten deň (kľúč s miestom) · tá istá súťaž pod dvoma číslami páru (nemôže nastať, pár nemôže tancovať tú istú kategóriu dvakrát).

**Otvorené, s odporúčaním:**

| Prípad | Dôsledok | Odporúčanie |
|--------|----------|-------------|
| Krížiky sa čítali raz a „KSIS nemá“ sa pamätalo navždy | Krížiky zverejnené neskôr (organizátor mešká) sa nenačítali nikdy | Hotové: „KSIS nemal“ sa pamätá 30 dní a potom sa spýta znova; súťaž z posledných 14 dní sa pýta pri každej aktualizácii. Oprava výsledku organizátorom sa stále nečíta (výsledok sa opravuje pri čítaní stránky páru, krížiky nie) |
| Súťaž zmazaná alebo zmenená v KSIS | V appke ostane, kým sa pár neodpojí | Nechať; dá sa odpojiť a načítať znova |
| Stránka páru 17340 | Neviem, ako vyzerá (overenie Cloudflare) | Po nasadení Aktualizovať a pozrieť log |
| Zlé hodiny v telefóne | „Minulé“ a „nadchádzajúce“ sa prehodia | Len na iPhone; server používa vlastný čas |
| Telefón v inom jazyku | Dátumy v Plánovači sa píšu v jazyku telefónu aj v slovenskom texte | Kozmetika, po v1 |
| Zvyšných 46 `try? save()` mimo Plánovača | Zlyhanie uloženia sa nezapíše | Mechanická zmena, povedz |

## 2d. Čo KSIS má a appka neukladala (16. 11.)

Na vzorovej stránke páru s 41 riadkami histórie sa ukladalo 22; po opravách 27 + 10.

| Čo | Koľko na vzorovej stránke | Stav |
|----|---------------------------|------|
| WDSF „ST“ a „LA“ so slovenským číslom (Košice GP) | 4 | Hotové a nasadené (v13) |
| MSR Dospelí 10T (desaťtance, majstrovstvá, nie pohár) | 1 | Pripravené, **nenasadené** (pozri nižšie) |
| WDSF bez KSIS čísla (Košice, Budapešť; len miesto a počet párov) | 14, z toho 4 sú tie isté ako tie s číslom, ostáva 10 | Pripravené, **nenasadené** |
| Trieda E (deti) | | Nečíta sa: v KSIS ju Jakub nemá (rozhodnuté 16. 11.) |
| Sólo, formácie, choreo, showdance | | Nie sú na stránke páru. Neoverené, nečítame |
| Harmonogram, propozície | | Len odkazy z kalendára |

WDSF výsledok nemá KSIS číslo súťaže, preto dostane záporné číslo vyrobené z dátumu, podujatia a kategórie (rovnaké pri každom čítaní). Miesto je názov podujatia („Kosice,Slovakia“), takže sa ukáže na mape; zahraničné ide do „Mimo mapy“. Appka také súťaže nikdy nepýta v KSIS (nemajú stránku) a v detaile ukáže, že ide o WDSF. **Server aj appka sa musia nasadiť naraz**: starší build by pýtal stránky so záporným číslom. Webová appka (Antigravity): riadky so záporným `sutaz_id` nemajú KSIS stránku, odkazy z nich treba skryť.

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
