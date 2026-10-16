# Encore v1: čo zostáva do kompletnej appky (9. 10. 2026)

Jeden prehľad. Podrobnosti sú v dokumentoch v zátvorkách. Poradie v každej časti je odporúčané poradie práce.

## 0. Najprv: uložiť prácu do gitu
Od posledného commitu je zmenených alebo nových **vyše 60 súborov** (Fotky, Cloudflare R2, Free/Plus/Premium, Nástroje,
zrkadlo, KSIS čítačky, dokumenty). Nič z toho nie je v gite. Navrhujem rozdeliť to na menšie commity podľa
tém. Pripravím ich, ty ich schváliš.

## 1. Teraz, bez Developer účtu

### Funkcie (`docs/V1_PAYWALL_FEATURES_PLAN.md`)
| # | Funkcia | Plán | Čo treba od teba |
|---|---|---|---|
| 1 | ✅ 9. 10. **Analýza a korekcie:** prekrytie so vzorom, olovnica, vodorovná čiara so sklonom, korekcia so štítkami k figúre (`docs/V1_UI_FEATURE_REVIEW.md` §4) | Premium | OK na logiku §4 |
| 2 | ✅ 9. 10. (over na iPhone) **KSIS zadarmo:** prehliadač KSIS v appke, prepojenie páru, história, výsledok a krížiky z otvorenej stránky, „naživo, keď sa pozeráš“; nový Súťažný denník len s číslami z KSIS (`docs/KSIS_SAMPLES_NEEDED.md`) | Free | Vyskúšať s vlastným párom |
| 3 | ✅ 9. 10. **Top 3 priority po lekcii** (reflexia v Pláne, Domov, Plán) | Plus | Vyskúšať |
| 4 | ✅ kód 9. 10. **Tréner: „Čo sme robili naposledy“**; poznámky trénera žiak nezmaže už od 7. 10. (spúšťač v databáze) | Premium | Spustiť SQL `20261009_coach_lessons_and_guest_keys.sql` |
| 5 | ✅ kód 9. 10. **Kľúč pre hosťujúceho trénera** (Free 1 kľúč na 7 dní, Plus neobmedzene a až 30 dní) | Free/Plus | Spustiť to isté SQL |
| 6 | **Alternatívne ikony appky** | Plus | Návrhy ikon |
| 7 | **Parket Optima (Košice)** | Plus | Presné rozmery sály |

### Redizajn podľa §1A (`docs/V1_UI_FEATURE_REVIEW.md` §3)
- **Priorita 1:** ✅ všetko hotové 9. 10.: Duel a Postúra (Porovnanie), výber médií, paywall (len hotové funkcie), Súťažný denník, zoznam zverencov. Prihlásenie bolo hotové už 8. 10.
- **Priorita 2:**
  - knižnica a úprava figúry,
  - tanečné prepojenia,
  - Nástroje,
  - trezor a strih videa,
  - listy na plátne,
  - obsah právnych textov.
- **Priorita 3:** karta člena, tanec, štýl právnych textov, majiteľská konzola.
- Všade **tykanie** namiesto vykania.

### Opravy pred odoslaním (`docs/V1_LAUNCH_CHECKLIST.md` C)
| # | Čo | Kto |
|---|---|---|
| C11 | Overiť hudbu a metronóm pri zamknutom telefóne, inak režim audio na pozadí vypnúť | ty na iPhone, potom ja |
| C1, C15 | Len iPhone a iOS 26.0 v Xcode | ty |
| C10 | Obrázky pozadia a parketu: licencia alebo náhrada kódom | ty (zdroj) / ja |
| C12 | E-maily pri registrácii (SMTP, napr. Resend) | ty (doména), ja (nastavenie) |
| C7 | Stránka `/add` pre QR pozvánky | web (Antigravity) |
| C19 | Vek 16+ alebo s rodičom | ty (po konzultácii) |

### Web a právne (`docs/V1_LAUNCH_CHECKLIST.md` D)
- **Doména:** treba ju pre zásady, podmienky, stránku podpory, e-maily (C12) a QR odkazy (C7).
- **Zásady ochrany súkromia, podmienky (EULA) a stránka podpory** na verejných adresách (D1–D4).
- **Záznamy o spracúvaní** (D5) a ideálne kontrola právnikom (D8).

## 2. Po kúpe Developer účtu
- **Prihlásenie cez Apple** a zrušenie tokenu pri zmazaní účtu (C3, C4).
- **Overenie nákupov na serveri** + App Store Server Notifications (C5). Bez toho si ktokoľvek zapne
  Premium.
- **Peňaženka:** karta člena (C8), neskôr motívy karty.
- **App Store Connect:**
  - texty a snímky obrazovky,
  - predplatné,
  - vekové hodnotenie,
  - štítky súkromia,
  - 2 demo účty pre review.
- **TestFlight:** celý zoznam testov (`docs/V1_LAUNCH_CHECKLIST.md` F).

## 3. Po odpovedi SZTŠ (`docs/KSIS_SZTS_EMAIL.md`)
- Serverové sledovanie: ranná obnova, súťaže z prihlášok samy v Pláne.
- Upozornenie na zamknutej obrazovke pri postupe z kola, Live Activity. Potrebuje aj Developer účet.
- KSIS Radar (Premium).

## 4. Verzia 1.1
- Apple Watch (`docs/WATCHOS_V1_1_PLAN.md`).
- Poznámky a Plán aj na server (dnes len v telefóne).

### Odložené: tréner a zdieľané videá (rozhodnuté 16. 10. 2026)
v1 je pre tanečníka a jeho partnera. Kód, tabuľky aj serverové funkcie ostali, vypína ich `Encore/AppFeatures.swift`:
- `coachTools`: rola Tréner pri registrácii a v Nastaveniach, karty Tréneri a Zverenci, „Moji zverenci“,
  zápis lekcií („čo sme robili naposledy“), poznámky trénera pri figúre, kľúče pre hosťujúcich trénerov a Požičané zostavy.
- `sharedVideos`: „Zdieľať s partnerom a trénerom“ pri videu figúry (kópia 720p na Cloudflare R2). Videá ostávajú vo Fotkách.

Ostáva: partner (pozvánka cez QR na kartičke, spoločné zostavy a poznámky naživo), QR zostavy, záloha zostáv v cloude.

Zapnutie (vždy novou verziou cez App Review, nikdy zo servera, pravidlo 2.3.1):
1. Najprv Supabase Pro (denné zálohy, žiadne pozastavenie projektu).
2. Prepínač v `AppFeatures.swift` na `true`. Paywall a texty v appke sa prispôsobia samy.
3. Web ručne: cenník a FAQ (`web/src/lib/site.ts`), záložka Tréner (`AudienceTabs.tsx`), opisy pre trénerov,
   Cloudflare ako úložisko videí v `privacy/page.tsx`.
4. App Store: popis, popisy predplatného, štítky súkromia (zdieľané videá), poznámky pre review.

## Hotové a overené (9. 10.)
- C9, C13, C14 opravené, C20 už v appke bolo (`docs/V1_LAUNCH_CHECKLIST.md`). Na tebe: spustiť SQL `20261009_app_config.sql`.
- Export „Stiahnuť moje dáta“ vrátane zdieľaných videí je nasadený.
- Premenovanie stĺpcov KSIS (`stt_last_change`, `lat_last_change`) je nasadené.
- Čítanie stránok KSIS + 15 testov; serverová funkcia `ksis-page` nasadená, staré `ksis-import`, `ksis-manage-*` zmazané.
- Paywall a popisy plánov sľubujú len hotové funkcie (C2, C22).
- iOS testy: 58 z 58.
