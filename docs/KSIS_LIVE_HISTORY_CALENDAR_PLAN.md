# KSIS: živé sledovanie súťaže, vyhľadávanie v histórii, kalendár a sezóna v číslach

> Stav: **návrh na schválenie** (12. 10. 2026). Nič z toho ešte nie je v kóde.
> Zdroj: nové stránky v `Encore:ksis-samples/` uložené počas súťaže 12206 (10. 10. 2026, Junior I D ŠTT, 12 párov, kľúč 12 → 6).

---

## 1. Čo ukázali nové stránky

| Stránka | Počas súťaže | Po vyhlásení postupu | Dnešný parser |
|---|---|---|---|
| `sutaz.php` (výsledková listina) | Blok kola („Semifinále“) so **všetkými** pármi v kole, bez umiestnenia. Stĺpce *Body* a *Celkom* majú **prázdne nadpisy**. | Navrchu blok „Finále“ (páry bez umiestnenia = **postúpili**), pod ním „Semifinále“ s umiestneniami 7.–12. (= **vypadli**). | **Padne**: `expectColumns` čaká `Body`, `Celkom` → používateľ vidí „Túto stránku KSIS sa nepodarilo prečítať“. |
| `hodnot_sut.php` (krížiky) | Len text „Hodnotenie bude až po ukončení súťaže !!!“. | rovnako | **Padne** na hlavičke stĺpcov. Má to byť stav „ešte nezverejnené“, nie chyba. |
| hlavička súťaže | Vedúci, tajomník, sčitatelia sa môžu objaviť aj zmiznúť. Názov klubu sa mení (rovnaký pár: „Polska“ → „Poland“). | | Parser ich nečíta, OK. Pár vždy spájať cez `par.php?id`, nikdy cez klub. |
| `sutaz_files/a_*.html` | Cloudflare challenge iframe. | | Ignorovať (`isChallengePage` už existuje). |

**Záver:** podmienka Fázy 2 z `KSIS_PHASE2_NOTES.md` je splnená aspoň pre tento typ súťaže. Z výsledkovej listiny sa dá pred koncom súťaže povedať:

- v ktorom kole práve tancuješ a s akým číslom (`Č.p.`),
- koľko párov je v kole a koľko pôjde ďalej (`Postupový kľúč` + počet riadkov v bloku),
- či ste **postúpili** (ste v najvyššom bloku bez umiestnenia) alebo **vypadli** (máte umiestnenie v nižšom bloku),
- konečné umiestnenie, keď sa doplní Finále.

Krížiky po kolách sa počas súťaže **nedajú** (KSIS ich zverejní až na konci).

### Ešte chýba (prosím uložiť na najbližšej súťaži)
1. Viackolová súťaž naživo: stav po 1. kole (či sa blok „1. kolo“ správa rovnako ako tu „Semifinále“).
2. Latinská a nebodovaná súťaž naživo.
3. Stránka **Rozpis** (časový harmonogram, ak má čas kôl) a `podujatie.php?pod_id=…` (všetky kategórie podujatia).
4. Hotová výsledková listina tej istej súťaže (12206) s vyplnenými *Body* a *Celkom*, na porovnanie.

---

## 2. Živé sledovanie (bez servera, cez KSIS v aplikácii)

Zostávame pri dnešnom modeli: KSIS sa otvára vo `KSISBrowserView` (prejde Cloudflare ako bežný prehliadač), HTML ide do `ksis-page`. Serverový worker, APNs a Dynamic Island z Fázy 2 **zatiaľ nerobíme**; najprv overíme, že to v klientovi funguje na reálnej súťaži.

### 2.1 Parser (`supabase/functions/_shared/ksis-pages.ts` + test)
- `parseResults`: prijme oba layouty. Povinné stĺpce `Umiestnenie, Č.p., Pár, Klub`; `Body` a `Celkom` voliteľné. Nové pole `published: boolean` (false, keď nadpisy *Body/Celkom* chýbajú).
- Nová čistá funkcia `liveStatus(results, parId)` → jeden z typov:
  - `inRound { round, startNumber, couplesInRound, advancing }` – sme v najvyššom bloku, bez umiestnenia,
  - `final { startNumber, couplesInFinal }` – najvyšší blok je Finále a sme v ňom,
  - `eliminated { round, place }` – máme umiestnenie v nižšom bloku,
  - `placed { place }` – súťaž je hotová (rovnaké ako dnešné uloženie),
  - `notInList` – náš pár na stránke nie je.
  `advancing` berieme len z publikovaného postupového kľúča, nič nedopočítavame.
