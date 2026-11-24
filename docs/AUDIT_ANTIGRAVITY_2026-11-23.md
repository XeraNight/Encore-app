# Audit od Antigravity (23. 11. 2026): čo je pravda, čo je opravené, čo čaká

Každé tvrdenie overil čítací agent proti **aktuálnemu** kódu (nie proti číslam riadkov z auditu) a hlavné body som si prečítal aj ja.
`web/` som nečítal (je to časť Antigravity), takže jeho webové body (CSP `/support`, AASA `/add`, PKCE, `.or()` filter, wallet
`/api/wallet/pass`, `/u/[id]`) sú **neoverené**.

Dôležitý kontext: `AppFeatures.swift` má `coachTools`, `sharedVideos` a `partnerRoutines` vypnuté, takže realtime parket a tréner
vo v1 neexistujú. Aplikácia je iba pre iPhone.

Stav: ✅ opravené (commit) · 🟡 čaká na schválenie (viac súborov alebo SQL/Edge) · ⏸️ odložené (nízke, alebo až po zapnutí funkcie) · ❌ nepravda alebo zámer · ❓ treba zariadenie

## P0

| # | Tvrdenie | Verdikt | Stav |
|---|---|---|---|
| 1 | Únik dát medzi účtami | Čiastočne, vážnosť STREDNÁ. Skutočná diera: `PendingSyncRunner.run()` drží kontajner a ledger starého účtu aj po prepnutí (úzke okno). Hlasovky: opravené. Záloha denníka: guard `accountId == userId` pridaný. FriendManager/UserProfileStore: len zobrazenie, nízke. StoreKit `appAccountToken`: zámer (nákup patrí Apple ID). | ✅ b6b513f, 16561a0 (časť) · 🟡 zvyšok (balík A) |
| 2 | Ban bypass, mikrofón za Face ID | Mechanicky pravda, no ban vynucuje server (RLS, Edge, zrušené sessions), takže je to kozmetika. Mikrofón: rýchla akcia nie je viazaná na zámok. | 🟡 balík C |
| 3 | R2 kvóta (`voice_upload`) | Pravda: žiadna rezervácia ani limit. Cena je malá (25 GB ≈ 0,2 USD/mesiac), reálna škoda: Free používateľ má neobmedzené miesto. | 🟡 balík E (Edge) |
| 4 | `ksis-page` DoS | Pravda: (b) rounds sa nafúknu (zhodí vlastný worker), (c) `results()` bez limitu 2000 riadkov. | 🟡 balík E (Edge) |
| 5 | Migrácie `20261025_*` | Čiastočne. Nasadená databáza je v poriadku (zámok `birth_year` tam je). Chyba je v repozitári: rovnaké predpony, chýbajúci súbor s `coach_notes_by_name`. | ⏸️ hygiena repa (balík E) |
| 6 | Hlasovka sa zmaže pri hovore alebo limite 10 min | Pravda | ✅ 6e22538 |
| 7 | Kamera zahodí video pri hovore, zaseknutý stav | Pravda (VYSOKÁ). Plus displej sa mohol zamknúť počas záberu. | ✅ 45ca808 |
| 8 | KSIS updater | Prevažne nadsadené. Pravda: kalendár sa zmaže pri zmenenom HTML (3), súhlas ostáva zapnutý (7c), mŕtve tlačidlá (7d). | ✅ b1d5613, 9415639, 0d32ae0 · ⏸️ drobnosti |
| 9 | Realtime parket | Pravda v kóde, no vo v1 neexistuje (`partnerRoutines` vypnuté) | ⏸️ opraviť pred zapnutím |
| 10 | `pullRoutines` prepíše `updatedAt` | Pravda, len pre účet s dvoma zariadeniami | 🟡 jednoriadková oprava, treba súhlas |

## P1

| # | Tvrdenie | Verdikt | Stav |
|---|---|---|---|
| 1 | `user_blocks` nič neruší | Čiastočne: hosťujúci tréner ostane do vypršania | 🟡 SQL (balík E) |
| 2 | `enforce_single_partner` race | Pravda, nízke | 🟡 SQL |
| 3 | Tréner vkladá figúry | Latentné: tréner-prepojenia sú vypnuté triggerom | ⏸️ pred zapnutím trénera |
| 4 | PIN a `send-email` race | PIN pravda (nízke). `send-email` nie je nasadený. | 🟡 Edge |
| 5 | `delete-account` | Čiastočne: poradie Apple je v poriadku. Zvyšky mena trénera a sériové mazanie R2 sú pravda. | 🟡 Edge |
| 7 | Live Activities | (b) pravda: štart ju hneď ukončil. (a) pravdepodobne nepravda, (c) treba zariadenie. | ✅ 61c237e (b) |
| 8 | `PhotoLibraryVideoStore` pád | **Nepravda**: video požiadavky nevolajú handler dvakrát | ❌ |
| 9 | `VideoTrimView` | (d) pravda: zlý export nahradil video. (c) pravda. (a)(b) nepravda. | ✅ b89f178 |
| 10 | Kolízie `AVAudioSession` | (b) AirPods pravda, (c) Spotify pravda, (a) čiastočne | ✅ 0b65e3d, 257fe80 |
| 11 | `SpeechRecognizerHelper` | Čiastočne: formát 0 Hz zhodí appku | ✅ c4e63e0 |
| 12 | Pole poznámky zmizne, `.id(today)` | (a) pravda, (b) čiastočne | ✅ 4a22e26 (a) · ⏸️ (b) |
| 13 | Časové pásmo, DST | Pásmo pravda no nejasný zámer ("čas miesta"), DST čísla v audite sú iné | ❓ rozhodnúť |
| 14 | WKWebView, kalendár, NetworkMonitor | Politika: v praxi nie je riziko (host test + ATS). Kalendár: pravda. Hodiny: oprava v audite je zlá. | ✅ b1d5613 · ⏸️ drobnosti |
| 15 | Osirelé súbory | Pravda. **Štyri bezpodmienečné mazania videa môžu zmazať súbor, ktorý používa iná poznámka.** | 🟡 balík B |
| 16 | StoreKit | Prevažne zámer a produktové rozhodnutia | ❌/⏸️ |
| 17 | Mikrofón v kamere, zrkadlo, duel | (a) pravda: bez povolenia mikrofónu video bez zvuku a bez varovania | 🟡 balík D |

