# 🛡️ ENCORE — Kompletný Register 90 Zraniteľných Scenárov & 20 Profesionálnych Tanečných Návrhov

> **Dátum:** August 2026  
> **Status:** Analýza rizík, edge-cases a návrhy funkcií pre tréningy, kempy, súťaže a analýzu  
> **Cieľ:** 90 podrobných hraničných situácií (rozdelených do 6 kategórií) a 20 profesionálnych funkcií pre tanečné páry, trénerov a súťažiacich.

---

## 📸 1. Nastavenie a Správanie Blesku v Kamere

### Aktuálny Princíp:
* **Blesk je v predvolenom stave VYPNUTÝ (`picker.cameraFlashMode = .off`).**
* Pri otvorení kamery blesk/svetlo **nikdy nezasvieti automaticky** a neoslepí tanečníkov na parkete.
* V hornom rohu natívneho rozhrania kamery má používateľ **interaktívnu ikonu blesku (⚡)**, ktorou si môže prisvietenie manuálne zapnúť na `Auto`, `On` alebo `Off` podľa potreby v tmavšej sále.

---

## 💃 2. 20 Profesionálnych Návrhov pre Tréning, Kempy, Súťaže a Analýzu

Inšpirované aplikáciami ako *Apple Camera, Halide, Blackmagic Cam, Hudl Technique, Dartfish* a profesionálnou tanečnou praxou v Standarde & Latine:

```
┌────────────────────────────────────────────────────────────────────────┐
│  🏆 SÚŤAŽNÝ & TRÉNINGOVÝ ASISTENT ENCORE                            │
│                                                                        │
│  [🎥 Kamera & Slo-Mo]      [👥 Side-by-Side Duel]   [⏱️ 5-Dance Final] │
│  [📐 Posture Angle Lines]  [🎵 BPM Pitch Trainer]  [📺 Studio AirPlay] │
│  [🎪 Camp Workshop Split]  [⌚ Watch Haptic Cue]   [📄 PDF Cheat Sheet]│
└────────────────────────────────────────────────────────────────────────┘
```

### A. Pokročilé Funkcie Kamery (1 – 10)
1. **⏱️ Samospúšť (Hands-Free Countdown 3s / 5s / 10s):** Tanečník položí iPhone na statív alebo lavičku a má čas zaujať východiskovú pozíciu pred spustením záznamu.
2. **📐 Kompozičná mriežka a vodováha (Grid & Level):** Vodiace čiary (Rule of Thirds) a horizontálna vodováha, aby záznam držania tela a parketu nepadal na stranu.
3. **🔍 Rýchle prepínanie ohnísk (0.5x Ultra-Wide, 1x Štandard, 2x / 3x Detail nôh):** 0.5x zachytí celú sálu a smer tanca (Line of Dance), 2x zachytí detailnú prácu chodidiel.
4. **👻 Ghost / Onion Skinning (Prekrývací tréningový mód):** Zobrazenie polopriehľadného videa trénera alebo referenčnej figúry priamo v hľadáčiku kamery na živé porovnanie držania tela.
5. **🪞 Zrkadlový režim prednej kamery (Mirror Front Mode):** Displej sa správa presne ako veľké tréningové zrkadlo v tanečnej sále.
6. **🏎️ Slo-Mo (120 / 240 FPS) s krokovaním po snímkach:** Analýza rýchlych spinov a rotácií po jednotlivých framoch (Frame-by-Frame Scrubbing).
7. **🎙️ Prepínač mikrofónu a audio indikátor:** Voľba medzi vstavaným mikrofónom, AirPods a bezdrôtovým klopovým mikrofónom trénera s vizuálnym meračom hlasitosti.
8. **✂️ Rýchly orezávač videa (Quick Trim):** Odstrihnutie začiatku a konca videa (kde tanečník iba kráča k telefónu a späť) pred uložením k figúre.
9. **🎵 Vstavaný metronóm s BPM tanca:** Vizuálne alebo haptické počítanie tempa (napr. 28-30 MPM pre Slowfox) počas nahrávania.
10. **🏷️ Automatické tagovanie figúry:** Priradenie štítku k videu na jedno ťuknutie: *„Chodidlá“, „Držanie tela“, „Chyba v rotácii“, „Trénerov komentár“*.

### B. Špeciálne Tanečné Moduly pre Kempy, Súťaže a Analýzu (11 – 20)
11. **👥 Side-by-Side Dual Playback (Synchrónne porovnanie dvoch videí):** Prehrávanie vlastného videa a videa majstrov sveta/trénera vedľa seba s jedným spoločným posuvníkom času.
12. **📐 Posture & Angle Lines (Vizuálna analýza línií a postúry):** Možnosť kresliť čiary priamo cez video (sklon chrbtice, C-shape top line v štandarde, uhol panvy v latine, rovina ramien).
13. **🎪 Camp / Workshop Splitter (Rýchly extraktor figúr z dlhého seminára):** Nahratie 45-minútového seminára na medzinárodnom kempe a rýchle rozstrihanie a priradenie jednotlivých figúr na canvas.
14. **🎵 Music Pitch & Speed Trainer (Spomalenie hudby bez zmeny tónu):** Možnosť spomaliť súťažnú skladbu na 80 %, 90 % alebo zrýchliť na 105 % pre tréning stability a svalovej pamäte.
15. **🏆 Súťažný simulátor finále (5-Dance Final Endurance Mode):** Automatický časovač 1:30 min na každý tanec s 30-sekundovou pauzou, prepínaním hudby a zobrazením zostavy na Dynamic Islande.
16. **⌚ Apple Watch Haptic Cueing (Tiché haptické pokyny):** Hodinky jemne ťuknú partnera na zápästie 1 dobu pred náročným prechodom alebo zmenou smeru tanca.
17. **📺 Studio AirPlay / External Display Mode:** Bezdrôtové zrkadlenie canvasu alebo spomaleného videa na veľkú TV v sále bez rušivých tlačidiel aplikácie (čistý Full-Screen video stream).
18. **📄 PDF Export choreografie pre trénerov a porotcov:** Vygenerovanie profesionálneho hárku zostavy so zoznamom figúr, počítaním, diagramom parketu a QR kódom.
19. **⭐ Tréningový denník a hodnotenie trénera (Coach Feedback Log):** Možnosť prideliť figúre 1-5 hviezdičiek, zaznamenať dátum zvládnutia a sledovať progres páru v čase.
20. **🔢 Súťažný organizér (Heats & Rounds Planner):** Zápis štartovného čísla, rozlosovania do rozstrelov (Heat 1, Heat 2), zoznamu súperov a poznámok k parketu.

