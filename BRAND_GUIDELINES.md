# 🏛️ Encore Brand Identity & Design System Guide
### *Inšpirované estetikou Ellegance.sk, Apple Human Interface Guidelines a Športovým Luxusom*

Tento dokument definuje oficiálnu vizuálnu identitu, farebnú paletu, typografiu a systém UI komponentov (tlačidiel a kariet figúr) pre aplikáciu **Encore**.

---

## 🎯 0. Produktová Filozofia: „Rob jednu vec 10× lepšie“ (The Core Loop)

> **Zlaté pravidlo Encore:**  
> Aplikácia nesmie byť preplácaná miliónom zbytočných funkcií, ktoré zdržujú. Hlavnou misiou Encore je **zrýchliť progres tanečníka a ušetriť mu drahocenný čas na tréningu.**

### Hlavná slučka používateľa (The Core Loop):
```
[ Zídenie z parketu po figúre / lekcii ]
                 │
                 ▼
[ Otvorenie Encore – max 2 sekundy ]
                 │
                 ▼
[ 1-Tap zaznamenanie: Hlasový diktát poznámky / 15s video / text ]
                 │
                 ▼
[ Automatické priradenie k figúre a tancu bez hľadania v galérii ]
```

### Ako sa to premieta do UI/UX:
1. **Frikcia na nule:** Textové pole a tlačidlo mikrofónu na domovskej obrazovke musia reagovať na prvý dotyk bez zdržiavania dialógmi.
2. **Satelitné funkcie nesmú zavadzať:** Funkcie ako Súťažný radar, Video duel, či Apple Wallet karta sú prémiové "satelity", ktoré sa otvárajú až na vyžiadanie (v radiálnom menu alebo v záložkách), nie uprostred hlavnej cesty zapisovania figúr.
3. **Ergonómia v sále:** Tanečník má často spotené ruky, telefón je na lavičke alebo statíve. Tlačidlá musia mať veľkorysé dotykové plochy (min. 44×44 pt), kontrastné písmo a jednoznačnú haptickú odozvu (`.sensoryFeedback`).

---

## ⭐ 1A. UI štandard celej aplikácie (vzor: obrazovka Domov)

> Schválené 7. 10. 2026. Každá nová alebo upravovaná obrazovka sa riadi touto sekciou. Ak sa staršia časť dokumentu líši (napr. krémové pozadie a biele karty v §2 a §4), pre obrazovky aplikácie platí táto sekcia.

### Povrchy a rozloženie
| Prvok | Pravidlo | V kóde |
| :--- | :--- | :--- |
| Pozadie obrazovky | Karmínový zamat. Pokojné nástroje bez značky (napr. právne texty) obsidián. | `EllegancePageBackground()`, `ElleganceToolBackground()` |
| Karta | Sklo: biela 7 %, lem biela 10 % 1 pt, zaoblenie 16–20 pt | `.homeCard(cornerRadius:)` |
| Okraje | 20 pt zľava aj sprava, medzi sekciami 18–22 pt | `.padding(.horizontal, 20)` |
| Zakázané | Plochá tmavosivá karta, neupravený systémový `Form`, okraje v % šírky | — |

### Typografia
* **Nadpis sekcie:** zlaté VEĽKÉ písmená, SF Rounded Black, tracking 1,4 (napr. „POZNÁMKY", „NAPOSLEDY UPRAVOVANÉ") → `HomeSectionHeader`.
* **Značka:** „ENCORE" sa píše len cez `EncoreWordmark`, na každej obrazovke rovnako.
* **Text:** textové štýly (`.callout`, `.subheadline`, `.footnote`, `.caption`), aby fungovalo zväčšenie písma (Dynamic Type). Pevné `.system(size:)` len pre logo a čísla.
* **Kontrast na zamate:** sekundárny text min. 60 % bielej, placeholder min. 50 %, nič pod 40 %.

### Ovládacie prvky
* **Hlavná akcia:** plné šampanské zlato, čierny text, rohy 16 pt → `PrimarySheetButton`. Neaktívna = to isté tlačidlo stlmené na 40 % a pod ním krátka veta, prečo sa nedá.
* **Prepínač režimov a filtrov:** rad kapsúl, vybraná výplň sa presúva (`matchedGeometryEffect`), zlatý lem 45 %.
* **Výber tanca:** `DanceMenuCapsule` – menu rozdelené na Štandard / Latina, vybraný tanec má bodku vo farbe disciplíny (modrá Štandard, karmínová Latina).
* **Sekundárne a ikonové akcie:** sklenené kruhy 36–44 pt → `.glassEffect(.regular.interactive(), in: .circle)`.
* **Deštruktívne akcie:** text v `latinRed` s ikonou, vždy s potvrdením.
* **Dotyková plocha:** min. 44 × 44 pt.

