# Encore v1: kontrola obrazoviek a funkcií (8. 10. 2026)

Prešiel som tvojich 10 snímok, celé Trénerské štúdio a štýl všetkých obrazoviek v kóde podľa
`BRAND_GUIDELINES.md` §1A (vzor Domov). Zároveň som posúdil, či každá funkcia dáva reálnu hodnotu
od prvého dňa.

**Stačí iPhone? Áno.** Apple iPad nevyžaduje. Appka iba pre iPhone sa na iPade dá stiahnuť
a beží v okne iPhonu s rovnakým rozložením (Guideline 2.4.1: iPhone appky majú na iPade bežať, „ak je to
možné“). Netreba nič programovať, stačí v Xcode nechať iba iPhone (Supported Destinations) a v App Store
Connect vypnúť Mac a Vision Pro.

---

## 1. Opravené hneď (krok 1, build prechádza)

| Problém zo snímky | Príčina | Oprava |
|---|---|---|
| **Výber médií** („Zvoliť pre: Moje video…“): dlaždice sa prekrývajú, fotka je obrovská | Spoločný náhľad `MediaThumbnailView` si nechal veľkosť určiť obrázkom, takže veľká fotka sa vytlačila z dlaždice | Veľkosť určuje dlaždica, obrázok ju len vyplní a orežie. Opravuje to všetky miesta s náhľadmi (výber médií, trezor, porovnanie, strihač). |
| **Duel: „A · Moje“ prečiarknuté video** | Keď video nebolo v telefóne, appka vrátila „náhradnú“ verejnú adresu v Supabase Storage. Úložisko je od bezpečnostnej úpravy súkromné, takže adresa nikdy nefungovala. | Náhrada odstránená. Duel overí, že video ide prehrať, počas hľadania ukáže načítavanie a pri chýbajúcom videu napíše „Video sa nenašlo“ s tlačidlom „Vybrať iné“. |
| **Postúra: „Snímku sa nepodarilo načítať“** | Rovnaká mŕtva adresa; pri fotke vo vzore sa snímka vôbec neposlala | Postúra berie video z ktoréhokoľvek okna, inak fotku. Bez zdroja je tlačidlo neaktívne. Na výšku natočené video už nie je zmenšené na 720 px výšky. |
| Mŕtvy kód „súbor prišiel z cloudu“ | Notifikácia sa už nikdy neodošle | Odstránený z knižnice figúr a detailu tanca. |

🔍 Na iPhone over: duel s tvojím videom a so vzorom, postúra na videu aj na fotke, výber médií.

---

## 2. Najvážnejší problém s hodnotou: Súťažný denník ukazuje vymyslené pravidlá

Tabuľka `advancement_rules` má 5 riadkov s poznámkou **„verify against current SZTŠ rules“** a
„Orientačné pravidlo“ (napr. E → D: 100 b. a 2 finále, D → C až A → S: 200 b. a 5 finále). Appka ich
pritom ukazuje s textom **„Zdroj stavu: Oficiálny KSIS kumulatívny register SZTŠ“**.

Podľa zmien súťažného poriadku SZTŠ na postup treba 5 finále, v triede E sa od roku 2018 počíta každé
finálové umiestnenie, z E do D sa dá prejsť aj bez finále a z A do S treba od roku 2023 v kategórii
Dospelí 120 bodov, nie 200. Čísla v appke teda nesedia. Pravidlo projektu hovorí, že pravidlá súťaží sa
**nikdy neodhadujú**.

**Návrh pre v1 (rozhodni):**
- **A (odporúčam):** do appky dostaneš presné hodnoty z aktuálneho súťažného poriadku, článok 9
  „Výkonnostné zatrieďovanie párov, postupový systém“ (szts.sk → Legislatíva). Ja ich zapíšem aj so zdrojom
  a rokom platnosti.
- **B:** kým ich nemáš, karta ukáže iba čísla z KSIS (body a finále) bez „potrebných“ hraníc a bez
  textu „oficiálny“.

---

## 3. Obrazovky podľa štandardu §1A