---

## 🚨 3. Kompletný Register 90 Zraniteľných Scenárov (Stress Audit)

---

### Kategória I: Kamera, Médiá a Hardvér (Scenáre 1 – 15)

| # | Hraničná Situácia | Riziko / Správanie | Riešenie a Ochrana |
|---|---|---|---|
| 1 | **Plný disk počas 4K videa** | Nahrávanie zlyhá uprostred figúry, nahrávka sa poškodí. | Pred otvorením kamery skontrolovať aspoň 300 MB voľného miesta na disku. |
| 2 | **Prichádzajúci hovor / Alarm** | iOS preruší audio/video reláciu a zatvorí kameru. | Odchytiť `AVAudioSession.interruptionNotification` a uložiť dovtedy zaznamenanú časť. |
| 3 | **Low Power Mode (Slabá batéria)** | Zníženie FPS z 60 na 30 FPS a zníženie jasu displeja. | Akceptovať throttling, informovať používateľa jemným toastom. |
| 4 | **Zhodenie aplikácie po kliknutí na "Use Video"** | Používateľ potiahne appku hore skôr, ako sa dokončí zápis. | Obaliť ukladanie do `UIApplication.shared.beginBackgroundTask`. |
| 5 | **Výber 48 MPx RAW fotografie** | Aplikácia spotrebuje priveľa RAM pri dekódovaní veľkej fotky. | `MediaResolver` automaticky zmenšuje obrázky na max 1400px pred vykreslením. |
| 6 | **Extrémne prehriatie iPhonu (Thermal State: Critical)** | Pri dlhom nahrávaní na horúcom parkete iOS zablokuje blesk a obmedzí kameru. | Sledovať `ProcessInfo.processInfo.thermalState` a znížiť kvalitu náhľadu pri prehriatí. |
| 7 | **Prehrávanie poškodeného video súboru** | Používateľ importuje súbor s neznámym kodekom, čierna obrazovka. | Nastaviť KVO pozorovateľ na `AVPlayerItem.status == .failed` a zobraziť chybový stav. |
| 8 | **Prehrávanie 0.3s ultrakrátkeho videa v nekonečnej slučke** | `AVPlayerLooper` preťaží procesor neustálym seekovaním. | Nastaviť minimálnu dĺžku slučky alebo pridať 200 ms pauzu medzi opakovaniami. |
| 9 | **Odpojenie Bluetooth reproduktora počas prehrávania** | Zmena audio výstupu môže spôsobiť zásek prehrávača. | Implementovať listener na `AVAudioSession.routeChangeNotification`. |
| 10 | **Otočenie displeja do Landscape režimu počas videa** | Prvky ovládania sa môžu posunúť mimo obrazovku. | Využiť bezpečné zóny (`safeAreaInsets`) a responzívne layouty. |
| 11 | **Zablokovanie kamery v MDM / Rodičovskej kontrole** | Kamera je systémovo zakázaná na firemnom/školskom iPhone. | Detegovať `AVCaptureDevice.authorizationStatus == .restricted` s vysvetlením. |
| 12 | **Kamera beží v noci v úplnej tme** | Senzor zašumí a obraz je nečitateľný. | Ponúknuť zapnutie predného podsvietenia displeja alebo zadného LED prisvietenia. |
| 13 | **Pád aplikácie z dôvodu nedostatku RAM pri 10 otvorených kartách** | Zlyhanie alokácie pamäte v SwiftUI hierarchii. | Uvoľňovať `AVPlayer` inštancie pri `onDisappear` a zavretí detailu figúry. |
| 14 | **Zmazanie originálneho videa zo systémovej galérie Fotiek** | Ak aplikácia odkazovala na galériu, video zmizne. | Encore vždy kopíruje médiá do vlastného chráneného Sandboxu (`Documents`). |
| 15 | **Vyčistenie úložiska systému iOS (Storage Pressure Sweep)** | Systém zmaže dočasné súbory v `tmp/` priečinku. | Všetky trvalé videá a fotky ukladať výhradne do `Documents/`, nikdy nenechávať v `tmp/`. |

---

### Kategória II: Hlasové Poznámky & Rozpoznávanie Reči (Scenáre 16 – 25)