- `parseMarks`: text „Hodnotenie bude až po ukončení súťaže“ → `KsisPageError("not_published")`, nie `layoutChanged`.
- Fixtúry (anonymizované ako doteraz): `results_live_round_12206.html`, `results_live_final_12206.html`, `marks_pending_12206.html` + testy v `ksis-pages.test.ts`.

### 2.2 Edge Function `ksis-page`
- `results()`: keď `published == false`, **neukladá** do `competition_results` a vráti `{ kind: "live", competition, status }`. Hotová listina ide ako dnes cez `save`.
- `marks()`: `not_published` → `{ kind: "marks_pending" }`.
- Bez zmeny schémy, bez nových tabuliek.

### 2.3 iOS
- `KSISPageReply` (`CompetitionModels.swift`): nové prípady `.live(KSISLiveStatus)` a `.marksPending`.
- `KSISBrowserView`: nad stránkou živá karta (§1A, sklenená karta, zlaté caps):
  - veľké **štartové číslo**, kolo („Semifinále · 12 párov · ďalej ide 6“),
  - stav: „Čakáte na výsledok kola“ → „Postupujete do finále!“ (zlatý záblesk + `sensoryFeedback(.success)`) / „Koniec v semifinále · 9. miesto“ (tlmené, bez konfiet),
  - automatické obnovenie stránky každých 60 s, kým je karta otvorená, + ručné potiahnutie; „Aktualizované pred 20 s“ s `.contentTransition(.numericText())`.
- `CompetitionTrackerView` → sekcia „V DEŇ SÚŤAŽE“: posledný otvorený živý stav (karta s číslom a kolom) a skratka späť na tú istú stránku.
- Neskôr (samostatný krok): lokálna Live Activity s číslom a kolom, obnovovaná z popredia (štart iba v popredí, pravidlá z `KSIS_PHASE2_NOTES.md` §7).

### 2.4 Uložiť celú súťaž jedným ťukom
Na hotovej výsledkovej listine tlačidlo **„Uložiť celú súťaž“**: uloží výsledok, potom v tom istom
prehliadači (rovnaká relácia, žiadny server) načíta `hodnot_sut.php?sutaz_id=…` a uloží krížiky. Jedna
karta s priebehom („Výsledok ✓ · Krížiky …“). Ak hodnotenie ešte nie je zverejnené, výsledok sa uloží
a krížiky sa doplnia pri ďalšom otvorení súťaže.

### 2.5 Súťažný režim (bez dohody so SZTŠ)
Ráno v deň súťaže appka ponúkne „Súťažný režim“ pre kategórie z Plánu / zo zoznamu prihlášok:
- celá obrazovka: obrovské štartové číslo, kolo, stav; displej nezhasne (`isIdleTimerDisabled`) iba v tomto režime,
- KSIS sa obnovuje v pozadí karty každých 60 s, pri zmene stavu silná haptika + zvuk,
- telefón môže držať aj **rodič alebo tréner na tribúne**: jeho appka posiela stav páru cez Supabase
  a tanečníkovi príde notifikácia (stav pochádza z bežného prezerania KSIS človekom, nie z robota),
- Apple Watch (verzia s hodinkami): vibrácia na zápästí cez WatchConnectivity, kým je režim na telefóne otvorený.

### 2.6 Notifikácie: čo sa dá a čo nie
| Spôsob | Funguje so zamknutým telefónom? | Potrebuje SZTŠ? |
|---|---|---|
| Súťažný režim na vlastnom telefóne (obrazovka zapnutá) | nie, appka musí byť na obrazovke | nie |
| Rodič/tréner sleduje → push tanečníkovi | **áno** (u tanečníka) | nie, potrebuje Apple Developer účet (APNs) |
| Server sleduje KSIS sám → push + Live Activity + hodinky | **áno**, bez nikoho | **áno**: server je od Cloudflare blokovaný (test 9. 10.: 403). Cloudflare **nebudeme obchádzať**; čakáme na allowlist (`KSIS_SZTS_EMAIL.md`). |