### Dizajn nesmie rozbiť logiku (pravidlá pre dotyk)
* **Sklo je len obrázok.** V tlačidlách a menu nikdy `.glassEffect(… .interactive())` – sklo by si dotyk bralo samo a tlačidlo by občas nereagovalo. Okrúhle ikonové tlačidlá sa robia len cez `LiquidGlassCircleButton`, štítok menu cez `GlassCircleLabel`.
* **Stlačenie cez `.pressable`.** Zmenšuje len obrázok, dotyková plocha ostáva plná (`contentShape`), takže ťuk pri okraji sa nestratí.
* **Tlačidlo nikdy „nič nespraví".** Keď akcia nemôže prebehnúť, otvorí sa obrazovka s vysvetlením a náhradou (napr. zostava je na QR príliš veľká → textový kód).
* **Ťažká práca nie je v ťuknutí.** Generovanie (QR, export, sieť) beží až v otvorenej obrazovke mimo hlavného vlákna, tlačidlo len otvára.
* **Kľúčové tlačidlá majú `accessibilityIdentifier`** (napr. `canvas.draw`, `canvas.shareQR`), aby ich vedeli stláčať automatické UI testy.

### Mikrointerakcie (povinné na každej obrazovke)
* Každé tlačidlo má `.buttonStyle(.pressable)` – jemné pruženie pri stlačení.
* Pridanie, zmazanie, pripnutie alebo presun položky: `withAnimation(.spring…)` + `.transition` (scale + opacity).
* Uloženie: krátke potvrdenie „Uložené" + `.sensoryFeedback(.success)`.
* Výber a prepnutie: `.sensoryFeedback(.selection)`; meniace sa čísla `contentTransition(.numericText())`, ikony `.symbolEffect` / `.contentTransition(.symbolEffect(.replace))`.
* Písanie: pri fokuse zlaté čiary po okraji poľa (`FieldEdgeSweep`).
* Videá v slučke sa dajú vždy zastaviť (ťuk na video alebo tlačidlo pauzy).
* Vždy rešpektovať `accessibilityReduceMotion`.

### Jazyk a texty
* UI výhradne po slovensky, tykanie („Prihlás sa", „Uložiť poznámku"). Žiadne anglické tlačidlá.
* Dátumy: `.environment(\.locale, Locale(identifier: "sk"))` + `Text(date, format:)` → „7. okt 9:36".
* Slovenské tvary počtu: 1 poznámka, 2–4 poznámky, 0 a 5+ poznámok.
* Jedno slovo = jeden význam („Poznámky" je sekcia, „skopírovaný kód" je obsah schránky iPhonu).

### Prístupnosť
* Ikonové tlačidlá majú `accessibilityLabel`, nadpisy `.isHeader`, vybrané stavy `.isSelected`.
* Chyby sa VoiceOveru oznamujú (`AccessibilityNotification.Announcement`).

### Kde sú spoločné komponenty
* `Encore/HomeSections.swift` – `homeCard`, `HomeSectionHeader`, `DanceMenuCapsule`, `HomeRecentRoutineCard`
* `Encore/PasswordSheets.swift` – `PrimarySheetButton`, `SheetBanner`, `AuthFieldChrome`
* `Encore/LuxuryUIComponents.swift` – `EncoreWordmark`, pozadia
* `Encore/PressableStyle.swift`, `Encore/FieldEdgeSweep.swift`

---

## 👑 1. Oficiálne Logo & Emblém (Sculptural Ribbon Mark)

