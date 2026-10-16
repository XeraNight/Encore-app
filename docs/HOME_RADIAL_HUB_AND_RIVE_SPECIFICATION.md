# 🌟 Domovský Radiálny Hub & Rive Animácia — Špecifikácia a Návod

> **Dokument:** `docs/HOME_RADIAL_HUB_AND_RIVE_SPECIFICATION.md`  
> **Dátum:** September 2026  
> **Projekt:** Encore iOS  
> **Cieľ:** Transformácia statického loga na domovskej obrazovke na interaktívny radiálny ovládací hub (Radial Satellite Menu), prepojený s inteligentným spodným panelom zostáv a detailným návodom na tvorbu animácie v Rive vs. SwiftUI.

---

## 📑 Obsah
1. [Nová UX Vízia Domovskej Obrazovky](#1-nová-ux-vízia-domovskej-obrazovky)
2. [Pravidlá Zobrazovania Zostáv (Multi-Routine UX)](#2-pravidlá-zobrazovania-zostáv-multi-routine-ux)
3. [Analýza Technológie: SwiftUI Spring vs. Rive (.riv)](#3-analýza-technológie-swiftui-spring-vs-rive-riv)
4. [Detailný Návod: Ako Vytvoriť Animáciu v Rive Krok za Krokom](#4-detailný-návod-ako-vytvoriť-animáciu-v-rive-krok-za-krokom)
5. [Architektúra Kódu v SwiftUI](#5-architektúra-kódu-v-swiftui)

---

## 1. Nová UX Vízia Domovskej Obrazovky

### Pôvodný stav vs. Nový stav
* **Pôvodný stav:** Kliknutie na horné logo otvorilo štandardný celoobrazovkový alebo spodný modal sheet (`LogoCommandPaletteView`), čo pôsobilo ako bežné vyskakovacie okno.
* **Nový koncept (Interactive Radial Hero Hub):**
  1. Logo v strede domovskej obrazovky je dominantným živým prvkom.
  2. Po ťuknutí na logo sa:
     - **Logo plynule zväčší** (scale `1.0 -> 1.18`) so zlatým svetelným pulzom a roztočením vonkajšieho prstenca.
     - **Dookola loga sa radiálne rozvinú 4 satelitné tlačidlá (Radial Actions):**
       - 🌟 **Nová zostava** (Hore-Vľavo, -135°)
       - 🪞 **Mirror / Čisté Zrkadlo** (Hore-Vpravo, -45°)
       - 📋 **Súťažný organizér kôl** (Dole-Vľavo, 135°)
       - 🎞️ **Porovnanie videí** (Dole-Vpravo, 45°; do 16. 10. 2026 tu bola Hudba pomalšie)
     - Pozadie za logom sa jemne stmaví s rozostrením (backdrop blur), aby satelitné možnosti vystúpili do popredia.
  3. Dole pod logom sa jemne a nenásilne vysunie **spodný panel s existujúcimi zostavami (Routines Deck)**.

```
                  ┌───────────────────────────────┐
                  │    [ 🌟 Nová zostava ]        │
                  │            ▲                  │
                  │            │                  │
    [ 📋 Organizér ] ◄─── ( ENCORE ) ───► [ 🪞 Zrkadlo ]
                  │       (  LOGO   )             │
                  │            │                  │
                  │            ▼                  │
                  │    [ 🎞️ Porovnanie ]          │
                  └───────────────────────────────┘
                                  │
                                  ▼
      ┌───────────────────────────────────────────────────────┐
      │  MOJE ZOSTAVY (Najnovšia zostava každého tanca)       │
      │  • Cha-Cha (Súťažná B - aktualizované dnes)      ➔    │
      │  • Quickstep (Kemp 2026 - aktualizované včera)    ➔    │
      │  [ + Rozbaliť staršie zostavy a kategórie tancov... ] │
      └───────────────────────────────────────────────────────┘
```

---

## 2. Pravidlá Zobrazovania Zostáv (Multi-Routine UX)

Tanečníci majú často viacero zostáv pre ten istý tanec (napr. Cha-Cha pre kategóriu C a nová Cha-Cha pre kategóriu B, alebo variácia pre párový tréning a sólo techniku).

### Pravidlá správania:
1. **Predvolený pohľad (Zbalený panel):**
   * Pre každý tanec sa v primárnom zozname zobrazuje **výhradne najnovšia (naposledy upravovaná) zostava**.
   * Tanečník tak hneď na 1 ťuknutie vidí to, čo aktuálne trénuje, bez chaosu a duplicít.
2. **Rozbalený pohľad (Detail tanca):**
   * Ak používateľ rozbalí spodný panel alebo klikne na konkrétny tanec (napr. Cha-Cha):
   * Zobrazí sa kompletná história a zoznam všetkých zostáv daného tanca:
     - *Cha-Cha — Kategória B (Aktuálna súťažná)*
     - *Cha-Cha — Kategória C (Stará zostava)*
     - *Cha-Cha — Sólo variácia na techniku bokov*

---

## 3. Analýza Technológie: SwiftUI Spring vs. Rive (.riv)

| Kritérium | Natívne SwiftUI (Spring + Canvas) | Rive (.riv vektorový runtime) |
|---|---|---|
| **Veľkosť & Závislosti** | 0 KB závislostí, priamo v iOS SDK | Vyžaduje balíček `RiveRuntime` (~4 MB) |
| **Interaktivita tlačidiel** | 100 % natívne SwiftUI Button prvky, VoiceOver, plná haptika | Klikacie zóny sa mapujú cez Rive State Machine |
| **Animácia satelitov** | Matematická trigonometria `cos/sin`, kaskádové oneskorenie | Vytvorená priamo na časovej osi v editore |
| **Zložitosť grafiky** | Škálovanie, rotácia, blur, gradienty, častice | Morfing vektorových kriviek, skeletálna animácia postavy |
| **Rýchlosť nasadenia** | **Okamžite hotové v kóde** | Vyžaduje nakreslenie a rozanimovanie v Rive editore |

### Verdikt a odporúčanie:
* **Ideálna cesta:**
  1. Rozmiestnenie satelitov, vysunutie spodného panelu a logiku tlačidiel implementujeme **v čistom SwiftUI**, pretože to zaručuje okamžitú odozvu, natívne dotykové správanie a perfektnú čitateľnosť.
  2. Ak chceš, aby samotné jadro loga (silueta tanečnice a zlaté prstence) malo komplexnú animáciu (napr. rozvinutie krídel, morphing liniek, rotujúce častice), **Rive je ideálny nástroj na vizuálne jadro loga**.

---

## 4. Detailný Návod: Ako Vytvoriť Animáciu v Rive Krok za Krokom

Ak sa rozhodneš vytvoriť grafiku v [Rive.app](https://rive.app):

### Krok 1: Založenie projektu v Rive
1. Otvor **Rive Editor** a vytvor nový súbor.
2. Nastav **Artboard**:
   - Šírka: `500 px`, Výška: `500 px`.
   - Pozadie (Fill): **Transparent** (vypnuté pozadie, aby neprekrývalo appku).

### Krok 2: Import a príprava vrstiev
Rozdeľ grafiku do logických skupín (Groups):
* `Center_Emblem` — silueta tanečnice a vnútorný tmavý kruh.
* `Gold_Rings` — vonkajšie zlaté oblúky (každý oblúk ako samostatná vektorová cesta `Path`).
* `Glow_Aura` — radiálny gradient svetla za logom.
* `Satellites` — 4 kotevné body (Bones alebo Groups) pre pozície satelitov.

### Krok 3: Vytvorenie animácií na časovej osi (Timelines)
Vytvor 3 samostatné animácie v paneli Animations:

1. **`idle` (Pokojový stav — Loop):**
   * Dĺžka: `2.0 s`, Loop: `Loop`.
   * Zlatý prstenec jemne pulzuje (Scale `1.0 -> 1.03 -> 1.0`).
   * Pomalá rotácia vonkajšieho oblúka o 360°.

2. **`expand` (Rozvinutie pri kliknutí — One-shot):**
   * Dĺžka: `0.6 s`, Loop: `One Shot`.
   * `Center_Emblem`: Scale zväčšenie z `1.0` na `1.18` s krivkou `Cubic Bezier (0.34, 1.56, 0.64, 1.0)` (spring overshoot efekt).
   * `Gold_Rings`: Zrýchlenie rotácie a zväčšenie priemeru.
   * `Glow_Aura`: Opacity z `0.2` na `0.85`.
   * Z prstenca vyletia 4 svetelné lúče smerom na pozície satelitov.

3. **`collapse` (Zatvorenie — One-shot):**
   * Dĺžka: `0.4 s`, Loop: `One Shot`.
   * Plynulý návrat z `1.18` späť na `1.0` s tlmeným dojazdom (`Ease Out`).

### Krok 4: Nastavenie State Machine
V paneli State Machine:
1. Vytvor nový vstup (Input):
   - Typ: **Boolean**, Názov: `isExpanded` (predvolená hodnota: `false`).
2. Prechody medzi stavmi:
   - `Entry` ➔ `idle` (vždy).
   - `idle` ➔ `expand` (podmienka: `isExpanded == true`).
   - `expand` ➔ `collapse` (podmienka: `isExpanded == false`).
   - `collapse` ➔ `idle` (po skončení animácie `collapse`).

### Krok 5: Export a import do iOS
1. Klikni na **File -> Export -> For Runtime (.riv)**.
2. Výsledný súbor pomenuj `encore_logo.riv`.
3. V iOS projekte stačí pridať SPM balíček `https://github.com/rive-app/rive-ios` a použiť:
   ```swift
   RiveViewModel(fileName: "encore_logo", stateMachineName: "State Machine 1")
       .view()
   ```

---

## 5. Architektúra Kódu v SwiftUI

Pre radiálne rozmiestnenie satelitných tlačidiel dookola loga sa používa trigonometria s uhlami:

```swift
// Výpočet polohy satelitného tlačidla na kružnici
func satelliteOffset(angleDegrees: Double, radius: CGFloat, isExpanded: Bool) -> CGSize {
    guard isExpanded else { return .zero }
    let radians = angleDegrees * .pi / 180.0
    return CGSize(
        width: radius * cos(radians),
        height: radius * sin(radians)
    )
}

// Rozmiestnenie 4 akcií:
// 1. Nová zostava:           -135° (vľavo hore)
// 2. Tanečné zrkadlo:        -45°  (vpravo hore)
// 3. Súťažný organizér:       135° (vľavo dole)
// 4. Porovnanie videí:        45°  (vpravo dole)
```

Tento dokument slúži ako kompletný základ pre implementáciu nového interaktívneho domovského prostredia.