| # | Hraničná Situácia | Riziko / Správanie | Riešenie a Ochrana |
|---|---|---|---|
| 16 | **Diktovanie v hlučnej sále s hudbou** | Prepis zachytí text piesne namiesto trénerovho hlasu. | Zobraziť grafický indikátor hladiny zvuku a možnosť jednoduchého zrušenia. |
| 17 | **Diktovanie v angličtine pri slovenskom nastavení** | Foneticky skomolený nezrozumiteľný text. | Rýchly prepínač jazyka [SK / EN] priamo vedľa tlačidla diktovania. |
| 18 | **Diktovanie dlhšie ako 60 sekúnd** | `SFSpeechRecognizer` má limit od Apple ~1 minútu na reláciu. | Automaticky segmentovať a reštartovať reláciu po 50 sekundách bez straty textu. |
| 19 | **Odpojenie alebo vybitie AirPods počas diktovania** | Audio engine spadne pre stratu vstupného hardvéru. | Zachytiť `routeChangeNotification`, zastaviť nahrávanie a uložiť dovtedajší text. |
| 20 | **Tréner diktuje špecifické tanečné výrazy (napr. *Chassé, Rondé, Fleckerl*)** | Slovenský slovník nepozná francúzske a nemecké tanečné termíny. | Doplniť `contextualStrings` do `SFSpeechAudioBufferRecognitionRequest` so slovníkom figúr. |
| 21 | **Používateľ nemá povolený mikrofón** | Tlačidlo diktovania nič neurobí a zamrzne. | Zobraziť dialóg: *"Pre diktovanie povoľte mikrofón v Nastavenia -> Encore"*. |
| 22 | **Súčasné diktovanie a prehrávanie hudby z Apple Music** | Aplikácia stlmí alebo zastaví hudbu v sále. | Použiť kategóriu `.record` s voľbou `.duckOthers`, ktorá hudbu len jemne stíši. |
| 23 | **Offline diktovanie bez internetového pripojenia** | Staršie iPhony bez on-device dictation zlyhajú. | Overiť `recognizer.supportsOnDeviceRecognition` a informovať o stave. |
| 24 | **200+ nespracovaných instantných poznámok v schránke** | Pomalé scrollovanie a neprehľadnosť v paneli. | Doplniť možnosť hromadného vymazania a vyhľadávania v schránke. |
| 25 | **Vloženie extrémne dlhého textu do poznámky (10 000 slov)** | Deformácia karty figúry a sekanie renderovania. | Použiť elastický `AppleTypewriterTextView` s virtuálnym scrollovaním. |

---

### Kategória III: 2D Choreografický Canvas & Realtime (Scenáre 26 – 40)

| # | Hraničná Situácia | Riziko / Správanie | Riešenie a Ochrana |
|---|---|---|---|
| 26 | **Multi-touch: Ťahanie 3 figúr naraz rôznymi prstami** | Kolízia viacerých gest a nepredvídateľné skoky figúr. | Nastaviť `exclusiveTouch = true` pre karty figúr na canvase. |
| 27 | **Presunutie figúry ďaleko mimo parketu (x=15000)** | Figúra zmizne z dohľadu a nedá sa nájsť. | Nastaviť hranice parketu (Bounding Box) a tlačidlo *"Vycentrovať parket"*. |
| 28 | **Zostava s 60+ figúrami a desiatkami Bezier kriviek** | Pokles snímkovej frekvencie pod 30 FPS na starších zariadeniach. | Aktivovať Metal akceleráciu cez SwiftUI `drawingGroup()` na vrstve prepojení. |
| 29 | **Súčasný pohyb figúry dvoma partnermi cez WebSockets** | Figúra bliká a skáče medzi dvoma pozíciami (Race condition). | Zaviesť zámok figúry (Node Lock: *"Partner práve presúva"*). |
| 30 | **Partner A zmaže figúru, kým Partner B má otvorený jej detail** | Partner B upravuje neexistujúci objekt, pád pri ukladaní do SwiftData. | Pri prijatí Realtime DELETE okamžite bezpečne zatvoriť detail s toastom. |
| 31 | **Pinch-to-zoom na 0.01x (extrémne zmenšenie)** | Figúry sa zmenšia na neviditeľné body, zlyhanie hit-testov. | Obmedziť mierku zoomu na bezpečný rozsah (0.35x až 2.5x). |
| 32 | **Zostava bez figúr (prázdny Canvas)** | Používateľ nevie čo má robiť na prázdnej ploche. | Zobraziť elegantný prázdny stav (Empty State) s tlačidlom *"Pridať prvú figúru"*. |
| 33 | **Choreografia vytvorí nekonečný cyklus v číslovaní** | Počítadlo figúr ukazuje nesprávny súčet. | Automatický prepočet `orderIndex` podľa topologického usporiadania spojení. |
| 34 | **Kreslenie trajektórie (Apple Pencil / Prst) s 10 000 bodmi** | Extrémna pamäťová náročnosť vrstvy kreslenia. | Algoritmus Douglas-Peucker na zjednodušenie a vyhladenie krivky trajektórie. |
| 35 | **Zmena disciplíny zostavy (zo Štandardu na Latinu)** | Nekompatibilné rytmizácie a figúry v zozname. | Upozorniť používateľa modálnym oknom pred zmenou kategórie tanca. |
| 36 | **Vytvorenie dvoch zostáv s úplne identickým názvom** | Zmätok v zozname zostáv. | Automaticky pridať suffix (napr. *"Waltz Choreografia (2)"*). |
| 37 | **Prekrytie dvoch kariet figúr presne na rovnakých súradniciach** | Spodná karta sa nedá označiť ani kliknúť. | Inteligentný auto-layout offset (+20pt) pri vložení na rovnaké miesto. |
| 38 | **Pomalé internetové pripojenie partnera (Edge / 2G)** | Hromadenie WebSocket správ a oneskorené animácie. | Debouncing polohy (700 ms) a zhadzovanie zastaraných polôh kurzora. |
| 39 | **Výpadok Supabase Realtime servera** | Canvas prestane synchronizovať zmeny medzi partnermi. | Vizuálny offline indikátor v rohu canvasu a plynulý prechod na lokálny režim. |
| 40 | **Rozpojenie prepojenia medzi figúrami** | Zostava stratí kontinuitu a rytmickú nadväznosť. | Zobraziť prerušovanú červenú čiaru s upozornením na chýbajúci prechod. |

---

### Kategória IV: Cloud, Synchronizácia, Autentifikácia & Bezpečnosť (Scenáre 41 – 50)