iOS appke v pozadí nedovolí obnovovať stránku každú minútu (`BGAppRefreshTask` spúšťa systém, keď sám chce),
preto „automaticky a so zamknutým telefónom“ ide spoľahlivo len cez server, teda po dohode so SZTŠ.

---

## 3. Vyhľadávanie v histórii

Všetko potrebné už je v `competition_results`: `event_name`, `category_name`, `date`, `start_number`, `placement`, `rounds`, `judges`. Hľadá sa **lokálne** v načítaných výsledkoch, žiadne nové API.

- Nová obrazovka **„Moje súťaže“** (z hlavičky VÝSLEDKY → „Všetky“), `.searchable` s tokenmi (Apple `searchable(text:tokens:)`):
  - text: názov podujatia, kategória, mesto (z názvu podujatia), meno porotcu,
  - **číslo**: „34“ alebo „#34“ nájde súťaže, kde ste tancovali s číslom 34,
  - rok, ŠTT/LAT, „finále“, „víťazstvo“,
  - filtrové čipy pod poľom (Rok · ŠTT · LAT · Finále), pri výsledku zvýraznená zhoda.
- Riadok výsledku: dátum, podujatie, kategória, **číslo v krúžku**, umiestnenie, kolo, do ktorého ste došli.
- Voliteľne (zmena schémy, SQL ukážem pred použitím): stĺpec `venue text` v `competition_results`, aby sa dalo hľadať aj podľa miesta konania. Bez neho hľadáme podľa názvu podujatia.

---

## 4. Kalendár súťaží

Nová obrazovka `CompetitionCalendarView` (vlastná mriežka v SwiftUI nad `PlannerCalendar`: pondelok prvý, slovenské názvy). `UICalendarView` nedovolí animácie a vzhľad podľa §1A, preto vlastná.

- **Vrstvy na dňoch**
  - odtancované súťaže (`competition_results`): zlatá bodka; finále = zlatý krúžok; 1.–3. miesto = malá medaila,
  - plánované súťaže z Plánu (`PlannedCompetition`): obrys, Idem / Zvažujem farebne,
  - (prepínač) tréningy z `TrainingLogEntry` ako jemné body.
- **Interakcie**
  - swipe medzi mesiacmi, názov mesiaca a rok cez `.contentTransition(.numericText())`,
  - výber dňa: zlatý podklad sa presúva cez `matchedGeometryEffect`, pružina + `sensoryFeedback(.selection)`,
  - ťuk na deň s výsledkom → karta sa rozbalí pod mriežkou (číslo, kolo, umiestnenie, krížiky), ďalší ťuk → `KSISResultDetailView`,
  - „Dnes“ skočí pružinou na dnešok,
  - stiahnutie prstami (pinch) → **ročný prehľad**: 12 mini mesiacov ako „heatmapa“ sezóny; ťuk na mesiac ho priblíži späť.
- Vstupy: z Výsledkov (ikona kalendára v hlavičke) a z Plánu.
- Spojenie plánu a výsledku: `PlannedCompetition.ksisCompetitionId` je už pripravené. Keď sa uloží výsledok s rovnakým dátumom a podujatím, plánovaná súťaž sa na ňu napojí a v kalendári sa z obrysu stane výsledok.

---

## 5. Sezóna v číslach (micro-interakcia na konci sezóny)

Počíta sa na klientovi z `competition_results` (vrátane `rounds` a `judges`). **Sezóna = 1. september – 31. august** (rozhodnutie Jakuba, 12. 10. 2026; oficiálnu definíciu SZTŠ sme neoverili). Zoskupenie v denníku sa zmení z kalendárneho roka (`yearOf`) na sezónu „2026/27“.

Karty v štýle „story“ (`TabView` stránkovaný, čísla nabiehajú cez `.numericText()`, každá karta so svojou animáciou, na konci „Zdieľať“ cez `ImageRenderer`):