✅ = už v štýle Domova · ❌ = starý štýl (pätkové zlaté nadpisy, ploché karty, chýba pruženie a haptika,
pevné veľkosti písma, vykanie)

| Obrazovka | Stav | Čo vidno na snímke / v kóde | Priorita pre v1 |
|---|---|---|---|
| Domov, Poznámky, Plátno (zoznam), Profil, Nastavenia, Prihlásenie, Ako fungujú videá | ✅ | | |
| **Duel (porovnanie videí)** | ✅ 9. 10. (over na iPhone) | Funkčne opravený; ovládanie roztrúsené, „Offset“ v sekundách nie je pre tanečníka zrozumiteľný | **1** (pozri §4) |
| **Postúra (čiary a uhly)** | ✅ 9. 10.: nahradená čiarami v Porovnaní | Anglické „Sway“, uloženie ide len do Fotiek, nie k figúre | **1** (pozri §4) |
| **Výber médií** | ✅ 9. 10. | Filtre s emoji (🎬 📷 🟢 🔴), pätkový nadpis | **1** |
| **Paywall (Členstvo)** | ✅ 9. 10. | Vykanie („Posuňte“, „Vyberte“), sľuby neexistujúcich funkcií, „trénerské štúdio“ v podnadpise | **1** (po rozhodnutí C2) |
| **Knižnica figúr a úprava figúry** („Alemana“) | ✅ 9. 10.: jedna knižnica (Profil aj Domov), hľadanie, filter tanca, skupiny podľa tancov, jeden formulár „Nová figúra“, spoločné sekcie video a fotka | Pätkové nadpisy sekcií, ploché polia, „Schránka instantných poznámok“ (jedno slovo = jeden význam: „Poznámky“) | **2** |
| **Tanečné prepojenia** + pozvánky | ✅ 9. 10. (štýl, tykanie, „ID tanečníka“); C6 nahlásenie je e-mail | Štýl skoro v poriadku; **falošné nahlásenie** (C6) | **2** |
| **Súťažný denník** | ✅ 9. 10. (nový, len čísla z KSIS) | Vymyslené hranice (§2), dlhé texty, „Plný prístup • KSIS Radar súperov“ (Radar neexistuje) | **1** (obsah), **2** (štýl) |
| **Trénerské štúdio** + nástroje | ✅ 9. 10.: Metronóm, Hudba, Moji zverenci. ❌ Strih seminára a Zrkadlo čakajú na novú logiku (§7) | Žiadny nástroj nemá pruženie ani sklenené karty; pätkový veľký nadpis | **2** (§5) |
| Trezor videí, Strih videa | ✅ 9. 10.: „Videá zostavy“ (bez emoji, Ja/Vzor, mazanie s potvrdením, nové videá do Fotiek). Strih videa má zamat, len pevné veľkosti písma | Ploché karty, pevné písmo | **2** |
| Karta člena, Detail a úprava tanca | ✅ 9. 10. (Peňaženka skrytá do Developer účtu; názov tanca sa už nedá premenovať, odpájalo to zostavy) | Pätkové nadpisy | **3** |
| Právne informácie | ✅ 9. 10. štýl a tykanie; obsah C18 ostáva | Obsah (meno prevádzkovateľa, C18); štýl: pre právne texty je povolené pokojné obsidiánové pozadie | **2** (obsah), **3** (štýl) |
| Majiteľská konzola | ❌ | Ukážka s tvojím osobným e-mailom (C16); vidíš ju len ty | **3** |
| Listy na plátne (výber figúr, prechod) | ✅ 9. 10. | Pätkové nadpisy | **2** |

Väčšina týchto obrazoviek používa aj **vykanie**. §1A predpisuje tykanie, takže pri redizajne prepíšem aj texty.

**9. 10. 2026 (druhý prechod podľa snímok z iPhonu):** všetky pätkové nadpisy sú SF Rounded (okrem samotnej
členskej karty), nadpisy navigácie sú biele SF Rounded, dátumy idú podľa slovenčiny (Info.plist `sk`),
Domov: logo sa pri otvorení ukloní (namiesto 3D piruety) a tlačidlá vyjdú po oblúku v smere tanca, ikony
jednotne zlaté na skle. Panel KSIS: výška podľa obsahu, karmínové sklo. Starý štýl ostal len v Strihu
seminára a Zrkadle (čakajú na novú logiku).