| # | Hraničná Situácia | Riziko / Správanie | Riešenie a Ochrana |
|---|---|---|---|
| 41 | **Expirácia JWT tokenu pri štarte v offline režime** | Aplikácia by používateľa neprávom odhlásila. | Čítať prihlásený stav z hardvérového Keychainu a token obnoviť až online. |
| 42 | **Zmena hesla cez web a staré heslo uložené v Face ID** | Face ID zlyhá voči Supabase Auth s chybou `invalid_grant`. | Detegovať chybu, vymazať Keychain a vyzvať na zadanie nového hesla. |
| 43 | **Offline vytvorenie 10 zostáv a následné pripojenie na Wi-Fi** | Nárazová synchronizácia môže zahltiť API alebo vyvolať chyby. | Fronta požiadaviek (Sync Queue) s postupným odosielaním s odstupom 100 ms. |
| 44 | **Prekročenie 500 MB limitu Supabase Storage** | Server odmietne nahrať nové video s chybou HTTP 413. | Informovať používateľa; lokálne video zostáva plne funkčné na iPhone. |
| 45 | **Súčasná registrácia dvoch používateľov s rovnakým e-mailom** | Supabase Auth vráti chybu `user_already_exists`. | Zobraziť slovenskú hlášku a tlačidlo na okamžitý prechod do Prihlásenia. |
| 46 | **Slabé internetové pripojenie počas výmeny Google OAuth kódu** | Prihlásenie cez Google zamrzne na bielom displeji. | Nastaviť 15-sekundový timeout s možnosťou zopakovať pokus. |
| 47 | **Vymazanie účtu v profile aplikácie** | Dáta zostanú v cloude ako osirotené záznamy. | Kaskádové mazanie v PostgreSQL (`ON DELETE CASCADE`) pre všetky zostavy používateľa. |
| 48 | **Odhlásenie na jednom zariadení pri aktívnej Live Activity** | Dynamic Island pokračuje v behu a zobrazuje súkromné dáta. | Pri volaní `signOut()` okamžite ukončiť všetky aktívne Live Activities. |
| 49 | **Pokus o SQL Injection cez názov figúry alebo poznámku** | Bezpečnostné riziko pri nesprávnom escapovaní. | Používať výhradne parametrizované dotazy a PostgREST ORM wrapper. |
| 50 | **Neoprávnený prístup cudzieho používateľa k súkromnej zostave** | Únik tréningových choreografií konkurenčným párom. | Striktné Row Level Security (RLS) politiky na PostgreSQL tabuľkách. |

---

### Kategória V: Systém iOS, QR, Widgety & Dátová Integrita (Scenáre 51 – 60)

| # | Hraničná Situácia | Riziko / Správanie | Riešenie a Ochrana |
|---|---|---|---|
| 51 | **Naskenovanie QR kódu reštauračného menu alebo Wi-Fi** | Aplikácia sa pokúsi dekódovať neplatný JSON a spadne. | Validácia schémy s prefixom `encore://routine` pred parsovaním. |
| 52 | **Generovanie QR kódu pre obrovskú zostavu (>40 figúr)** | Hustý QR kód je nečitateľný pre staršie fotoaparáty. | Kompresia dát cez Gzip/Deflate pred generovaním QR kódu. |
| 53 | **Zmena veľkosti systémového písma (Dynamic Type XXL)** | Prvky v navigácii a karty figúr pretečú cez okraje. | Podpora škálovania cez `@ScaledMetric` a flexibilné layouty s `ViewThatFits`. |
| 54 | **Zapnutý VoiceOver pre zrakovo znevýhodnených** | Tanečník nepočuje názvy figúr pri dotyku na canvase. | Pridať sémantické `.accessibilityLabel` a `.accessibilityHint` na karty figúr. |
| 55 | **Spustenie aplikácie na iPade v režime Split View (polovica obrazovky)** | Layout navrhnutý len pre iPhone sa zdeformuje. | Použitie responzívnych kontajnerov a adaptívneho plávajúceho doku. |
| 56 | **Zmena časového pásma pri cestovaní na medzinárodnú súťaž** | Nesúlad v časových značkách `updatedAt` pri synchronizácii. | Všetky časové pečiatky ukladať a porovnávať striktne v UTC (ISO 8601). |
| 57 | **Budúca aktualizácia schémy SwiftData (Nová verzia modelu)** | Pád aplikácie pri štarte na `SwiftData.MigrationError`. | `DatabaseRecoveryManager` automaticky zálohuje SQLite bázu pred obnovou. |
| 58 | **Používateľ 3x importuje rovnakú zostavu z QR kódu** | Vznik 3 identických duplikátov v zozname tancov. | Dialóg: *"Táto zostava už existuje. Chcete ju aktualizovať alebo vytvoriť kópiu?"*. |
| 59 | **Uspanie aplikácie systémom pri bežiacom Dynamic Islande** | Widget na zamknutej ploche zamrzne a neaktualizuje sa. | Nastaviť `staleDate` pre Live Activity a ukončiť ju pri nečinnosti. |
| 60 | **Zapnutie funkcie Obmedzenie pohybu (Reduce Motion) v iOS** | Rýchle prechody a animácie môžu spôsobiť nevoľnosť. | Rešpektovať `@Environment(\.accessibilityReduceMotion)` a vypnúť zbytočné animácie. |

---

### Kategória VI: Súťaže, Kempy, Tréningový Stres & Zdieľanie (Scenáre 61 – 90)

