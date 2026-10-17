# Encore – Gemini Guidelines & Architecture Rules

Tento súbor slúži výhradne pre Antigravity (Gemini). Definuje striktné inžinierske zásady, minimalizmus kódu a zabraňuje generovaniu generického "AI balastu". 

---

## 🎯 0. Základný inžiniersky princíp: „Menej kódu je lepšie“ (YAGNI & KISS)

* **Zákaz prebytočného kódu a atrapiek:** Nikdy negeneruj falošné HTML mockupy telefónov, animovaných maskotov, diskotékové svetlá ani zbytočné vizuálne hračky. Ak funkcia nie je reálne potrebná v aplikácii, nepíš ju.
* **The Core Loop:** Každá funkcia a UI prvok musí slúžiť hlavnej produktovej filozofii v [BRAND_GUIDELINES.md](file:///Users/jakub/Documents/Encore/BRAND_GUIDELINES.md) §0:
  * Zídenie z parketu $\to$ Otvorenie Encore do 2 sekúnd $\to$ 1-tap záznam (hlas/video/text) $\to$ Priradenie k figúre.
* **Refaktoring zmazaním:** Najlepší refaktoring je kód, ktorý sa dá bezpečne zmazať alebo nahradiť natívnym riešením platformy.

---

## 🏛️ 1. Dizajnový štandard: §1A z BRAND_GUIDELINES.md

Každá obrazovka na webe aj v iOS aplikácii sa povinne riadi štandardom **§1A**:
* **Povrchy:** Karmínový zamat (`EllegancePageBackground`), pokojné nástroje obsidián. Sklenené karty (biela 7 %, lem biela 10 % 1 pt, polomer 16–20 pt).
* **Typografia:** VEĽKÉ zlaté písmená na nadpisoch sekcií (`HomeSectionHeader`), textové štýly Dynamic Type (`.callout`, `.subheadline`, `.footnote`), žiadne natvrdo nakódené veľkosti fontov.
* **Interakcie:** Každé tlačidlo má `.buttonStyle(.pressable)`, zmena stavu haptiku (`.sensoryFeedback`), žiadne blokovanie dotyku cez nesprávne sklenené efekty (`.glassEffect` nesmie požierať dotyk).
* **Jazyk:** Výhradne prirodzená slovenčina, tykanie, presná tanečná terminológia (parket, krížiky, KSIS, SZTŠ, zostavy, lekcie, samotréning).

---

## 🔒 2. Bezpečnosť a Infraštruktúra (Non-negotiable)

* **Žiadne tajomstvá v kóde ani v gite:** Supabase service-role kľúč patrí výhradne do Edge Functions / serverového prostredia. Anon kľúč je verejný $\to$ RLS (Row Level Security) na každej jednej tabuľke.
* **Databáza:** Nikdy nemeň schému databázy, RLS politiky ani migračné skripty bez toho, aby si najprv používateľovi ukázal presný SQL kód a počkal na schválenie.
* **Žiadne heslá:** Auth session patrí do Keychain storage v Supabase SDK.
* **iOS výkon:**
  * Žiadne ťažké I/O, sieťové volania, audio spracovanie ani Keychain volania na hlavnom vlákne (`@MainActor`).
  * Žiadne force-unwraps (`!`) na dátach od používateľa alebo zo siete.
  * Používaj `Logger` (`Logger+Encore.swift`), nikdy surový `print`.

---

## 🛠️ 3. Spôsob práce (Workflow)

1. **Plán pred kódom:** Ak zmena zasahuje viac ako 2 súbory alebo mení architektúru, najprv napíš stručný plán (outline) a počkaj na schválenie.
2. **Malé kroky & Build:** Po každej úprave over build (`xcodebuild` pre iOS alebo `npm run build` pre web). Nikdy netvrď, že je hotovo, bez overenia buildu.
3. **Nemazať ani nepremenovávať súbory ani targety** bez explicitného schválenia.
4. **Vekslenie medzi nástrojmi:** [CLAUDE.md](file:///Users/jakub/Documents/Encore/CLAUDE.md) patrí Claudeovi, [GEMINI.md](file:///Users/jakub/Documents/Encore/GEMINI.md) patrí Gemini. Nemeň ani neprepísuj pravidlá určené pre Claude.