---

## 4. Porovnanie a Analýza: návrh v2 (bez AI a bez kreslenia prstom)

**Zmena oproti prvému návrhu (8. 10.):** kreslenie prstom je na mobile nepresné. Preto žiadne voľné
čiary, len pomôcky, ktoré sú vždy presné.

**Cieľ:** za 2 minúty vidieť, čím sa tvoj pohyb líši od vzoru, a uložiť konkrétnu korekciu k figúre.

1. **Prekrytie (najväčšia hodnota):**
   - vzor sa položí priesvitne cez tvoje video,
   - posuvník priehľadnosti, tlačidlo „Zrkadliť vzor“,
   - dvoma prstami zväčšíš alebo posunieš vzor, aby sedel na tvoje telo.

   Rozdiel v tvare a polohe je vidno hneď, bez kreslenia.
2. **Pomocné čiary:**
   - **olovnica**: zvislá čiara, ktorú jedným prstom posunieš k stojnej nohe; hneď vidno, či je hlava
     alebo boky pred ňou alebo za ňou,
   - **vodorovná čiara**: posunieš ju k ramenám; dvoma prstami ju natočíš a appka ukáže sklon,
     napríklad „ramená 6°“,
   - čiary sú vždy dokonale rovné.
3. **Rovnaký moment:** „Zarovnať“ (obe videá na prvý krok figúry), krok po snímke, spomalenie
   0,25–1×, slučka figúry.
4. **Uložiť korekciu:**
   - snímka s čiarami,
   - jeden alebo viac **hotových štítkov** (Telo dozadu, Rám padá, Ľavý lakeť, Hlava, Kolená, Chodidlá,
     Načasovanie),
   - voliteľne hlasová poznámka,
   - uloží sa do poznámok figúry, partner a tréner to uvidia.
5. **Pokojná obrazovka:** zriedkavé nastavenia (rozloženie nad sebou / vedľa seba / prepínanie a výber,
   ktorého videa zvuk počuť) sú v menu ⋯. Na obrazovke ostanú videá, prehrávanie a tri tlačidlá:
   Zarovnať, Prekrytie, Čiary.

**Hotové 9. 10.:** `DualVideoComparisonView` (Porovnanie), `AnalysisGuides.swift` (čiary), `FigureCorrectionSheet.swift`
(korekcia do poznámok figúry), testy `AnalysisToolsTests`. Hlasová poznámka ku korekcii zatiaľ nie je.

Neskôr (v1.1): automatická detekcia postavy (Vision). Až potom môže paywall písať „detekcia“.

## 5. Trénerské štúdio: čo nechať vo v1

**Rozhodnuté 8. 10.:** volá sa **Nástroje** a je v Profile pre všetkých (sekcia TRÉNER so zverencami
len pre trénerov). **Simulátor finále je odstránený.** **Zrkadlo ostáva**: 4K alebo 1080p, 60 snímok za
sekundu, HDR, zosilnenie pri slabom svetle a prisvietenie obrazovkou. Nástroje aj zrkadlo sú v štýle §1A.
Organizér súťažného dňa čaká na rozhodnutie.

