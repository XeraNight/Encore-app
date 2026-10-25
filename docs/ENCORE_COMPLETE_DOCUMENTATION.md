# 📖 Encore — Kompletná Projektová Dokumentácia

> **Verzia dokumentu:** 1.0 | **Dátum:** September 2026  
> **Bundle ID:** `com.jakub.encore` | **Aktuálna verzia:** 1.0 (Build 1)

---

## Obsah

1. [Brand Identita](#1-brand-identita)
2. [Architektonický Prehľad](#2-architektonický-prehľad)
3. [iOS App — Štruktúra & Dátový Model](#3-ios-app--štruktúra--dátový-model)
4. [UI/UX Dokumentácia](#4-uiux-dokumentácia)
5. [Infraštruktúra & Cloud Services](#5-infraštruktúra--cloud-services)
6. [3rd Party Knižnice & Integrácie](#6-3rd-party-knižnice--integrácie)
7. [Emergency Precautions & Systém Poistiek](#7-emergency-precautions--systém-poistiek)
8. [Release & Update Workflow](#8-release--update-workflow)
9. [Analytika & Monitoring](#9-analytika--monitoring)
10. [Bezpečnosť & GDPR](#10-bezpečnosť--gdpr)

---

## 1. Brand Identita

### Názov & Filozofia

| | |
|---|---|
| **Primárny názov** | Encore |
| **Súvisiaci brand** | Ellegance.sk (tanečná škola) |
| **Bundle Display Name** | Encore |
| **Tagline** | *Tvoj tanečný partner. Vždy poruke.* |
| **Publikum** | Súťažní tanečníci (Standard & Latin), tréneri, tanečné školy |

**Encore** reprezentuje *"ešte raz"* — opakovanie, zdokonaľovanie, ďalšie kolo na parkete. Aplikácia sprevádza tanečníkov pri analýze, tréningu a zdokonaľovaní každého kroku.

---

### Farebná Paleta (Design Tokens)

#### Primárna Paleta — Obsidian Luxury

| Token | Hex | Použitie |
|---|---|---|
| `obsidian900` / `themeBg` | `#050505` | Hlavné pozadie plátna |
| `obsidian800` | `#0A0A0A` | Sub-plátno, modal pozadie |
| `obsidian700` / `themeCard` | `#141418` | Karty, bubliny, panely |
| `themeDark` | `#F5F5F5` | Primárny text (biely na čiernom) |
| `themeTextSecondary` | `white 60%` | Sekundárny/popisný text |
| `themeBorder` | `Gold400 @ 20%` | Jemné zlaté orámovanie kariet |

#### Akcentová Paleta — Champagne Gold

| Token | Hex | Použitie |
|---|---|---|
| `amberGold` / `gold500` / `themeAccent` | `#D4AF37` | Primárny CTA, ikony, akcenty, beat pulz |
| `gold400` | `#FFE088` | Bevel efekt, TabBar tint |
| `gold300` | `#F9F1CC` | Svetlý šampanský akcent |

#### Encore Brand Paleta — Crimson Velvet

| Token | Hex | Použitie |
|---|---|---|
| `encoreCrimson` | `#780514` | Primárna brand farba, stage spotlight |
| `encoreCrimsonLight` | `#9A0D1F` | Hover / aktívny stav |
| `encoreBurgundy` | `#52020D` | Tieň, hĺbka |
| `encoreGold` | `#DCA51E` | Satin Gold brand variant |

#### Disciplínové Farby

| Token | Hex | Použitie |
|---|---|---|
| `standardBlue` | `#3B82F6` | Standard kategória (Waltz, Tango…) |
| `latinPink` / `latinCrimson` | `#F43F5E` / `#E11D48` | Latin kategória, REC indikátor |
| `syncEmerald` | `#10B981` | Cloud sync stav, úspech |

---

### Typografia

Encore používa výhradne **SF Pro** (systémový font iOS):

```
Primárne nadpisy:    .system(size: 20-28, weight: .heavy/.black, design: .rounded)
Sekundárne nadpisy:  .system(size: 15-18, weight: .bold, design: .rounded)
Telo textu:          .system(size: 13-15, weight: .medium/.semibold)
Monospace (BPM):     .system(size: 13, weight: .heavy, design: .monospaced)
Tracking labels:     ALL CAPS, tracking 1.0-1.5pt, .black weight
Waze-style pills:    .system(size: 12-14, weight: .heavy, design: .rounded)
```

### Logá

- `docs/brand/EncoreLogo_Full.svg` — kompletné logo s textom
- `docs/brand/EncoreLogo_Mark.svg` — ikonická značka (app icon základ)

---

## 2. Architektonický Prehľad

```
┌─────────────────────────────────────────────────────────────┐
│                     ENCORE EKOSYSTÉM                        │
├───────────────────┬─────────────────────┬───────────────────┤
│   iOS APP         │   WEB (Next.js)      │  CLOUD BACKEND    │
│   (Swift/SwiftUI) │   (Vercel)           │  (Supabase)       │
│                   │                     │                   │
│ • SwiftData DB    │ • Landing page       │ • PostgreSQL DB   │
│ • AVFoundation    │ • /support form      │ • Auth (JWT)      │
│ • Live Activities │ • /api/app-config    │ • Realtime ws://  │
│ • Widgets         │   (kill-switches)    │ • Row Level Sec.  │
│ • Metronome PCM   │ • PostHog web        │ • File Storage    │
│ • Remote Config   │                     │                   │
└───────────────────┴─────────────────────┴───────────────────┘
```

### Kľúčový Princíp: Offline-First

Primárne dáta sú **vždy na zariadení**. Cloud je synchronizácia, nie závislosť.

- Videá, rutiny, figúry → lokálne v SwiftData + `Documents/Videos/`
- Internet padol? Metronóm hrá, kamera nahráva, Canvas funguje.
- Sync sa spustí automaticky, keď sa spojenie obnoví.

---

## 3. iOS App — Štruktúra & Dátový Model

### Navigácia (Tab Bar)

```
MainTabView
├── Tab 0: "Domov"   → ContentView (Radial Hub + Zrkadlo + Tance)
├── Tab 1: "Canvas"  → CanvasRoutinesHubView (Rutiny + Kanvas)
├── Tab 2: "Kamera"  → CaptureModeView (sheet, nie Tab)
└── Tab 3: "Profil"  → ProfileView (nastavenia, video vault)
```

### Kľúčové Obrazovky

| Súbor | Funkcia |
|---|---|
| `ContentView.swift` | Radial Hub, Tance, Figúry, Zrkadlo, Metronóm |
| `CanvasRoutinesHubView.swift` | Správa rutín (zoznam, vytvorenie) |
| `RoutineCanvasView.swift` | Interaktívny plátno editor figúr |
| `DanceCameraView.swift` | Nahrávanie videa s metronómom, ghostingom, mriežkou |
| `DanceMirrorView.swift` | Tréningové zrkadlo s analýzou postoja |
| `ProfileView.swift` | Profil, VideoVault, nastavenia, výzvy |
| `VideoVaultView.swift` | Knižnica tréningových videí |
| `DualVideoComparisonView.swift` | Side-by-side porovnanie videa |
| `DanceMetronomeView.swift` | Plnohodnotný BPM tréner s vizuálnym pulzom |
| `StudioToolsView.swift` | Studio nástroje (metronóm, AirPlay, speed trainer) |
| `CompetitionOrganizerView.swift` | Organizátor súťaží |
| `CompetitionFinalSimulatorView.swift` | Simulátor finálového súťažného programu |

### SwiftData Dátový Model

```
Dance               id, name, category, tempo, info, imagePath?, videoPath?
FigureLibraryItem   id, name, danceName, rhythm, techniqueNotes, masteryRating(1-5), isCustom
Routine             id, name, danceName, danceCategory, createdAt, updatedAt
  └── canvasNodes: [CanvasNode]   (cascade delete)
  └── mediaVault:  [VideoMediaEntry] (cascade delete)
CanvasNode          id, x, y, figureName, rhythm, orderIndex, masteryRating
  └── mediaVault:  [VideoMediaEntry] (cascade delete)
VideoMediaEntry     id, filePath, title, role(myTake|targetIdol|coach|draft), isFavorite
InstantNote         id, createdAt, text, videoPath?, imagePath?
```

### Systémové Oprávnenia

| Kľúč | Popis |
|---|---|
| `NSCameraUsageDescription` | Nahrávanie tréningových videí a QR kódy |
| `NSMicrophoneUsageDescription` | Zvuk k videám a hlasové poznámky trénera |
| `NSPhotoLibraryUsageDescription` | Výber fotiek figúr a profilového obrázku |
| `NSPhotoLibraryAddUsageDescription` | Ukladanie QR kódov do Knižnice |
| `NSFaceIDUsageDescription` | Rýchle prihlásenie pomocou Face ID |
| `NSSpeechRecognitionUsageDescription` | Automatický prepis pokynov trénera |
| `NSSupportsLiveActivities` | Dynamic Island počas nahrávania |
| `UIBackgroundModes: audio` | Metronóm hrá pri uzamknutej obrazovke |

---

## 4. UI/UX Dokumentácia

### Design Systém: Dark Obsidian Luxury

Filozofia: Prémiová, elegantná estetika inšpirovaná javiskovou scénou.

```
Vrstva 1: Pozadie — EllegancePageBackground
          (Red Velvet Stage Spotlight + Obsidian Canvas)

Vrstva 2: Karty — themeCard (#141418)
          s jemným zlatým orámovaním (gold400 @ 20%)

Vrstva 3: Interaktívne prvky — amberGold (#D4AF37) akcent
          Aktívne = plná zlatá; Neaktívne = tmavá matná

Vrstva 4: Text — white 96% primárny / white 60% sekundárny
                 amberGold pre kategórie a labely
```

### Kľúčové UI Vzory

**1. Luxury Gold CTA Button**
```swift
.background(LinearGradient(colors: [.amberGold, gold-dark]))
.foregroundColor(.black)
.clipShape(RoundedRectangle(cornerRadius: 14))
.shadow(color: amberGold @ 35%, radius: 12)
```

**2. Waze Filter Pills (kamera, štítky)**
```swift
.font(.system(size: 13, weight: .bold, design: .rounded))
.background(active ? amberGold : black @ 68%)
.clipShape(Capsule())
.overlay(Capsule stroke)
.shadow(radius: 6, y: 2)
```

**3. Icon Badge (odznak s ikonou)**
```swift
ZStack {
    RoundedRectangle(cornerRadius: 10)
        .fill(accentColor.opacity(0.18))
        .frame(width: 44, height: 44)
    Image(systemName: icon).foregroundColor(accentColor)
}
```

**4. Discipline Color Coding**
- 🔵 Standard tance: `standardBlue #3B82F6`
- 🔴 Latin tance: `latinCrimson #E11D48`

### Animácie & Mikrointerakcie

| Prvok | Animácia |
|---|---|
| Radial Hub otváranie | `.spring(response: 0.5, dampingFraction: 0.7)` |
| Beat pulz metronómu | `.easeInOut` veľkosť kruhu |
| Toast notifikácie | `.move(edge: .top).combined(with: .opacity)` |
| Tab prechod | `.easeInOut(duration: 0.28)` |
| Karta rozbalenie | `.interactiveSpring(response: 0.4)` |

### Haptická Spätná Väzba

```swift
HapticFeedback.light()   // výber, chip toggle, navigácia
HapticFeedback.medium()  // akcia potvrdenia, uloženie
HapticFeedback.heavy()   // kritická akcia, START nahrávania
```

### Kamerový UI (DanceCameraView)

```
ZStack (full-screen)
├── 1. CameraPreviewRepresentable (live preview)
├── 2. GhostPlayerRepresentable (onion skin overlay, opacity 15-85%)
├── 3. CameraGridAndLevelOverlay (3x3 mriežka + gyroskopický horizont)
├── 4. Countdown Overlay (veľké číslo, zaoblená typografia)
├── 5. Instant Memory Toast (hore, amber gold)
└── 6. Controls Deck (VStack)
    ├── topHeaderBar (X + baterka)
    ├── actionControlStrip (Waze pills: Metronóm | Mriežka | Spúšť | Ghost)
    ├── metronomeStatusPill (keď metronóm beží)
    ├── [Spacer]
    ├── CameraVUMeterView + recordingPill
    ├── zoomSwitcherBar (0.5x / 1x / 2x)
    └── bottomControlsDeck (shutter + ghost opacity)
```

### Prístupnosť

- Všetky interaktívne prvky: min. 44×44 pt (Apple HIG)
- Kontrast: biely text na `#141418` = ~14:1 (WCAG AAA)
- VoiceOver: kľúčové akcie sú labelované
- Dynamický typ: veľkosti sú relatívne

---

## 5. Infraštruktúra & Cloud Services

### Architektúra Produkcie

```
encore-app.vercel.app         iukblwlttvrcdclmlyxu.supabase.co
┌─────────────────────┐          ┌──────────────────────────┐
│  Next.js 16 (Vercel)│◄─────────│  Supabase (PostgreSQL)   │
│  Edge Runtime       │          │  Auth + Realtime + RLS   │
│  /api/app-config    │          │  EU Region (Frankfurt)   │
│  /support (Form)    │          └──────────────────────────┘
└─────────────────────┘
         │
         ▼
PostHog EU (eu.posthog.com)   Better Stack (Logs + Uptime)
```

### Supabase Backend

**Projekt URL:** `https://iukblwlttvrcdclmlyxu.supabase.co`  
**Región:** EU Frankfurt — GDPR compliant

| Služba | Použitie |
|---|---|
| PostgreSQL | Cloudová sync profilu, rutín, pokrokov |
| Auth | Email, Apple Sign In, Google OAuth |
| Realtime | Kooperácia na canvas v reálnom čase (websockets) |
| Row Level Security | Každý user vidí iba vlastné dáta |
| Storage | (Pripravené) Cloudové zálohy videí |

### Vercel Web Frontend

**URL:** `https://encore-app.vercel.app`  
**Framework:** Next.js 16 (App Router, Turbopack)

| Route | Typ | Funkcia |
|---|---|---|
| `/` | Dynamic | Landing page |
| `/login` | Static | Prihlásenie |
| `/support` | Static | Kontaktný formulár (Formspree) |
| `/privacy` | Static | Zásady ochrany súkromia |
| `/dashboard` | Dynamic | Admin prehľad |
| `/api/app-config` | Edge API | Kill-switche pre iOS appku |
| `/auth/callback` | Dynamic | OAuth redirect |

### Environment Variables

**Vercel Dashboard (produkcia):**
```
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY
NEXT_PUBLIC_POSTHOG_KEY
NEXT_PUBLIC_POSTHOG_HOST=https://eu.posthog.com
LOGTAIL_SOURCE_TOKEN
```

**iOS (Secrets.xcconfig — NESMIE BYŤ NA GITHUB):**
```
SUPABASE_URL
SUPABASE_ANON_KEY
GID_CLIENT_ID
```

---

## 6. 3rd Party Knižnice & Integrácie

### iOS (Swift Package Manager)

| Knižnica | Zdroj | Funkcia |
|---|---|---|
| **Supabase Swift** | github.com/supabase-community/supabase-swift | Auth, DB, Realtime |
| **GoogleSignIn-iOS** | github.com/google/GoogleSignIn-iOS | Google OAuth |
| **PostHog iOS** | github.com/PostHog/posthog-ios | Analytika *(odkomentovať po setup)* |

### iOS — Apple Frameworky

| Framework | Použitie |
|---|---|
| **SwiftData** | Lokálna databáza (tance, figúry, rutiny, videá) |
| **SwiftUI** | Celé používateľské rozhranie |
| **AVFoundation** | Kamera, nahrávanie, audio session, metronóm PCM |
| **ActivityKit** | Live Activities / Dynamic Island |
| **WidgetKit** | Homescreen widgety |
| **Speech** | Rozpoznávanie reči (pokyny trénera) |
| **CoreMotion** | Gyroskop — úroveň horizontu v kamere |
| **OSLog** | Štruktúrované logovanie (Console.app) |
| **UserNotifications** | Push notifikácie |
| **WatchConnectivity** | Apple Watch cueing |

### Web (npm packages)

| Balíček | Funkcia |
|---|---|
| next 16 | React framework, App Router |
| @supabase/supabase-js | Supabase klient |
| posthog-js | Web analytika |
| @formspree/react | Kontaktný formulár |
| typescript | Typová bezpečnosť |

### Externé Služby (SaaS)

| Služba | Plán | Funkcia |
|---|---|---|
| **Supabase** | Free → Pro | Backend DB + Auth + Realtime |
| **Vercel** | Free → Pro | Web hosting + auto-deploy z GitHub |
| **PostHog** | Free (EU Cloud) | Anonymná analytika |
| **Better Stack** | Free | Logy + Uptime monitoring |
| **Formspree** | Free (50/mes) | Kontaktný formulár |
| **Apple Developer** | $99/rok | App Store, TestFlight, Push |
| **Google Cloud** | Free tier | Google Sign In OAuth |

---

## 7. Emergency Precautions & Systém Poistiek

### Rýchlosť Reakcie

```
⚡ Sekundy:  Remote Config Kill-Switch (vypni funkciu)
🔧 Minúty:   Maintenance Mode (informuj používateľov)
📱 Hodiny:   TestFlight Hotfix Build
🏪 24-48h:   App Store Expedited Review
```

### Kill-Switches (Vypínače funkcií)

**Endpoint:** `https://encore-app.vercel.app/api/app-config`  
**Súbory:** `web/src/app/api/app-config/route.ts` + `Encore/RemoteConfigManager.swift`

```json
{
  "features": {
    "canvas_realtime": true,
    "cloud_sync": true,
    "posture_analysis": true,
    "ghost_overlay": true,
    "dual_video_comparison": true,
    "music_speed_trainer": true,
    "dance_metronome": true,
    "in_app_feedback": true
  },
  "maintenance_mode": false,
  "maintenance_message": "...",
  "min_version": "1.0.0",
  "app_store_url": "https://apps.apple.com/app/encore/id..."
}
```

**Postup vypnutia funkcie:**
1. Zmeň `"ghost_overlay": false` v `route.ts`
2. Git push → Vercel deployuje za 30 sekúnd
3. iOS appka sa synchronizuje do 60 sekúnd

### Databázová Záchrana (DatabaseRecoveryManager)

Pri každej SwiftData migrácii:
1. Automatická záloha SQLite → `Documents/DatabaseBackups/{timestamp}/`
2. Ak migrácia zlyhá → čistá inštalácia, appka nepadne do slučky
3. Záloha zostáva pre prípadnú ručnú obnovu

### Phased Release (Postupné vydávanie)

**Vždy zapni pri každom App Store release!**

| Deň | % Používateľov |
|---|---|
| 1 | 1% |
| 2 | 2% |
| 3 | 5% |
| 4 | 10% |
| 5 | 20% |
| 6 | 50% |
| 7 | 100% |

Pri chybe: **Pause Release** v App Store Connect → 99% zostáva na starej verzii.

---

## 8. Release & Update Workflow

### Typy Build Zostáv

| Typ | Kde beží | Na čo |
|---|---|---|
| **Debug (kábel)** | iPhone cez kábel / Wi-Fi | Vývoj, okamžité testovanie |
| **TestFlight** | TestFlight app na iPhone | Overenie pred vydaním |
| **App Store** | App Store | Produkcia pre používateľov |

### Postup Vydania Novej Verzie

```
1. VÝVOJ
   - Testuj cez kábel (Debug build)
   - Overenie: xcodebuild → ** BUILD SUCCEEDED **

2. TESTFLIGHT
   - Zvýš Build Number v Xcode (General → Build: napr. 1 → 2)
   - Product → Archive → Distribute App → TestFlight
   - Po 5-10 min: notifikácia na iPhone cez TestFlight app
   - Testuj minimálne 24-48h na reálnom zariadení

3. APP STORE
   - App Store Connect → "Submit for Review"
   - VŽDY zapni "Phased Release"
   - Schválenie: 24-48h (prvý submit) / 1-24h (update)

4. POST-RELEASE (prvé 48h)
   - Sleduj PostHog (crash rate, drop v udalostiach)
   - Sleduj Better Stack (web uptime)
   - Kontroluj App Store Connect → Crashes & Feedback
```

### Postup pri Kritickej Chybe

```
OKAMŽITE → Vypni funkciu cez Kill-Switch

HOTFIX BUILD (ak treba patch kódu):
  → Oprav na dev branchi
  → TestFlight build (overenie na iPhone)
  → Expedited Review: developer.apple.com → Request Expedited Review
  → Apple schváli do 2-4h (bezpečnostné problémy)

SERVER-SIDE FIX (bez iOS update):
  → Oprav Supabase SQL / Vercel API
  → Zmena sa prejaví okamžite bez App Store review
```

---

## 9. Analytika & Monitoring

### Sledované Eventy (PostHog)

| Event | Vlastnosti | Účel |
|---|---|---|
| `mirror_opened` | `source` | Odkiaľ sa otvára zrkadlo |
| `auth_signin_apple` | — | Preferovaná metóda prihlásenia |
| `auth_signin_google` | — | Preferovaná metóda |
| `auth_signin_email` | — | Preferovaná metóda |
| `routine_created` | `dance_name`, `dance_category` | Popularita tancov |
| `canvas_opened` | `routine_id`, `dance_name` | Frekvencia úprav rutín |
| `canvas_node_added` | `figure_name`, `dance_name` | Najpoužívanejšie figúry |
| `metronome_started` | `bpm`, `dance` | Využitie metronómu |
| `dance_card_viewed` | `dance_name`, `category` | Záujem o tance |
| `routine_exported_json` | — | Využitie exportu |
| `account_deleted` | — | Churn signál |

### Odporúčané PostHog Dashboardy

1. **Engagement:** DAU/WAU/MAU, dĺžka session
2. **Feature Adoption:** Mirror opens, metronome starts, canvas edits
3. **Dance Popularity:** Funnel `dance_card_viewed` → `routine_created`
4. **Churn Signals:** `account_deleted` trend

### Monitoring

- **Better Stack Uptime:** Alert ak web padne na 2+ minúty → Email
- **Better Stack Logs:** Structured JSON z Next.js backendu
- **Xcode Organizer:** Crash reports a Energy diagnostics
- **App Store Connect:** Reviews + Crash rate dashboard

---

## 10. Bezpečnosť & GDPR

### Kam Idú Dáta

| Typ dát | Umiestnenie | Prístup |
|---|---|---|
| Videá | Lokálne (`Documents/Videos/`) | Iba lokálne na iPhone |
| Rutiny, figúry | SwiftData + Supabase (sync) | Iba prihlásený user (RLS) |
| Email / meno | Supabase Auth | Iba user cez vlastný účet |
| Analytika | PostHog EU (Frankfurt) | Anonymizované, žiadna PII |

### GDPR Opatrenia

- PostHog: EU server, `persistence: 'memory'` (žiadne cookies), `autocapture: false`
- **Cookie banner NIE JE potrebný** — žiadne tracking cookies
- **Apple ATT popup NIE JE potrebný** — žiadne cross-app tracking
- Supabase RLS: Každý user vidí iba vlastné záznamy
- Právo na vymazanie: `accountDeleted()` → vymaže auth + všetky záznamy

### Bezpečnostné Pravidlá

```
✅ SUPABASE_ANON_KEY — bezpečný na ship v iOS app (obmedzené RLS práva)
❌ SUPABASE_SERVICE_ROLE_KEY — NIKDY nesmie byť v iOS ani web frontende
✅ Google Client ID v Info.plist — bezpečné (OAuth viazaný na bundle ID)
❌ Secrets.xcconfig — je v .gitignore, nesmie ísť na GitHub
✅ Supabase RLS politiky — každý user vidí iba vlastné dáta
```

### Deep Links & URL Schemes

```
encore://        → interný deep link
encore://     → interný deep link
com.googleusercontent.apps.390349651729-...  → Google OAuth redirect
```

---

*Dokumentácia bola vygenerovaná na základe zdrojového kódu projektu Encore.*  
*Aktualizuj sekciu "Aktuálna verzia" a "Sledované eventy" pri každom release.*