| # | Hraničná Situácia | Riziko / Správanie | Riešenie a Ochrana |
|---|---|---|---|
| 61 | **Zahltaná mobilná sieť v športovej hale s 2000 divákmi** | 100% strata paketov, timeouty synchronizácie. | Plný offline režim so zobrazením lokálne uložených dát bez blokovania UI. |
| 62 | **Kvapky potu / vody na displeji iPhonu počas tréningu** | Náhodné falošné dotyky posúvajú figúry po canvase. | Tlačidlo *"Zámok parketu"* (Lock Canvas), ktoré deaktivuje posun kariet. |
| 63 | **Zhasnutie / uzamknutie obrazovky (Auto-Lock) uprostred tanca** | Displej zhasne po 30 sekundách, tanečník nevidí zostavu. | Nastaviť `UIApplication.shared.isIdleTimerDisabled = true` počas otvoreného Canvasu. |
| 64 | **Zmena siete z 5G na štúdiovú Wi-Fi uprostred uploadu videa** | HTTP spojenie sa preruší a nahrávanie zlyhá. | Použiť `URLSessionUploadTask` s podporou automatického obnovenia (Resumable Upload). |
| 65 | **Prehrávanie videa cez štúdiový Bluetooth reproduktor s oneskorením** | Zvuk mešká 300 ms za videom (desynchronizácia dôb). | Možnosť manuálneho posunu audio offsetu (+/- ms) v prehrávači. |
| 66 | **Paralelné cvičenie: Apple Fitness / Tréning beží na hodinkách** | Dve audio-aktívne aplikácie bojujú o kategóriu relácie. | Nastavenie `AVAudioSessionCategoryOptionMixWithOthers`. |
| 67 | **Zdieľanie choreografie cez AirDrop (`.encore` súbor)** | Systém nevie priradiť súbor aplikácii. | Zaregistrovať vlastný Document Type a UTI `com.encore.routine` v `Info.plist`. |
| 68 | **Odpojenie AirPlay TV uprostred tímového rozboru na kempe** | Prehrávač zamrzne alebo spadne pri strate externého displeja. | Odchytiť `UIScreen.didDisconnectNotification` a vrátiť prehrávanie na telefón. |
| 69 | **Rýchle viacnásobné klikanie na tlačidlo Nahrávať (Spamming)** | Spustenie viacerých inštancií rekordéra za sebou. | Debounce na tlačidle nahrávania (blokovanie na 500 ms po kliknutí). |
| 70 | **Rýchle zmazanie figúry počas prebiehajúceho uploadu jej videa** | Upload nahrá video do cloudu, ale figúra v databáze už neexistuje. | Zrušiť priradený `Task` uploadu pri volaní `deleteVideo()`. |
| 71 | **Otvorenie dvoch okien aplikácie na iPade (Stage Manager)** | Dve inštancie `RoutineCanvasView` naraz pristupujú k SwiftData. | SwiftData `ModelContext` koordinácia a zdieľaný state kontajner. |
| 72 | **Súčasná editácia zostavy tromi partnermi na medzinárodnom kempe** | Konflikt viacerých WebSocket streamov na jednom kanáli. | Kanál routovaný podľa `routineId` s priradením unikátneho `clientId` pre každého. |
| 73 | **Cudzojazyčné znaky v názvoch figúr (Azbuka, Japončina, Čínština)** | Poškodenie kódovania pri prenose cez QR kód alebo JSON. | Striktné kódovanie `String.Encoding.utf8` vo všetkých serializátoroch. |
| 74 | **Prepnutie používateľského konta v offline režime** | Zobrazenie dát predchádzajúceho používateľa. | Reset lokálneho SwiftData kontextu pri zmene `AuthManager.currentUser`. |
| 75 | **Poškodená hlavička videa (`moov atom`) pri násilnom reštarte iPhonu** | Video sa nedá prehrať v iOS ani na webe. | `UIImagePickerController` automaticky finalizuje hlavičku priamo cez AVFoundation. |
| 76 | **Hardvérový prepínač tichého režimu (Mute Switch) na iPhone** | Používateľ nepočuje video ani rytmus. | Nastavenie kategórie `.playback` ignoruje hardvérový Silent Switch podľa Apple HIG. |
| 77 | **Extrémne veľká vlastná knižnica figúr (500+ položiek)** | Pomalé načítanie zoznamu figúr v paneli. | Použitie `LazyVStack` a stránkovania (Pagination) v `GlobalLibraryView`. |
| 78 | **Aktivácia Siri ("Hey Siri") počas nahrávania tanca** | Siri preruší mikrofón aj nahrávanie kamery. | Odchytiť prerušenie relácie a po skončení Siri umožniť pokračovanie. |
| 79 | **Zapnuté nahrávanie obrazovky iOS (Screen Recording v Control Center)** | Limitovaný prístup k video hardvéru. | Kompatibilné spracovanie cez štandardný `UIImagePickerController`. |
| 80 | **Používateľ manuálne zruší Live Activity v Dynamic Islande** | Aplikácia sa pokúsi poslať update do neexistujúcej aktivity. | Ošetriť `Activity.activityState == .dismissed` pred volaním `update()`. |
| 81 | **Prechod na letný/zimný čas (Daylight Saving) uprostred nočného tréningu** | Chyba vo výpočte trvania tréningu v štatistikách. | Výpočet dĺžky tréningu cez `Date().timeIntervalSince(startTime)`. |
| 82 | **Poškodený náhľadový obrázok (Thumbnail) stiahnutý z cloudu** | Pád aplikácie pri pokuse o zobrazenie poškodeného JPG. | Bezpečný guard `UIImage(data:)` s fallbackom na generickú ikonu tanca. |
| 83 | **Zablokovanie Face ID po 5 neúspešných pokusoch v tmavej sále** | Aplikácia neumožní prihlásenie tvárou. | Automatický plynulý fallback na zadanie hesla alebo biometrického kódu iPhonu. |
| 84 | **Zapnutý režim vysokého kontrastu v Nastaveniach prístupnosti** | Strata viditeľnosti jemných farieb na parkete. | Kontrola `@Environment(\.colorSchemeContrast)` a zosilnenie okrajov kariet. |
| 85 | **Uspanie aplikácie počas sťahovania zostavy z cloudu** | Sťahovanie zlyhá uprostred prenosu. | Konfigurácia `URLSessionConfiguration.background` pre sieťové úlohy. |
| 86 | **Detský účet (Family Sharing) s obmedzenými právami** | Zákaz prístupu k mikrofónu alebo cloudu. | Zobrazenie zrozumiteľného vysvetlenia namiesto nekonečného načítavania. |
| 87 | **Rýchle prepínanie kategórií tancov počas prehrávania videa** | Video z predchádzajúceho tanca hrá na pozadí nového. | Okamžité zastavenie a deallocácia prehrávača pri zmene tanca. |
| 88 | **Nedostatočná šírka pásma pri AirPlay 4K zrkadlení** | Sekanie obrazu na veľkej TV v tanečnej sále. | Ponúknuť zníženie rozlíšenia streamu na 1080p pre plynulých 60 FPS. |
| 89 | **Roztrasený statív pri dynamických skokoch na parkete** | Obraz z kamery vibruje a stráca ostrosť. | Automatická aktivácia hardvérovej stabilizácie senzora (Cinematic Stabilization). |
| 90 | **Import zostavy s neznámym budúcim ID tanca z novej verzie appky** | Staršia verzia aplikácie nerozpozná disciplínu. | Fallback na univerzálny tanec (*"Vlastný tanec"*) s možnosťou manuálneho zaradenia. |

