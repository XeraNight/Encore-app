# Funkcie z paywallu, ktoré dorobíme (rozhodnuté 8. 10. 2026)

## Rozdelenie plánov (rozhodnuté 16. 10. 2026)
v1 bez trénera a zdieľaných videí (`docs/V1_REMAINING_WORK.md` §4). Logika: **Free** = trénuješ s partnerom
každý deň, **Plus** = vieš, na čom pracovať (lekcia → súťaž), **Premium** = každý detail vo videu.
KSIS údaje ostávajú zadarmo; platí sa za analýzu a pohodlie, nie za údaje (SZTŠ, App Review, recenzie).

| | Free | Plus | Premium |
|---|---|---|---|
| Zostavy a parket | 1 na tanec | neobmedzené | ✓ |
| Partner naživo, QR zostavy, poznámky, diktovanie | ✓ | ✓ | ✓ |
| Kalendár, reflexia, týždeň v číslach | ✓ | + **vývoj za mesiac a sezónu** ✱ | ✓ |
| Top 3 priority po lekcii | – | ✓ | ✓ |
| KSIS: výsledky, body, krížiky, história | ✓ | ✓ | ✓ |
| **Moja sezóna** (krížiky podľa tancov, vývoj, finále) ✱ | – | ✓ | ✓ |
| **Súťažný deň** (tance v poradí, pri každom Top 3) ✱ | – | ✓ | ✓ |
| Zrkadlo, metronóm | ✓ | ✓ | ✓ |
| Hudba pomalšie, strih lekcie na figúry | – | ✓ (presun z Free) | ✓ |
| Natočiť s duchom, duel vedľa seba | ✓ | ✓ | ✓ |
| Porovnanie so vzorom, čiary, korekcie | – | – | ✓ |
| **Časová os figúry** ✱ | – | – | ✓ |

✱ dorobiť pred vydaním. Poradie: presun Hudba pomalšie a Strih lekcie do Plus → Moja sezóna → Súťažný deň →
vývoj v Kalendári → Časová os figúry. Každá funkcia sa v paywalli ukáže až hotová a otestovaná.

Paywall smie sľubovať len to, čo funguje (App Review 2.3.1 a 3.1.2). Preto každá funkcia ide do
paywallu až keď je hotová a otestovaná. Dovtedy sa riadok v paywalli nezobrazuje.

| # | Funkcia (plán) | Čo presne robí | Závisí od | Náročnosť |
|---|---|---|---|---|
| 1 | ✅ 9. 10. Free: prehliadač KSIS v appke **KSIS prepojenie a denník** (automatika neskôr v Plus) | Prepojenie menom, trieda, body a finále z KSIS, história a krížiky automaticky (`docs/KSIS_AUTO_CONNECT_PLAN.md`) | SQL (hotové), čítanie stránok (hotové), **povolenie od SZTŠ / KSIS: server je zablokovaný** (`docs/KSIS_SAMPLES_NEEDED.md` §1); bez neho len import z otvorenej stránky | veľká |
| 2 | ✅ 9. 10. (over na iPhone) **Analýza a korekcie** (Premium) | Prekrytie so vzorom, olovnica, vodorovná čiara so sklonom, uloženie korekcie so štítkami k figúre (`docs/V1_UI_FEATURE_REVIEW.md` §4) | nič | stredná |
| 3 | ✅ 9. 10. **Top 3 priority po lekcii** (Plus) | Po tréningu zapíšeš 3 hlavné korekcie trénera pre tanec (text alebo hlas). Ukazujú sa na Domove a v Pláne, kým ich neodškrtneš. | nič (Plán a poznámky už sú) | stredná |
| 4 | ✅ kód 9. 10., čaká na SQL **Tréner: „Čo sme robili naposledy“ + ochrana poznámok** (Premium; ochrana poznámok platí od 7. 10.) | Pri každom žiakovi posledná lekcia a poznámka; poznámky trénera žiak nemôže zmazať (kontrola na serveri) | SQL | stredná |
| 5 | **KSIS Radar** (Premium) | Sleduješ iné páry (súperov, kamarátov) a appka ukáže ich nové výsledky a zmeny tried; upozornenie na zamknutej obrazovke | funkcia 1 + Developer účet (push) | veľká |
| 6 | ✅ kód 9. 10., čaká na SQL **Kľúč pre hosťujúceho trénera** (Free 1 kľúč / 7 dní, Plus neobmedzene / 30 dní) | Odkaz alebo QR, cez ktorý trénerovi na seminári dočasne sprístupníš jednu zostavu; môže pridať poznámky, nevidí poznámky iných trénerov; po 7 dňoch sa sám zruší | SQL + serverová funkcia; náhodný, krátkodobý, zrušiteľný kľúč (pravidlá projektu) | veľká |
| 7 | **Vzhľad: ikony appky a motívy karty** (Plus) | Alternatívne ikony appky a farebné motívy karty v Peňaženke | navrhnuté ikony; Peňaženka po Developer účte | malá až stredná |
| 8 | **Parket Optima (Košice)** | Plán skutočnej sály na plátne | **presné rozmery sály** (nesmú sa odhadnúť) | malá, keď budú rozmery |

## Návrh: KSIS zadarmo, automatika platená (9. 10. 2026, čaká na rozhodnutie)