Oficiálnym symbolom Encore je **Sculptural Ribbon Mark (Variant 3B)**:
* **Koncept:** Spojitá 3D/vektorová stuha zo saténového šampanského zlata na hlbokom matnom obsidiáne (`#080808`).
* **Geometria:** Horná slučka stuhy znázorňuje siluetu štandardného tanečného držania v páre (Standard Dance Frame & Lady's Sway), ktorá plynule prechádza do kaligrafického písmena **„E“** (Encore / Ellegance).
* **Assety v projekte:**
  * `Encore/Assets.xcassets/AppIcon.appiconset/` (1024x1024 Universal, Dark Mode, Tinted Mode).
  * `Encore/Assets.xcassets/EncoreLogo.imageset/` (`encore_logo.png`).
  * `brand_assets/xcode_3d_layers/Encore3D.imagestack/` (4-vrstvový priestorový asset pre Xcode a visionOS).

---

## 🎨 2. Oficiálna Farebná Paleta (Color Tokens)

### A. Primárna Paleta (Core Brand Colors)
* **🖤 Obsidian Black (`#080808` / `#0D0D0E`)**: Hlboká zamatová čierna. Základ pre App Icon, Dynamic Island, nočný režim a karty.
* **🏆 Champagne Gold (`#D4AF37` / `#F3E5AB`)**: Šampanské zlato. Farba úspechu, emblému, finálových bodov a aktívnych stavov.
* **🍦 Silk Ivory / Warm Cream (`#FBF9F5` / `#F5F2EB`)**: Hodvábny krémový podklad. Zabezpečuje príjemný kontrast pre oči pri dlhom štúdiu choreografií v sále.
* **🤍 Pure Card White (`#FFFFFF`)**: Čistá biela pre vyvýšené karty figúr na krémovom pozadí.

### B. Tanečné a Funkčné Akcenty (Discipline & Utility Codes)
* **💃 Latin Crimson (`#E11D48`)**: Vášeň, latinskoamerické tance (Samba, Cha-Cha, Rumba, Paso, Jive), nahrávanie videa (`REC`).
* **👔 Standard Royal Blue (`#1E40AF` / `#3B82F6`)**: Noblesa, štandardné tance (Waltz, Tango, Valčík, Slowfox, Quickstep), trénerské komentáre.
* **🌿 Emerald Sync (`#10B981`)**: Živá synchronizácia, úspešné uloženie, perfektný timing.
* **⚠️ Warning Amber (`#F59E0B`)**: Upozornenia na techniku, držanie rámu, stredný stav batérie.

---

## ✍️ 2. Typografický Systém (Typography Hierarchy)

| Úroveň | Písmo (Font) | Veľkosť & Rez | Použitie |
| :--- | :--- | :--- | :--- |
| **Display Title** | *New York / Playfair / SF Pro Display* | `28–34 pt`, Bold/Black | Názvy tancov, finálové kategórie, titulky obrazoviek |
| **Figure Headline** | *SF Pro Text / Inter* | `17–20 pt`, Bold/Heavy | Názov figúry (napr. *"Natural Spin Turn"*) |
| **Technical Body** | *SF Pro Text* | `14–15 pt`, Regular/Medium | Technický popis nášľapu, rotácie, sklony tela |
| **Badge & Chip** | *SF Pro Rounded* | `11–12 pt`, Heavy, All-Caps | Značky nášľapov (`TH`, `HT`), smer (`LOD`, `DW`) |
| **Timing & Digits** | *SF Mono / SF Pro Rounded* | `14–32 pt`, Heavy Monospace | Metronóm, počítadlo dôb (`1 2 3`), stopky |

---

## 🔘 3. Systém Tlačidiel (Button UI Hierarchy)

### 1. Primárne CTA Tlačidlo (Primary Luxury Button)
* **Vzhľad**: Zamatovo čierne pozadie (`#0D0D0E`) so zlatým textom a ikonou (`#D4AF37`), alebo plné šampanské zlato s čiernym textom.
* **Okraj**: Jemný `1px` svetlejší zlatý lem (`rgba(212, 175, 55, 0.35)`).
* **Tieň**: Mäkký rozptýlený tieň `shadow(color: black.opacity(0.15), radius: 14, y: 5)`.
* **Rohy**: Zaoblenie `16 pt` (moderná elegantná kapsula).
* **Haptika**: `.sensoryFeedback(.impact(weight: .medium), trigger:)`.

### 2. Sekundárne Sklenené Tlačidlo (Frosted Glass Button)
* **Vzhľad**: Priehľadné/biele matné sklo (`.ultraThinMaterial` / `Color.white.opacity(0.85)`).
* **Okraj**: `1px` jemný neutrálny okraj (`#E5E7EB` alebo zlatý odtieň).
* **Použitie**: Filtre, sekundárne akcie, tlačidlo "Upraviť", "Zdieľať zostavu".

### 3. Tanečné Kapsulové Filtre (Discipline Pill Chips)
* **Vzhľad**: Malé 32pt kapsule (`Capsule()`).
* **Stav Aktívny**: Zlaté alebo karmínové pozadie s bielym/čiernym písmom.
* **Stav Neaktívny**: Biela karta s jemným šedým písmom a 1px okrajom.

---

## 🗂️ 4. Systém Kariet Figúr (Figure Card UI Architecture)

Karta figúry je kľúčový element celej aplikácie. Je rozdelená do 4 prehľadných zón:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 💃 WALTZ  •  Figúra #03              [ SQQ ] (Timing)          ↗ LOD (Smer)            │
├────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                        │
│  Natural Spin Turn                                            [ ★★★★★ ] (Mastery)      │
│  Pravá noha vpred, zníženie a silná rotácia 3/8 vpravo.                                │
│                                                                                        │
├────────────────────────────────────────────────────────────────────────────────────────┤
│  [ 🦶 T-H (Pán) ]  [ 🦶 H-T (Dáma) ]  [ 📐 Náklon: Vpravo ]  [ 🎙️ Tréner: 1 poznámka ] │
├────────────────────────────────────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────────┐                            │
│  │ 🎬 Video ukážka: 00:14 (HD)       [ 👁️ Porovnať ]     │                            │
│  └────────────────────────────────────────────────────────┘                            │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### Kľúčové atribúty karty:
1. **Základňa**: Biela karta (`#FFFFFF`) na hodvábnom krémovom pozadí (`#FBF9F5`).
2. **Fazeta**: `1px` prémiový svetlozlatý/sklenený lem (`rgba(212, 175, 55, 0.20)`).
3. **Zaoblenie**: `20 pt` pre maximálnu modernosť a ergonómiu pri scrollovaní.
4. **Hĺbka**: Mäkký ambientný tieň bez tvrdých komiksových obrysov.
