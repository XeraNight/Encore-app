# Canvas (zostavy a parket): audit kódu a UI/UX

> 15. 10. 2026. Prejdené: `CanvasRoutinesHubView`, `RoutineCanvasView`, `CanvasLayersAndCards`,
> `CanvasOverlaysAndSheets`, `CanvasFloatingControls`, `CanvasRealtimeManager` (posielanie),
> `FigureDetailCard`, `AssignFigureSheetView`, `StudentRoutineDetailView`. Build prechádza.
> Naživo v simulátore sa nedalo skúšať (appka chce prihlásenie), všetko je overené čítaním kódu.

## 1. Čo v canvase vieš robiť

**Moje zostavy:** nová zostava (tanec), hľadanie, filter Štandard / Latina, otvoriť parket, premenovať, zdieľať QR, zmazať (s potvrdením, zmažú sa aj videá figúr uložené v Encore).

**Parket:**
- posúvanie a priblíženie, „Vycentrovať figúry“, parket na šírku aj na výšku, displej nezhasne;
- **+ Figúra** z knižnice daného tanca, alebo rovno nová figúra;
- presúvanie figúr (prichytia sa k mriežke a neprejdú cez stenu), ťuk = detail, podržanie = Otvoriť / Vymazať, 5 s na „Vrátiť“;
- ťuk na názov zostavy = premenovať; ⋯ → Poradie figúr (presunieš ťahaním);
- čísla poradia a čiary medzi figúrami, ťuk na šípku = poznámka k prechodu (ukladá sa sama);
- Zobrazenie: veľkosť kariet (70 / 100 / 120 %) a priesvitné karty;
- kreslenie po parkete (ceruzka, zmazať kresbu);
- AirPlay na TV v sále;
- spolupráca naživo: kurzor partnera, figúra zamknutá, kým ju ťahá partner, oznámenia „Partner pridal / upravil…“, štítok Naživo / Offline (ťuk = obnoviť alebo pripojiť);
- ⋯ menu: Duel videí, Videá a fotky zostavy, Hosťujúci tréner; QR zdieľanie hore;
- Live Activity s aktuálnou a ďalšou figúrou.

**Detail figúry:** ťuk na názov = názov a rytmus figúry len v tejto zostave; video (spustí sa stlmené, hudba v sále hrá ďalej; reproduktor zapne zvuk a so zvukom hrá ďalej v mini prehrávači nad tab barom, na zamknutej obrazovke a v Dynamic Island; natočiť s „duchom“ vzoru, z Fotiek, otočiť, zväčšiť ťahaním, slučka, ťuk = pauza), zdieľanie videa s partnerom a trénerom, porovnanie so vzorom a korekcie rovno do poznámok, formátované poznámky s automatickým ukladaním, poznámka od trénera, poznámky hosťujúceho trénera.

## 2. Nálezy

### 🔴 Chyby
| # | Problém | Dôsledok |
|---|---|---|
| C1 | Šípky „SMER TANCA“ na stenách idú **v smere hodinových ručičiek** (ľavá stena hore, horná doprava…). Línia tanca ide okolo sály **proti** smeru hodinových ručičiek. | Parket učí opačný smer. *Prosím potvrď ako tanečník.* |
| C2 | **Export do PDF** je naprogramovaný, ale žiadne tlačidlo ho neotvorí. | Funkcia je skrytá. |
| C3 | **Kresba sa neukladá**: po odchode z parketu zmizne a partner ju nikdy nevidí. | Strata práce. |
| C4 | Pri zmazaní figúry sa poradie prečísluje zo zoznamu, v ktorom môže byť ešte zmazaná figúra. | Môže vzniknúť diera v číslovaní (1, 2, 4). |
| C5 | Po každom presunutí figúry sa zostava **uloží a odošle na server dvakrát** (karta aj parket). | Zbytočná sieť a batéria. |
| C6 | Pri ťahaní figúry partnerom sa telefón **ukladá pri každej správe** (~10× za sekundu). | Zaťaženie a batéria. |
| C7 | Kurzor partnera ignoruje okraje parketu: pri priblížení na kraj je posunutý. | Kurzor „uletí“. |
| C8 | Otvorenie figúry s videom **zastaví hudbu v sále** (Spotify) a video hrá so zvukom. | Na tréningu otravné. |