Platí sa za službu (automatika, upozornenia, menej hľadania), nie za verejné údaje.

| Plán | Čo dostane | Potrebuje |
|---|---|---|
| **Free** | Prepojenie páru; trieda, body a finále; história s umiestnením; krížiky od porotcov po kolách; v deň súťaže „naživo, keď sa pozeráš“ (obnovíš potiahnutím) | Nič, funguje aj bez povolenia KSIS |
| **Plus** | Upozornenie na zamknutej obrazovke pri postupe a výsledku, Live Activity, súťaže z prihlášok samy v Pláne a kalendári, ranná obnova bez otvárania appky | Povolenie SZTŠ / KSIS + Developer účet (push) |
| **Premium** | KSIS Radar: nové výsledky iných párov | Ako Plus |

Prečo:
- **SZTŠ skôr povie áno**, keď samotné údaje zostanú zadarmo. Platená automatika ich povolenie potrebuje
  aj tak.
- **Najsilnejší dôvod stiahnuť si appku:** každý tanečník chce vidieť svoje body. Zadarmo to prinesie
  najviac ľudí, ktorí potom môžu prejsť na Plus.
- **Je to férové:** používateľ platí za to, že mu všetko príde samo, na jednom mieste a bez prechádzania
  stránok.

## Návrh: prečo prejsť na Plus a Premium (9. 10. 2026, čaká na rozhodnutie)

Free ostáva štedrý (poznámky, KSIS prehľad, zdieľanie s partnerom). Za peniaze dostaneš to, čo **šetrí
čas a ukazuje pokrok**, nie to, čo ti Free zoberie.

**Nové nápady (neboli v pôvodnom pláne):**

| Funkcia | Plán | Čo robí | Prečo to ľudia chcú |
|---|---|---|---|
| **Moja sezóna** | Plus | Z tvojich výsledkov v KSIS: koľko krížikov dostávaš v ktorom tanci (napr. quickstep 58 %, waltz 86 %), vývoj krížikov a umiestnení v čase, finále. Karta sezóny na zdieľanie do Instagramu. | Hneď vidíš, na ktorom tanci pracovať. Zdieľaná karta privedie ďalších tanečníkov. Je to tvoja analýza, nie predaj údajov KSIS. Hodnotíme tance, nie porotcov. |
| **Súťažný režim** | Plus | V deň súťaže jedna obrazovka: tance v poradí a pri každom tvoje Top 3 priority od trénera. Pred kolom si ich prečítaš za 10 sekúnd. Neskôr aj Live Activity. | Spája lekcie so súťažou. Nič také inde nie je. Funguje aj bez KSIS. |
| **Časová os figúry** | Premium | Všetky videá jednej figúry podľa dátumu, porovnanie „pred 3 mesiacmi a dnes“ jedným ťuknutím. | Pokrok je vidno. To motivuje viac než čokoľvek iné. |

**Čo už v pláne je** (funkcie 1–7 vyššie): Top 3 priority, kľúč pre trénera, analýza a korekcie, tréner
„čo sme robili naposledy“, Radar, ikony, viac miesta na zdieľané videá.

**Ako zvýšiť počet platiacich (nie funkcie):**
- **Skúšobná doba zadarmo** (napr. 7 dní na Plus aj Premium, nastavuje sa v App Store Connect).
  Najsilnejší spôsob, ako presvedčiť ľudí, ktorí nechcú platiť naslepo.
- **Ročná cena viditeľne** (Plus 49,99 € = 4,17 € mesačne).
- **Ponuka v správnej chvíli:**
  - pri druhej zostave na tanec,
  - po súťaži („Tvoja sezóna je pripravená“ s rozmazaným náhľadom),
  - pri prvom zdieľaní, keď sa minie 1 GB.

  Nie náhodné vyskakovanie.
- **Kódy pre kluby** (Offer Codes po kúpe Developer účtu): tréner dá svojim párom mesiac Plus zadarmo.

**Čo nerobiť:**
- zamknúť poznámky alebo zobrať niečo, čo Free už má,
- predávať samotné údaje z KSIS,
- robiť štatistiky jednotlivých porotcov (SZTŠ sme sľúbili, že nebudeme profilovať).

## Návrh: kľúč pre hosťujúceho trénera (9. 10. 2026)
- **Free:** 1 aktívny kľúč naraz, platí 7 dní.
- **Plus:** neobmedzene kľúčov naraz a platnosť až 30 dní.

Prečo nie celé v Plus:
- **Každý kľúč privedie trénera do appky.** Na seminári ho uvidí celá skupina, a jeden tréner ovplyvní
  desiatky párov.
- **Poznámky trénera ostanú u tanečníka**, takže appku neopustí.

Prečo nie celé zadarmo: kto chodí na viac seminárov a k viacerým trénerom, ten je presne zákazník Plus.

**Odporúčané poradie:** 1 → 2 → 3 → 4 → (Developer účet) → 5 → 6 → 7 → 8.

**Už funguje:** neobmedzené zostavy, kalendár so synchronizáciou do Apple Kalendára, Video Duel,
zdieľanie videí s limitmi 1 / 10 / 50 GB.

**Pri spustení:** ak niektorá funkcia ešte nebude hotová, paywall ju nespomenie. Vyhneš sa zamietnutiu
a nesľubuješ ľuďom niečo, čo nedostanú.
