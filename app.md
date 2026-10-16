# 💃 ENCORE — Kompletný Prehľad Aplikácie, Brandu, UI a Architektúry

> **Súbor:** `app.md`  
> **Dátum:** Október 2026  
> **Stav projektu:** Jadro + StoreKit 2 platby + Opravené audio a domovská obrazovka, čistý Xcode build (`** BUILD SUCCEEDED **`)  
> **Účel dokumentu:** Kompletný referenčný stav kódu aplikácie pre vývojára a Claude AI asistenta.

---

## 🚦 Aktuálny Stav Kódu (Posledné Opravy & Pripravenosť)

1. **✅ Opravená domovská obrazovka (Hit-testing & Diktovanie):**
   - Vyriešený problém, kde nešlo písať text ani uložiť hlasovú poznámku. Radiálne menu `EncoreRadialHubView` malo statický neviditeľný 300pt rámček s `.zIndex(100)`, ktorý blokoval dotyky. Upravené na dynamickú veľkosť + pridaný `@FocusState` a `.onTapGesture` pre okamžité vysunutie klávesnice.
   - Hlasový záznam sa ukladá priamo do SwiftData `InstantNote` s vizuálnym zeleným toastom.
2. **✅ Odstránený konflikt audia v kamere:**
   - Z `DanceCameraManager` bol odstránený konfliktný VU meter a `AVCaptureAudioDataOutput`, ktorý spôsoboval pád audio session (error -19224) a predbiehal sa s mikrofónom.
   - Mikrofón je teraz zapojený priamo do natívneho `AVCaptureMovieFileOutput` (rovnako ako oficiálna Apple Camera), nahráva čistý 60 FPS zvuk a video bez zásekov.
3. **✅ Model predplatného (StoreKit 2 & Offline testovanie za 0 €):**
   - Vytvorený súbor `EncoreProducts.storekit` a zapojený do Xcode schémy `Encore.xcscheme`. Všetky nákupy na simulátore aj cez USB kábel sú zadarmo.
   - **Free plán:** 1 zostava na každý konkrétny tanec (1× Waltz, 1× Tango, 1× Samba...).
   - **Plus plán (€5.99/mes, €49.99/rok):** Neobmedzené zostavy, synchronizácia s Apple Kalendárom, Top 3 priority po lekcii, parket Optima Košice.
   - **Studio plán (€14.99/mes, €129.99/rok):** KSIS Radar súperov so živými notifikáciami, Posture línie vo videu, Video Duel.
   - **Rola Trénera (Coach):** Roster zverencov, poznámka "Čo sme robili naposledy", Zero-Delete politika (tréner nikdy nemôže zmazať žiakovi choreografiu).
4. **✅ Overenie kompilácie:**
   - Projekt sa kompiluje bez jedinej chyby (`** BUILD SUCCEEDED **`).

---