### 🟠 Chýbajúce funkcie
| # | Čo chýba |
|---|---|
| F1 | **Premenovať zostavu** (názov sa dá zadať len pri vytvorení). |
| F2 | **Zmeniť poradie figúr** alebo vložiť figúru medzi dve existujúce. Teraz poradie = poradie pridania. |
| F3 | Upraviť názov alebo rytmus figúry v tejto zostave (napr. „Natural Turn (skrátený)“, iné doby). |
| F4 | **Vrátiť** zmazanie figúry (krátka lišta „Figúra zmazaná · Vrátiť“). |
| F5 | Kresba: vrátiť posledný ťah, 2–3 farby. |

### 🟡 UI/UX podľa §1A
| # | Problém |
|---|---|
| U1 | Prázdny parket: stará karta (themeCard, pevné písmo) a text „Ťukni na ‚Pridať figúru‘“, hoci tlačidlo je „+ Figúra“. |
| U2 | Šípka prechodu je pri oddialení malá (8–20 pt), takmer sa nedá trafiť. Treba aspoň 44 pt bez ohľadu na priblíženie. |
| U3 | Pri veľkosti kariet 70 % / 120 % sa dotyková plocha nemení s kartou. |
| U4 | Štítok Naživo / Offline má dotykovú plochu len 28 pt. |
| U5 | Trénerské obrazovky (Priradiť figúru, zostava zverenca) majú pevné veľkosti písma, nie textové štýly. |
| U6 | Hlavička detailu figúry: „Zavrieť“ s pevnou veľkosťou písma. |

### ⚪ Kód
| # | Problém |
|---|---|
| K1 | Mŕtvy kód: `MinimapView`, `isCanvasLocked` (nikdy sa nezapne), `getDocumentsDirectory()`, zdvojené skrývanie navigácie. |
| K2 | Zmazanie zostavy nechá videá jej figúr v telefóne (zaberajú miesto). |
| K3 | Live Activity loguje pod kategóriou „camera“. |

## 3. Plán opráv (každý krok samostatne, build po každom)
1. **Chyby C1–C8** a mŕtvy kód K1, K3. Pri C8: video sa spustí stlmené a hudba v sále hrá ďalej, zvuk zapneš ťukom na reproduktor.
2. **PDF export** do ⋯ menu (C2).
3. **Premenovať zostavu** (F1): ťuk na názov v hornej lište → okno s názvom.
4. **Poradie figúr** (F2): v ⋯ menu „Poradie figúr“ → zoznam, ktorý presunieš ťahaním; čísla aj čiary sa hneď prekreslia.
5. **Vrátiť zmazanie** (F4) a **upraviť figúru v zostave** (F3).
6. **Kresba** (C3, F5): uloženie k zostave v telefóne, vrátiť ťah, farby. Zdieľanie kresby s partnerom potrebuje nový stĺpec v databáze (SQL ukážem zvlášť).
7. **UI** U1–U6 a uvoľnenie miesta po zmazaní zostavy (K2).

## 4. Stav (15. 10. 2026)
**Hotové:** C1 (proti smeru hodinových ručičiek), C4–C8, F1–F4, U1–U6, K1–K3.
Mini prehrávač nad tab barom je od iOS 26.1; na iOS 26.0 sa video so zvukom po zatvorení figúry zastaví.

**C2:** PDF export zmazaný (16. 10. 2026, nikto ho nepotreboval).

**Čaká na rozhodnutie:**
- C3, F5: kresba po parkete sa neukladá. Zmazať kreslenie, alebo ho dorobiť (uloženie, vrátiť ťah, farby; zdieľanie s partnerom potrebuje nový stĺpec v databáze)?

Overené buildom a testami; naživo v simulátore to bez prihlásenia skúsiť nejde.