| Nástroj | Hodnota od D1 | Návrh |
|---|---|---|
| Trénerský roster zverencov | Vysoká: reálne prepojenia tréner–žiak, poznámky trénera, priradenie figúr | **Nechať**, redizajn |
| Tanečný metronóm (takty za minútu) | Vysoká | **Nechať.** Tempá sú overené podľa Súťažného poriadku SZTŠ 2023, čl. 8 (odkazuje na WDSF); zdroj je v appke aj v `DanceMetronomeEngine.swift` (hotovo 17. 11.). |
| Music Speed & Pitch Trainer | Vysoká: vlastná hudba pomalšie bez zmeny tóniny | **Nechať**, slovenský názov („Hudba pomalšie / rýchlejšie“) |
| Súťažný simulátor finále | Stredná: kondícia 5 tancov s prestávkami | **Nechať**, ak používa tempá z metronómu; dĺžky tancov a prestávok len podľa pravidiel, nie odhadom |
| Camp & Seminar Splitter | Stredná až vysoká: rozstrihanie lekcie na figúry | **Nechať**, ale texty „inteligentný“ a „automatické pomenovanie“ len ak to naozaj robí |
| Čisté tanečné zrkadlo | Nízka: predná kamera iPhonu to vie tiež | **Vyradiť z v1** alebo presunúť ako režim do Kamery |
| Súťažný organizér kôl | Nízka bez dát zo súťaže (ručné prepisovanie čísel a heatov) | **Vyradiť z v1**, vrátiť sa s dátami z KSIS |
| AirPlay „Studio TV“ | Stredná: zostava na veľkej obrazovke v sále | Nechať pri plátne, premenovať bez slova „Studio“ |

Názov „Trénerské štúdio“ aj podnadpis „TRÉNERSKÉ & SÚŤAŽNÉ ŠTÚDIO“ zvyšuje dojem skupinového plánu. Návrh:
**„Nástroje“** s dvoma skupinami: TRÉNER (roster) a TRÉNING (metronóm, hudba, finále, strihač).

---

## 6. Poradie práce (každý krok build, testy a tvoja kontrola na iPhone)

1. ✅ Opravy chýb (§1).
2. ✅ 9. 10. **Duel + Postúra podľa §4** (výber médií ešte čaká).
3. **Súťažný denník:** hranice podľa §2 (potrebujem tvoje rozhodnutie A alebo B) a obsah karty.
4. **Paywall:** texty podľa rozhodnutia C2, tykanie, štýl, limity zdieľaných videí.
5. **Nástroje (Trénerské štúdio)** podľa §5: vyradenie, premenovanie, redizajn ponechaných.
6. Priorita 2: knižnica figúr a úprava figúry, prepojenia (+ skutočné nahlásenie), trezor a strih, listy
   na plátne, obsah právnych textov.
7. Priorita 3: karta člena, tanec, štýl právnych textov, konzola.

## 7. Potrebujem od teba
1. Súhlasíš s logikou Duelu a Korekcie (§4)?
2. Súťažný denník: A (pošleš hodnoty zo súťažného poriadku) alebo B (iba čísla z KSIS)?
3. Nástroje: súhlasíš s vyradením Zrkadla a Organizéra kôl z v1 a s názvom „Nástroje“?
4. Rozhodnutia z `docs/V1_LAUNCH_CHECKLIST.md` (paywall, Peňaženka, obrázky, e-mail, vek, iOS).

## Zdroje
- [Apple App Review Guidelines (2.4.1 Hardware compatibility, 2.3.1, 3.1.2)](https://developer.apple.com/app-store/review/guidelines/)
- [SZTŠ: Súťažný poriadok 2023, sekcia TŠ](https://szts.sk/wp-content/uploads/2023/09/20221219_sutazny-poriadok-2023-sekcie-ts.pdf)
- [SZTŠ: Súťažný poriadok 2022 (výkonnostné triedy)](https://archiv.szts.sk/files/documents/legislativa/20220123_sutazny-poriadok-2022-sekcia-tanecny-sport.pdf)
- [SZTŠ: Zmeny SP 2016 (5 finále)](https://archiv.szts.sk/files/documents/sutazny_usek/20151205_zmeny-sp-szts-2016.pdf)
- [SZTŠ: Zmeny SP 2018 (trieda E)](https://archiv.szts.sk/files/documents/sutazny_usek/20180131_zmeny-sp-szts-2018.pdf)
- [SZTŠ: Zmeny SP 2023 (A → S 120 bodov)](https://szts.sk/wp-content/uploads/2023/09/20230109_zmeny-sp.pdf)
- [SZTŠ: Kvalifikačný poriadok TŠ 2025](https://szts.sk/wp-content/uploads/2024/12/Kvalifikacny-poriadok-TS-2025_web.pdf)