## P2 a P3 (stručne)

- Zlaté tlačidlo (Dynamic Type), skeleton 30 FPS, ETA odpočet: pravda, nízke. ⏸️
- Výkon parketu a trendov: pravda v tvare, v praxi nízke. ⏸️
- MainActor I/O: pravda pre mriežky médií (MediaResolver), Keychain a LAContext sú zanedbateľné. 🟡
- Dvojklik (EventKit, Free limit, `FigurePickerSheet`): pravda, nízke až stredné. 🟡
- Synchronizácia: vlastné figúry vytvorené offline sa nikdy nezopakujú (STREDNÉ, 🟡 balík A); trvalé 4xx držia opakovanie na 5 min (nízke až stredné, 🟡).
- Guest Coach, App Switcher snímka (STREDNÉ-nízke, 🟡 balík C), Wallet, `/u/[id]`: Wallet a `/u` sú webová časť, neoverené.
- P3: desatinné tempá (nízke), ghost video stlmené ✅ 14fe14c, AVPlayer cykly nepravda, `FullScreenVideo` session (nízke), QR hint (až s trénerom).

## Nové (nebolo v audite), zistené pri kontrole servera

- **Tabuľky bez limitu veľkosti** (`device_records` do 64 KB × 5000 riadkov denne, `figure_library_items`, `canvas_nodes`): jeden prihlásený
  používateľ vie cez PostgREST naplniť 500 MB Free databázy. VYSOKÁ pre Free plán. 🟡 SQL.
- `encore-media` bucket: INSERT politika bez kvóty, appka ju nepoužíva. 🟡 SQL (2 príkazy).
- Staré 4-miestne `dancer_code` sa dajú vyťažiť (STREDNÉ). 🟡 SQL.

## Balíky na schválenie

Stav 24. 11. po jeho odpovedi: **D áno, E áno, F neskôr (zapamätať), A, B a C nepochopil** (vysvetliť jednoducho a počkať na jeho slovo).

- **A, účty a zálohy** (SyncLedger, SupabaseSyncManager, DeviceBackup, VoiceBackup, GlobalLibraryView, FriendManager, UserProfileStore): identita kontajnera v behu synchronizácie, opakovanie vlastných figúr, nezasekávať opakovanie jedným zlým riadkom. 🟡 čaká na jeho slovo.
- **B, mazanie médií** (GlobalLibraryView, ProfileSettingsView, MediaAttachmentSections, VideoVaultView, MediaStorageManager): mazať video len ak ho nikto nepoužíva, obrázok pri mazaní poznámky (hotové v 0b09138), upratanie `tmp/` pri štarte. 🟡 čaká na jeho slovo.
- **C, súkromie a zámok** (AppLockView, EncoreApp, MainTabView, HomeCaptureWorkspace, QuickActions): štít v App Switcheri, rýchle akcie až po odomknutí, obrazovka banu namiesto prekrytia. 🟡 čaká na jeho slovo.
- **D, kamera a hlas** ✅ 24. 11.: refused microphone notice in the camera (09638c1), mirror notice + restart (a7d7e8f), negative offset in the duel (003b361, `DuelAlignment`), full-screen note video gives the audio session back (05cadcc). Nehotové z M9: zlé súradnice ťuknutia na zaostrenie v zrkadle (nízke).
- **E, databáza a servery**: pripravené 24. 11., **nič nespustené ani nenasadené**. SQL (limity veľkosti, bucket, `figure_notes`, voliteľný Dancer ID) je v `docs/SQL_NA_SCHVALENIE_2026-11-24.md`, otestované na kópii Postgres 17. Zmeny funkcií sú v repozitári: ksis-page 7ce1a58, media-share f037bab, delete-account e13404a, owner-delete-account 885cab0. Čaká na jeho "áno" (SQL) a "nasaď" (funkcie). Odložené nízke: `user_blocks` vs hosťujúci tréner a `enforce_single_partner` (obe až pred zapnutím trénera), RLS `auth.uid()` ako `(select auth.uid())` (výkon, upozornenie poradcu).
- **F, ostatné drobnosti** (`pullRoutines`, časové pásmo, `.id(today)`, KSIS drobnosti, dvojklik): jeho slovo 24. 11.: "potom doriešime, zatiaľ zapamätaj". Nezačínať.