---

### Kategória VII: Registrácia, prihlásenie a účet (Scenáre A1 – A62)

> Audit z 5. 10. 2026, podrobnosti a skóre (3/10) sú v [docs/AUTH_AUDIT.md](./docs/AUTH_AUDIT.md).
> Stav: ✅ v poriadku · 🛠️ opravené v kóde alebo skripte, čaká na nasadenie · ⚠️ čiastočne · ❌ chyba · ➖ chýba · ❓ neoverené (treba skúsiť alebo skontrolovať v Dashboarde).
> Aktualizované 6. 10. 2026 po opravách; čo presne treba nasadiť a v akom poradí je v [docs/AUTH_AUDIT.md](./docs/AUTH_AUDIT.md).
> Pri každom riadku zapíš po oprave dátum a výsledok testu.

#### Registrácia

| # | Situácia | Stav | Dôsledok / Oprava |
|---|---|---|---|
| A1 | Nový e-mail + heslo | 🛠️ | Kód z e-mailu je v appke hotový. Čaká na Dashboard (Confirm email ON, SMTP) a potom `20261006_enable_email_confirmation.sql`. |
| A2 | Rovnaký e-mail zaregistrovaný dvakrát | ✅ | Rozpozná sa podľa prázdneho `identities`. |
| A3 | Pre-hijacking: útočník zaregistruje cudzí e-mail, obeť sa potom prihlási cez Google/Apple | 🛠️ | Odstráni sa tým istým krokom ako A1 (overenie e-mailu pred plným účtom). |
| A4 | Heslo 6 znakov | 🛠️ | Klient vyžaduje 8 znakov a odmieta časté heslá. Server: v Dashboarde nastav min. 8 a „letters + digits“. |
| A5 | Heslo s medzerami, emoji, veľmi dlhé | ✅ | Heslo sa neorezáva, limit 128 znakov doplnený. |
| A6 | E-mail s medzerami alebo veľkými písmenami | ✅ | Medzery sa orežú, server porovnáva bez ohľadu na veľkosť písmen. |
| A7 | Neplatný e-mail (`a@b`) | ✅ | Klient kontroluje formát e-mailu pred odoslaním. |
| A8 | Meno veľmi dlhé alebo s HTML | 🛠️ | Klient limit 60 znakov hotový; DB obmedzenie a orezanie v sign-up triggeri je v migrácii `20261006_auth_account_lifecycle.sql`. |
| A9 | Dvojité ťuknutie na „Registrovať“ | ✅ | Tlačidlo je počas načítania vypnuté. |
| A10 | Registrácia prejde na serveri, ale odpoveď sa stratí (slabý signál) | ✅ | Hláška „účet už existuje, prihlás sa alebo si obnov heslo“; nepotvrdený účet pri prihlásení rovno ponúkne kód. |
| A11 | Hromadné registrácie botov | ➖ | Žiadna CAPTCHA ani limit. Turnstile / App Attest. |
| A12 | Používateľ mladší ako 16 rokov (tanečníci sú často juniori) | ✅ | Povinné potvrdenie veku (16+ alebo súhlas rodiča), uložené v metadátach. Formálne overenie veku nie je. |
| A13 | Apple „Skryť môj e-mail“ (relay adresa) | ❓ | Pozvánky a prepojenia podľa e-mailu nebudú fungovať, účty sa nedajú spojiť. |
| A14 | Apple pošle meno len pri prvom prihlásení, prvá výmena tokenu zlyhá | ❌ | Meno sa stratí natrvalo. Uložiť hneď po autorizácii. |
| A15 | Súhlas s podmienkami a zásadami | ⚠️ | Len text pod tlačidlom. Overiť požiadavky GDPR a zhodu s `PrivacyInfo.xcprivacy` (❓). |

#### Prihlásenie

| # | Situácia | Stav | Dôsledok / Oprava |
|---|---|---|---|
| A16 | Správny e-mail a heslo | ✅ | |
| A17 | Zlé heslo alebo neexistujúci účet | ✅ | Rovnaká hláška (žiadne zisťovanie existencie účtu). |
| A18 | Nepotvrdený e-mail (po zapnutí potvrdzovania) | ✅ | Prihlásenie nepotvrdeného účtu pošle nový kód a otvorí zadanie kódu; je tam aj „poslať znova“. |
| A19 | Bez internetu | ✅ | Sieťové chyby sa rozpoznávajú podľa `URLError` kódu, nie textu. |
| A20 | Server vráti 5xx alebo je v údržbe | ⚠️ | Všeobecná hláška. |
| A21 | Príliš veľa pokusov (rate limit) | ✅ | Rate limit sa rozpoznáva podľa kódu chyby a HTTP 429. |
| A22 | Klávesnica: Return nepresunie ani neodošle | ✅ | Return posúva medzi poľami a na konci odošle. |
| A23 | Zobraziť / skryť heslo | ✅ | Pole hesla má oko na zobrazenie a skrytie. |
| A24 | iCloud Keychain / automatické dopĺňanie | ✅ | `textContentType` je nastavené. Prepojenie s doménou (webcredentials) až s doménou. |
| A25 | Face ID pri existujúcej relácii | ✅ | |
| A26 | Face ID po odhlásení | ✅ | Zámerne nedostupné. |
| A27 | Face ID zablokované alebo vypnuté v nastaveniach | ✅ | Hláška a odkaz do Nastavení. |
| A28 | Stav tlačidla Face ID sa počíta pri každom prekreslení | ✅ | Stav tlačidla Face ID sa načíta raz pri zobrazení. |
| A29 | Štart appky offline s platnou reláciou | ✅ | Používateľ ostane prihlásený. |
| A30 | Heslo zmenené na inom zariadení, token revokovaný | ✅ | Listener odhlási. Lokálne dáta ostanú (pozri A51). |
| A31 | Google z prihlasovacej obrazovky otvorenej ako sheet | ✅ | Google sa prezentuje z najvyššieho zobrazeného okna. |
| A32 | Google záložný tok cez Safari | ✅ | Záložný tok používa `ASWebAuthenticationSession` a vráti úspech len pri skutočnej relácii. |
| A33 | Google bez nonce | ⚠️ | Slabšia ochrana proti opätovnému použitiu tokenu. |
| A34 | Apple prihlásenie bez entitlementu (do kúpy Developer účtu) | ✅ | Tlačidlo Apple je skryté príznakom `AuthFeatureFlags.appleSignInEnabled`, kým nie je Developer účet. |
| A35 | Apple a Google ponúknuté spolu | ✅ | Požiadavka 4.8 sa splní, keď Apple funguje. |
| A36 | Zlý čas na zariadení (JWT „not yet valid / expired“) | ⚠️ | Chyby TLS a dátumu majú hlášku; chyba času v JWT samostatnú nemá. |
| A37 | Prihlásenie cez Wi-Fi s portálom (hotel, hala) | ➖ | Žiadna špecifická hláška. |
| A38 | Dva pokusy naraz (Google a e-mail) | ⚠️ | Stav `isLoading` je spoločný, ale tok sa neruší. |