## 📑 Obsah
1. [Brand Identita, Názov & Logo](#1-brand-identita-názov--logo)
2. [Vizuálny Dizajn & Color Scheme](#2-vizuálny-dizajn--color-scheme)
3. [Prehľad Obrazoviek a UI Architektúry](#3-prehľad-obrazoviek-a-ui-architektúry)
4. [Backend, Cloud & Infraštruktúra (Supabase, Resend, SwiftData)](#4-backend-cloud--infraštruktúra)
5. [Katalóg Všetkých Implementovaných Funkcií & Tanečných Pomôcok](#5-katalóg-všetkých-implementovaných-funkcií--tanečných-pomôcok)
6. [Nový Koncept: Čisté Tanečné Zrkadlo (Clean Dance Mirror)](#6-nový-koncept-čisté-tanečné-zrkadlo-clean-dance-mirror)
7. [Plán Ďalších Nastavení a Tanečných Pomôcok (Backlog)](#7-plán-ďalších-nastavení-a-tanečných-pomôcok-backlog)

---

## 1. Brand Identita, Názov & Logo (Oficiálny Rebranding na ENCORE)

### Názov: **ENCORE** (Choreography & Dance Practice)
* **Vízia a význam:**
  * **"Encore" (Prídavok / Opakovateľnosť pre divákov)** — V divadle a na tanečnom parkete reprezentuje moment, kedy publikum a porotcovia žiadajú opakovanie výnimočného výkonu. Naša vízia je, že tanečná zostava a výkon sú opakovateľná dokonalosť pripravená pre divákov a súťažné kolá.
  * Krátky, medzinárodne rešpektovaný a zapamätateľný názov pre App Store.

### Nový Vizuálny Symbol & 3D Logo
* **Geometrická konštrukcia a symbolika:**
  * **Pomer Zlatý rez ($\Phi = 0.618$):** Telo písmena "E" a prepojenie s ladnou tanečnou figúrou.
  * **Nekonečná slučka (Infinity Loop, $t=0 \to t=2\pi$):** Nekonečné opakovanie, zdokonaľovanie a plynulý tok choreografie (Line of Dance).
  * **Harmónia kriviek (Parametric Splines):** Zlaté 3D stužkové línie vyjadrujúce dynamiku párového držania a eleganciu.
* **App Store Ikona (`AppIcon.png` — 1024×1024):**
  * Hlboké zamatovo červené pozadie (Crimson Velvet `#780514` až `#52020D` v rohoch).
  * 3D saténový zlatý emblém "E" v strede s precíznym tieňovaním a hĺbkou.
  * Verzie pripravené pre iOS: štandardná, tmavá (Dark) a tónovaná (Tinted).
* **Emblém v aplikácii (`AppSplashView.swift`, `ContentView.swift`, `AuthSheetView.swift`):**
  * Splash Screen využíva zamatový radiálny kruh (`encoreCrimson` / `encoreBurgundy`) s rotujúcim zlatým prstencom.
  * Názov zobrazený ako **ENCORE** s jemným zlatým chevron indikátorom otvárajúcim Command Palette / Quick Hub.

---

## 2. Vizuálny Dizajn & Color Scheme

Aplikácia prepája tri dizajnové smery do jednotného prémiového celku:
* **Encore Crimson & Gold (Nový Brand):** Hlboký zamatový karmín (`#780514`), burgundské tiene a šampanské zlato pre kľúčové prvky identity.
* **iOS 18 Liquid Glass & Luxury Obsidian:** Plávajúci dymový dock, sklenené panely s rozostrením pozadia (blur), jemné odlesky a haptická odozva.
* **Warm Cream & Neubrutalism (Plátno & Figúry):** Teplý podklad pripomínajúci kvalitný papier, jemné tiene a čistá typografia, ktorá neťahá oči pri dlhom štúdiu zostáv v tanečnej sále.

### Oficiálna farebná paleta (`Colors.swift`)

| Token | HEX / Farba | Využitie v UI |
|---|---|---|
| `encoreCrimson` | `#780514` (Deep Velvet Crimson) | Pozadie ikony, splash emblém, primárny akcent brandu |
| `encoreCrimsonLight` | `#9A0D1F` (Bright Crimson) | Gradienty, aktívne svetelné efekty |
| `encoreBurgundy` | `#52020D` (Burgundy Shadow) | Okraje ikon, hlboké tiene, kontrastné vignetting |
| `encoreGold` | `#DCA51E` (Satin Gold) | 3D stužkový emblém "E", prémiové označenia |
| `gold400` / `gold300` | `#FFE088` / `#F9F1CC` | Zlaté odlesky, sekundárny text loga, tlačidlá |
| `obsidian900` | `#050505` (Pure Obsidian) | Podklad obrazoviek v tmavom režime, dock |
| `standardBlue` | `#3B82F6` (Royal Blue) | Štandardné tance (Waltz, Tango, Valčík, Slowfox, Quickstep) |
| `latinPink` / `latinRed` | `#F43F5E` / `#E11D48` | Latinskoamerické tance (Samba, Cha-Cha, Rumba, Paso, Jive) |
| `syncEmerald` | `#10B981` (Sync Emerald) | Úspešná synchronizácia, aktívny cloud stav |

---

## 3. Prehľad Obrazoviek a UI Architektúry

Všetky obrazovky majú implementovaný **Auto-Padding systém** (8–10 % šírky obrazovky), vďaka čomu žiaden prvok nezasahuje do zaoblených rohov iPhonov ani pod fyzické rámčeky.

```
┌─────────────────────────────────────────────────────────────┐
│  HORNÁ LIŠTA (Liquid Glass): Názov, QR Kód, Menu [ ... ]    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    INTERAKTÍVNY OBSAH                       │
│        (Plátno / Hub zostáv / Knižnica / Profil)            │
│                 Plne Edge-to-Edge pod lištami               │
│                                                             │
│  [TV AirPlay]                                 [ ⟳ Refresh ] │
│  [ ✏️ Ceruza ]                                 [ ⌖ Center ]  │
│                   [ 🟢 Real time: Active ]                  │
├─────────────────────────────────────────────────────────────┤
│  [ 🏠 Domov ]   [ ▦ Canvas ]   [ 🎥 Kamera ]   [ 👤 Profil ]  │  <- Spodný Dock
└─────────────────────────────────────────────────────────────┘
```

### 1. Spodný Plávajúci Dock (`MainTabView.swift`)
* Pláva nad celým obsahom s dymovým Liquid Glass efektom.
* Štyri hlavné záložky:
  1. **Domov (`ContentView`):** Prehľad tancov, rýchly import, kategórie.
  2. **Canvas Hub (`CanvasRoutinesHubView`):** Výber a správa choreografií.
  3. **Rýchla kamera (`CaptureModeView`):** 1-Tap okamžitý záznamník (video/hlas).
  4. **Profil (`ProfileView`):** Štatistiky, cloud, údržba a štúdiové nástroje.

### 2. Domovská Obrazovka (`ContentView.swift`)
* Karty 10 tancov rozdelené na Štandard a Latinu.
* Zobrazenie tempa (MPM/BPM), počtu naučených figúr a ukážkového tréningového videa ku každému tancu.
* Rýchly import zostáv cez naskenovanie QR kódu alebo vložením textového kódu.

### 3. Hub Zostáv — "Moje Zostavy" (`CanvasRoutinesHubView.swift`)
* Dvojúrovňová navigácia — po ťuknutí na Canvas v doku sa najskôr otvorí tento hub.
* Filtrovanie (Všetky, Štandard, Latina) a vyhľadávanie v reálnom čase.
* **Mini-konštelácia figúr:** Každá kartička zostavy priamo zobrazuje malú grafickú schému toku figúr, počet priradených videí a dátum poslednej zmeny.
* Tlačidlo `+ Nová zostava` s výberom tanca.

### 4. Interaktívny Tancodrom (`RoutineCanvasView.swift`)
* **Edge-to-Edge:** Plátno (3000 × 3000 pt) sa rozprestiera cez celú obrazovku a podchádza pod hornú lištu aj spodný dok — žiadne čierne pásy.
* Plynulý 2-prstový Pan a Pinch Zoom cez natívny UIKit koordinátor (`CanvasGestureView`).
* Podklad s parketovým značením (Line of Dance, stred sály, štvrťkruhy rohov).
* Figúry ako samostatné kartičky s rytmickou osou (`BeatsTimelineView`), spojené Bezier krivkami.
* **Bočné ovládače v dosahu palca (odsadené 24 pt od bokov, plávajúce nad dokom):**
  * Vľavo: AirPlay vysielanie na TV, prepínač voľného kreslenia (Ceruza).
  * Vpravo: Hrubý DB refresh (priama obnova zo servera), Vycentrovanie parketu.
  * Stred: Zelená pilulka stavu živého spojenia.
* **Stabilita pri odomknutí:** Ošetrený nežiaduci posun/skok pri opätovnom rozsvietení displeja.

### 5. Globálna Knižnica Figúr (`GlobalLibraryView.swift`)
* Encyklopédia s viac ako 100 oficiálnymi figúrami.
* Technický popis krokov, rytmizácia (Slow/Quick), priradenie vlastných videí a nahrávok.

### 6. Profil & Trénerské Štúdio (`ProfileView.swift` & `StudioToolsView.swift`)
* Tréningové štatistiky (počet zostáv, nahrané hodiny, obsadené úložisko).
* Vstup do špecializovaného trénerského a súťažného štúdia.

---

## 4. Backend, Cloud & Infraštruktúra

### 1. Supabase (BaaS)
* **Autentifikácia:**
  * E-mail a heslo.
  * Bezpečné ukladanie tokenov do hardvérového iOS Keychain.
  * **Biometrické prihlasovanie (Face ID / Touch ID)** bez nutnosti opätovného vypisovania hesla.
* **PostgreSQL Databáza:**
  * Tabuľky `routines`, `canvas_nodes`, `figure_library`, `dances`.
  * Zapnuté Row Level Security (RLS) pravidlá zabezpečujúce, že používateľ vidí a upravuje iba svoje dáta.
  * Nastavenie `REPLICA IDENTITY FULL` pre spoľahlivé sledovanie zmien.
* **Supabase Realtime (WebSockets):**
  * Kanál s odozvou pod **50 ms** pre okamžitý prenos ťahania figúry na parkete (`node_moved`).
  * **Presence kurzory:** Ak majú partneri súčasne otvorené rovnaké plátno, vidia navzájom svoje kurzory a pohyb v reálnom čase.
* **Supabase Storage:**
  * Špecializovaný bucket `encore-media` pre bezpečný upload a streamovanie tréningových videí a fotografií.

### 2. E-maily & Overovanie (Resend & SMTP)
* Supabase Auth automaticky zabezpečuje odosielanie aktivačných e-mailov a obnovu zabudnutého hesla.
* V Supabase Dashboarde v sekcii *Authentication -> SMTP Settings* je pripravená integrácia na **Resend API / SMTP**.
* Výhoda: E-maily nepadajú do spamu, odchádzajú z vlastnej overenej domény (napr. `auth@encore.com`) a majú vlastný HTML branding.

### 3. SwiftData & Offline-First Odolnosť
* Aplikácia je navrhnutá pre tanečné sály v podzemí a na kempingoch bez mobilného signálu.
* Všetky zmeny sa najskôr zapisujú do lokálnej SQLite databázy (SwiftData).
* Po obnove internetu manažér `SupabaseSyncManager` s inteligentným debouncingom (700 ms) automaticky a bezpečne zosynchronizuje zmeny do cloudu bez zamrznutia UI.
* Modul `DatabaseRecoveryManager` automaticky chráni pred pádmi pri zmenách dátových modelov a robí zálohy.

---

## 5. Katalóg Všetkých Implementovaných Funkcií & Tanečných Pomôcok

Aplikácia obsahuje komplexnú výbavu, ktorá ďaleko presahuje bežné poznámkové bloky:

### A. Choreografia a Tancodrom
1. **2D Vizuálny Canvas:** Nelineárne rozloženie figúr po sále s dodržaním smeru tanca.
2. **Bezier prepojenia:** Plynulé krivky medzi figúrami s možnosťou vložiť technickú poznámku k prechodu.
3. **Beats Timeline:** Vizuálne zobrazenie dôb a rytmizácie (napr. 1, 2, 3 alebo Slow, Quick, Quick).
4. **Drawing Layer (Ceruza):** Kreslenie voľnou rukou priamo na parket (napr. trajektória rotácie páru).
5. **Radarová Minimapa:** Rýchla orientácia na veľkom plátne 3000 × 3000 pt.
6. **QR Export & Import:** Zdieľanie celej choreografie do 2 sekúnd cez CoreImage QR kód.

### B. Práca s Médiami a Zvukom
7. **Bezkonfliktné Audio (`AudioSessionCoordinator`):** Inteligentný arbiter zabraňujúci zlyhaniu zvuku pri súčasnom nahrávaní, prehrávaní a diktovaní.
8. **Diktovanie trénera v slovenčine (`SpeechRecognizerHelper`):** Prepis hovoreného slova trénera priamo do textových poznámok figúry cez Apple Speech.
9. **Kamera s vysokou stabilitou (`VideoRecorderView`):** Predvolene vypnutý blesk, podpora prednej/zadnej kamery, 60 FPS záznam.
10. **Slučkový prehrávač (`LoopingVideoPlayer`):** Plynulé opakovanie kľúčového kroku s možnosťou spomalenia (0.5× až 1.5×).

### C. Profesionálne Tanečné a Štúdiové Pomôcky
11. ⚔️ **Duel videí (`DualVideoComparisonView`):** Porovnanie dvoch videí vedľa seba (vlastné video vs. vzor alebo staršie vs. novšie) so synchrónnym krokovaním po snímkach.
12. 🗄️ **Video & Foto Trezor (`VideoVaultView`):** Centrálna galéria všetkých tréningových záberov s tagovaním podľa tancov a figúr.
13. ✂️ **Strihač seminárov (`SeminarSplitterView`):** Rýchle rozstrihanie celého 45-minútového kempu na samostatné 10-sekundové figúry.
14. ✂️ **Strih a orezanie videa (`VideoTrimView`):** Orezanie zbytočného začiatku a konca nahrávky.
15. 🧍 **AI Analýza držania tela (`PostureAnalysisOverlayView`):** Detekcia línie pliec, chrbtice a náklonu hlavy cez Apple Vision AI v reálnom čase.
16. ~~Music Speed Trainer~~ zmazaný 16. 10. 2026 (hudbu si tanečníci púšťajú zo Spotify).
17. 🏆 **Súťažný simulátor finále (`CompetitionFinalSimulatorView`):** Tréning 5 tancov v plnom tempe s pauzami a výpočtom výsledkov podľa WDSF Skating systému.
18. 📋 **Súťažný organizér kôl (`CompetitionOrganizerView`):** Správa štartovných čísel, rozdelenia do heatov a časového harmonogramu súťaže.
19. 📺 **AirPlay TV Hub (`StudioAirPlayManager`):** Okamžité bezdrôtové premietanie parketu alebo videa na TV v sále.
20. 📄 **PDF Exporter (`RoutinePDFExporter`):** Tlač choreografických listov pre trénerov a súťažné páry.
21. 🏝️ **Live Activity & Dynamic Island (`EncoreWidget`):** Zobrazenie aktuálnej a nasledujúcej figúry a času na zamknutej obrazovke iPhonu.
22. ⌚ **Apple Watch Cueing (`WatchCueingManager`):** Haptické odpočítavanie dôb na zápästí.
23. 🌐 **Web Companion (`web/` & `encore-web/`):** Webový prístup k zostavám pre partnerov s Androidom alebo PC.

---

## 6. Čisté Tanečné Zrkadlo (Clean Dance Mirror) — IMPLEMENTOVANÉ

> **Status:** **100 % HOTOVÉ A OTESTOVANÉ** (`DanceMirrorView.swift` & `AnimatedMirrorIconView.swift`)  
> **Prístup v aplikácii:** Priamo zo záložky *Kamera* v spodnom doku alebo cez *Profil -> Trénerské Štúdio*.

### Špecifikácia a implementácia modulu:
1. **100 % Čistý Full-Screen režim:**
   * Žiadne rušivé prvky, lišty ani texty.
   * Displej telefónu funguje ako bezokrajové zrkadlo využívajúce prednú TrueDepth kameru.
2. **Jediné tlačidlo — Liquid Glass "Späť":**
   * Plávajúca sklenená kapsula (`.ultraThinMaterial` s jemným svetelným orámovaním) v ľavom hornom rohu s haptickou odozvou na rýchly návrat.
3. **Prirodzené horizontálne zrkadlenie:**
   * Obraz je zrkadlovo otočený (`isVideoMirrored = true`), presne ako v skutočnom zrkadle.
4. **Nezávislosť od audia (Hudba neprestáva hrať):**
   * Zrkadlo vôbec neaktivuje mikrofón ani `AVAudioSession`, takže hudba alebo Spotify v tanečnej sále či v AirPodoch hrá plynulo ďalej bez stíšenia či pauzy.
5. **Neviditeľné dotykové gestá (Bez zbytočných ikon na obrazovke):**
   * **Dvojité ťuknutie (Double-Tap):** Hladké priblíženie (1× / 2× zoom) na detailnú kontrolu líčenia, mihalníc či účesu.
   * **Jedno ťuknutie (Single-Tap):** Rýchle zaostrenie a vyváženie expozície na tvár.
6. **Vektorová animovaná ikona zrkadla (`MirrorRectangularIcon` / `AnimatedMirrorIconView`):**
   * Čistý vektorový tvar zrkadla s diagonálnymi líniami odlesku (podľa špecifikácie SVG `viewBox="0 0 24 24"`, `rect 16x20`, `path M11 6L8 9m8-2l-8 8`).
   * **Nekonečne ostrá na každom Retina displeji:** Žiadny raster ani kompresné artefakty GIFu, nulová pamäťová záťaž.
   * **Animuje sa IBA na hover alebo dotyk:** V pokoji zobrazuje elegantnú statickú ikonu zrkadla.
   * **Presne 1 cyklus na akciu:** Pri prejdení myšou/kurzorom alebo dotyku prsta prebehne cez sklo svetelný odlesk so subtílnym spring pulzom a ikona sa vráti do pokoja. Žiadne nekonečné rušivé blikanie.
   * Dostupná v natívnom SwiftUI (iOS) aj ako React komponent pre Web (`MirrorRectangularIcon.tsx`).

---

## 7. Plán Ďalších Nastavení a Tanečných Pomôcok (Backlog)

Nápady na rozšírenie nastavení a ďalšie nástroje pripravené na realizáciu:

1. **Rýchly Tanečný Metronóm:**
   * Prednastavené oficiálne tempá pre všetkých 10 tancov (napr. Waltz 28–30 MPM, Jive 42–44 MPM).
   * Zvukový signál s výrazným úderom na 1. dobu + vizuálne blikanie na displeji.
2. **Offline Data Mode prepínač v nastaveniach:**
   * Možnosť manuálne zablokovať synchronizáciu dát na zahraničných súťažiach v roamingu.
3. **Predsúťažný Checklist:**
   * Interaktívny zoznam vecí do tašky (číslo, sponky, lak, kefka na semišovú podrážku, tekutý vosk, náhradné pančuchy, energy tyčinka).
4. **Prepínač párov (Multi-Couple Profile):**
   * Pre trénerov, ktorí na jednom zariadení spravujú 5 rôznych tanečných párov.
5. **Prepínač vizuálnej témy (Theme Switcher):**
   * Výber medzi *Warm Cream*, *Pure Dark Obsidian* a *High-Contrast Ballroom*.

---

## 8. Plánovaná UX Transformácia: Domovský Radiálny Hub & Multi-Routine Deck

> **Detailná špecifikácia a Rive návod:** [docs/HOME_RADIAL_HUB_AND_RIVE_SPECIFICATION.md](./docs/HOME_RADIAL_HUB_AND_RIVE_SPECIFICATION.md)

* **Interaktívne Hero Logo (Radial Satellite Menu):**
  * Namiesto otvárania modálneho sheetu sa po kliknutí na stredové logo Encore logo zväčší (scale 1.18×) a dookola neho sa orbitálne rozvinú 4 satelitné akcie:
    1. **Nová zostava** (Hore-Vľavo)
    2. **Mirror / Čisté Zrkadlo** (Hore-Vpravo)
    3. **Súťažný organizér kôl** (Dole-Vľavo)
    4. **Porovnanie videí** (Dole-Vpravo)
* **Spodný výsuvný panel zostáv (Routines Deck):**
  * Každý tanec primárne ukazuje svoju **najnovšiu (poslednú upravovanú) zostavu**.
  * Ak má tanečník viac zostáv pre rovnaký tanec (napr. Cha-Cha pre C aj B), ostatné zostavy sa zobrazia po rozbalení panelu a ťuknutí na konkrétny tanec.

---

*Dokument slúži ako kompletný podklad pre diskusiu o budúcom smerovaní aplikácie.*