1. Počet súťaží, podujatí a miest (mestá na mape v ďalšej verzii).
2. Finále, víťazstvá, pódiá, priemerné umiestnenie, najlepšie umiestnenie.
3. **Čísla**: všetky štartové čísla sezóny ako „kolekcia dresov“, šťastné číslo (najlepší priemer).
4. **Krížiky**: spolu, percento krížikov v každom kole, najlepší tanec (najviac krížikov), najslabší tanec.
5. **Porotcovia**: kto vám dal najviac krížikov (len porotcovia s ≥ 3 spoločnými súťažami, aby to nebola náhoda), kto najlepšie hodnotil vo finále. Skrytý porotca (napr. D) sa do štatistík nezapočíta.
6. Body získané v sezóne a vývoj triedy (z `par.php`, iba zverejnené údaje).
7. ŠTT vs. LAT, najsilnejší mesiac, najdlhšia séria finále.
8. Porovnanie s minulou sezónou (šípky hore/dole).

Prémiová funkcia? Rozhodne sa podľa `docs/V1_PAYWALL_FEATURES_PLAN.md` (Plán je osobný, nikdy skupinový).

---

## 6. Ďalšie nápady

- **Súperi v kategórii**: zo zoznamu prihlášok (`zoznam_prihl.php`) ukázať, kto ide v našej kategórii, a vzájomnú bilanciu s konkrétnym párom („proti páru #12: 3 : 1“).
- **Poznámka k súťaži**: pocit, čo išlo, čo zlepšiť; prepojiť s Top 3 z lekcie.
- **Video k výsledku**: pripojiť video z Video Vaultu ku kolu.
- **Checklist pred súťažou** (číslo, kostým, hudba, licencia) v Pláne deň pred súťažou.
- **Widget** (`EncoreWigdet`): najbližšia súťaž s odpočtom; v deň súťaže číslo a kolo.
- **Upozornenie „Výsledky sú zverejnené“** – až so serverovou Fázou 2.

---

## 7. Poradie práce (jeden krok = jeden commit, build po každom)

| # | Krok | Súbory | Schéma |
|---|---|---|---|
| 1 | Fixtúry 12206 + živý layout v parseri + `liveStatus` + testy | `ksis-pages.ts`, `ksis-pages.test.ts`, `fixtures/ksis/` | nie |
| 2 | `ksis-page` vracia `live` / `marks_pending` | `ksis-page/index.ts` | nie |
| 3 | iOS model + živá karta v prehliadači + auto-obnova + haptika | `CompetitionModels.swift`, `KSISBrowserView.swift` | nie |
| 3b | „Uložiť celú súťaž“ jedným ťukom (výsledok + krížiky) | `KSISBrowserView.swift` | nie |
| 4 | „V DEŇ SÚŤAŽE“ ukáže posledný živý stav + Súťažný režim na celú obrazovku | `CompetitionTrackerView.swift`, nový `CompetitionModeView.swift` | nie |
| 4b | Widget: najbližšia súťaž s odpočtom, v deň súťaže číslo a kolo | `EncoreWigdet*` | nie |
| 4c | Rodič/tréner sleduje → push tanečníkovi (po Developer účte) | Edge Function + APNs | **áno, SQL najprv ukážem** |
| 5 | Obrazovka „Moje súťaže“ s vyhľadávaním | nový `CompetitionHistoryView.swift` | nie |
| 6 | Kalendár (mesiac, potom ročný prehľad) | nový `CompetitionCalendarView.swift` | nie |
| 7 | Napojenie plánovanej súťaže na výsledok | `PlannerModels.swift`, `CompetitionManager.swift` | nie (SwiftData) |
| 8 | Sezóna v číslach | nový `SeasonStatsView.swift` + výpočty v samostatnom súbore s testami | nie |
| 9 | (voliteľné) `venue` v `competition_results` | migrácia | **áno, SQL najprv ukážem** |

## 8. Rozhodnuté a otvorené
- ✅ Sezóna september – august.
- ✅ Viackolová súťaž: parser berie bloky zhora nadol, takže „1. kolo“ funguje rovnako ako „Semifinále“. Cielene to nezháňať; ak sa stránka náhodou uloží, pridá sa ako fixtúra.
- ✅ Widget áno; Apple Developer účet a hodinky prichádzajú (Jakub, 12. 10. 2026).
- ❓ Poslať e-mail SZTŠ (`KSIS_SZTS_EMAIL.md`) – bez neho nie sú notifikácie bez človeka na tribúne.
- ❓ Sezóna v číslach a kalendár: Free, Plus alebo Premium?