#### Obnova hesla a odkazy

| # | Situácia | Stav | Dôsledok / Oprava |
|---|---|---|---|
| A39 | Žiadosť o obnovu pre neznámy e-mail | ✅ | Rovnaká odpoveď. |
| A40 | Odkaz otvorený na inom zariadení (PKCE chýba overovač) | ✅ | Obnova a potvrdenie idú cez 6-miestny kód, ktorý funguje na akomkoľvek zariadení. |
| A41 | Použitý alebo expirovaný odkaz | ✅ | „Odkaz už vypršal“. |
| A42 | Potvrdzovací odkaz do hodiny od žiadosti o obnovu | ✅ | Hlavná cesta je kód, nie hádanie z odkazu. Heuristika ostáva len pre záložný odkaz. |
| A43 | Odkaz pre iný účet, kým je prihlásený niekto iný | ❌ | Relácia sa potichu prepíše. Vyžiadať potvrdenie. |
| A44 | Zatvorenie okna obnovy bez nastavenia hesla | ⚠️ | Používateľ ostane prihlásený cez recovery reláciu. |
| A45 | Zmena hesla v appke (staré heslo overené) | ✅ | |
| A46 | Po zmene alebo obnove hesla ostatné zariadenia | ✅ | Po nastavení nového hesla sa ostatné zariadenia odhlásia (`signOut(scope: .others)`). |
| A47 | Limit vstavaného odosielania e-mailov | ❓ | Veľmi nízky bez vlastného SMTP. Nastaviť Resend. |
| A48 | Site URL v Dashboarde ukazuje na localhost | ❓ | Odkazy by viedli nikam. Skontrolovať. |
| A49 | Škodlivá aplikácia zaregistruje `encore://` | ✅ | PKCE (SDK 2.52.0) a kódy z e-mailu; odkaz nie je nutný. |

#### Odhlásenie, zmena účtu, zmazanie

| # | Situácia | Stav | Dôsledok / Oprava |
|---|---|---|---|
| A50 | Odhlásenie bez internetu, potom reštart appky | ✅ | Overené v zdroji SDK 2.52.0: lokálna relácia sa zmaže pred volaním servera. |
| A51 | Odhlásenie a prihlásenie iného účtu na tom istom zariadení | ✅ | `LocalDataGuard` vymaže dáta predchádzajúceho účtu pri prihlásení iného; rovnaký účet ich zachová. |
| A52 | Zmazanie účtu | 🛠️ | Edge funkcia `delete-account` je napísaná; appka tvrdí „zmazané“ až po potvrdení servera. Treba ju nasadiť. |
| A53 | Zmazanie: FK `routines.user_id` (NO ACTION), `user_entitlements.granted_by`, `connections.initiated_by` | 🛠️ | Zmenené FK sú v migrácii `20261006_auth_account_lifecycle.sql`. |
| A54 | Zmazanie: videá a fotky v úložisku | 🛠️ | Funkcia `delete-account` najprv zmaže súbory v úložisku. |
| A55 | Zmazanie: odvolanie tokenu Sign in with Apple | ➖ | Požiadavka Apple. |
| A56 | Zmazanie: bez dodatočného overenia | ⚠️ | Len dialóg. Pridať Face ID alebo heslo. |
| A57 | Zmazanie: aktívne predplatné v App Store | ✅ | Dialóg upozorní, že predplatné v App Store sa nezruší samo. |
| A58 | Preinštalovanie appky | ✅ | Čerstvá inštalácia (bez uloženého e-mailu) začína odhlásená. |
| A59 | Ban účtu | 🛠️ | `admin_set_account_status` nastaví `banned_until`, zmaže relácie a RLS politiky `active_account_only` zablokujú dáta hneď. V migrácii. |
| A60 | Zmena e-mailu v appke | ➖ | Chýba (aj `double_confirm_changes`). |
| A61 | Export vlastných dát z cloudu (GDPR čl. 20) | ⚠️ | Export JSON je len lokálny. |
| A62 | Zmena `dancer_code`, `invite_code` na cudzí kód | 🛠️ | `dancer_code` generuje server, klient nesmie meniť `dancer_code`, `invite_code` ani `email`. V migrácii. |

#### Databáza a funkcie (súvisí s účtami)

| # | Situácia | Stav | Dôsledok / Oprava |
|---|---|---|---|
| D1 | Funkcie `SECURITY DEFINER` volateľné anonymne | ⚠️ | Pripravené v `supabase/migrations/20261005_hardening_function_grants.sql`, treba spustiť. |
| D2 | `record_app_store_transaction` dovolí kohokoľvek nastaviť si plán Studio | ❌ | Uzavreté v tej istej migrácii, treba spustiť. |
| D3 | Edge funkcia `send-email` (nenasadená) | 🛠️ | `send-email` prepísaná: len pozvánka, escapovanie, kód zo servera, limit 5 za deň. Nenasadená. |
| D4 | Leaked password protection | ❌ | Vypnuté (advisor). |
| D5 | Duplicitný unikátny index `invite_code` | 🛠️ | Duplicitný index sa zmaže v migrácii. |
| D6 | `profiles.email` | ⚠️ | Osobný údaj, uvádzať v zásadách ochrany súkromia a pri zmazaní. |
| D7 | Zmeny schémy robené v SQL editore, `list_migrations` je prázdny | ✅ | Nové zmeny sú v `supabase/migrations/`. Aplikujú sa stále ručne v SQL editore. |

---

### Kategória VIII: Poznámky, reflexie a hlasovky: zálohy a zmena účtu (Scenáre B1 – B12)

> Zistené 23. 11. 2026 pri teste na iPhone a kontrole servera (záznamy v `device_records`, logy funkcie `media-share`).
> Stav ako v kategórii VII. Po oprave zapíš commit a výsledok testu.

| # | Situácia | Stav | Dôsledok / Oprava |
|---|---|---|---|
| B1 | „Bez tanca" na poznámke, ktorá je reflexiou po tréningu | ✅ | Poznámka a reflexia boli ten istý text zapísaný dvakrát. Reflexia (plán, trendy, Top 3) ostala so starým tancom a jej ďalšie uloženie vrátilo tanec aj do poznámky. Oprava 327a8ed: poznámka a reflexia sa držia spolu (tanec aj slová), testy `ReflectionMirrorTests`. |
| B2 | Zmazanie reflexie alebo jej poznámky v Denníku (alebo zmazanie tréningu s reflexiami) | ✅ | Poznámka a reflexia sú jedno: zmazanie jednej zmaže druhú. Oprava d45e0d2 (reflexia zmaže poznámku, `TrainingLogEntry.delete(in:)`) a 0b09138 (poznámka zmaže reflexiu, `InstantNote.delete(in:)`; tri miesta, ktoré mazali poznámku, idú cez jednu funkciu a poznámka, ktorá je aj reflexiou, sa najprv opýta). Testy `ReflectionMirrorTests`. |
| B3 | „Vrátiť medzi nové" na poznámke pridanej k figúre | ✅ | Karta držala názov figúry a filter „Bez figúry" ju vynechal. Oprava fb581b1. |
| B4 | Nahrávka, ktorú cloud odmietne (neznámy názov, príliš veľká) | ✅ | Zastavila nahrávanie všetkých ďalších hlasoviek. Oprava 16561a0: preskočí sa, ostatné idú ďalej. |
| B5 | Server pri sťahovaní hlasovky odpovie chybou (zlá chvíľa, nedokončené prihlásenie) | ✅ | Nahrávka sa zapamätala ako „bez kópie" a nevrátila sa až do reštartu appky. Oprava 16561a0: zapamätá sa len odpoveď „kópia neexistuje". |
| B6 | Zmena účtu uprostred nahrávania hlasoviek do cloudu | ✅ | Zvyšok nahrávok účtu A by sa nahral pod účet B. Oprava 16561a0: každý krok overí, že otvorený účet je stále prihlásený. |
| B7 | Databáza prebudovaná prázdna (DatabaseRecoveryManager) | ✅ | Vyzerala ako zmazanie všetkých poznámok, z cloudu by sa zmazali kópie všetkých hlasoviek. Oprava 16561a0: kópia sa maže až po obnovení zálohy poznámok. |
| B8 | Hlasovka vo figúre na novom iPhone | ✅ | Oprava f973189: formátované poznámky figúr sa zálohujú ako záznam `figure_notes` v `device_records` a pri otvorení zostavy sa obnovia (hlasovka sa prehrá z cloudu, foto a video ostanú ako značka); f700945: nahrávka bez kópie ukáže "nedostupná" namiesto tlačidla, čo nič neurobí. **SQL pre nový druh záznamu (`device_records_kind_check`) čaká na schválenie a musí ísť pred buildom.** Neoverené v produkcii, len testy s náhradným cloudom. |
| B9 | Nahratie hlasovky zlyhá (slabé Wi-Fi) | ✅ | Oprava b6b513f: opakovanie 1 s, 5 s, 30 s, 5 min pre hlasovky aj zálohu denníka a odoslanie hneď po prihlásení. |
| B10 | Dlhá hlasovka (do 10 minút, okolo 10 MB) a odchod z appky | ❓ | Podľa kódu iOS appku uspí a nahrávanie sa začne od začiatku pri ďalšom návrate. Neoverené na iPhone. |
| B11 | Hlasovky z čias pred 8. 11. | ➖ | Pri vtedajšej zmene účtu sa súbory zmazali a kópie ešte neexistovali: poznámky s hlasovkou bez zvuku (v cloude 404). Nevratné, od 8. 11. sa nestratia. |
| B12 | Zmazaná poznámka z reflexie a ďalšie uloženie reflexie | ✅ | Rozhodnuté 24. 11.: poznámka a reflexia sú jedno, zmazaním poznámky sa zmaže aj reflexia, takže nie je čo uložiť znova (0b09138). |

## 🎯 Záver & Strategický Plán Implementácie

1. **Stav kamery je stabilný:** Natívny systém `UIImagePickerController` s bleskom vypnutým v predvolenom stave a pripravenou infraštruktúrou.
2. **Fáza 1 (Najbližšie vylepšenia kamery):**
   - Implementácia **Hands-Free Samospúšte (3s / 10s)** a **vodiacej mriežky (Grid)**.
   - Doplnenie **ochrany pred plným diskom** pred spustením videa.
3. **Fáza 2 (Súťažné a tréningové funkcie):**
   - **Side-by-Side porovnávací prehrávač** pre video rozbor techniky.
   - **Simulátor 5 tancov finále** s prepojením na Dynamic Island.
