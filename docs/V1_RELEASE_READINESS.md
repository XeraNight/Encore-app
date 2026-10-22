# Encore v1: pripravenosť na App Store (22. 10. 2026)

Predplatné a Apple review, snímky obrazovky pre App Store a web, audit funkcií podľa typu tanečníka.
✅ hotové v kóde (overené) · 👤 úloha pre teba · ❓ rozhodnúť

---

## 1. Predplatné: funguje a dá sa poslať na review?

**V kóde je hotové:**
- ✅ StoreKit 2: 4 produkty (Plus a Premium, mesačne a ročne), nákup s ID účtu (`appAccountToken`), podpis Apple sa overuje v iPhone.
- ✅ Obnova nákupov, sledovanie zmien (vrátené peniaze, predĺženie), posledný overený stav aj offline.
- ✅ Paywall:
  - ceny len z App Store v mene zákazníka (od 22. 10.);
  - text o automatickom obnovení a zrušení v Nastaveniach;
  - Podmienky používania a Ochrana súkromia.
- ✅ Bezpečnosť: zapísať si Premium cez API už nejde (opravené 22. 10.). Platené predplatné overuje iPhone a server berie do úvahy len darovanie od majiteľa.
- ✅ Prihlásenie cez Apple popri Google (pravidlo 4.8) a zmazanie účtu v appke (5.1.1(v)).
- ✅ Blokovanie používateľov (1.2) a šifrovanie deklarované v Info.plist (`ITSAppUsesNonExemptEncryption = false`, používame len štandardné HTTPS).

**Kam idú peniaze:** Apple vypláca na bankový účet, ktorý nastavíš v App Store Connect → Business (Agreements, Tax, and
Banking). Bez aktívnej zmluvy **Paid Apps Agreement**, bankového účtu a daňového formulára sa predplatné nedá predávať.

**👤 Čo treba spraviť v App Store Connect:**
1. **Business:** podpísať Paid Apps Agreement, zadať bankový účet a daňové údaje (pre fyzickú osobu na Slovensku formulár W-8BEN).
2. **Small Business Program:** prihlásiť sa. Pri tržbách do 1 milióna dolárov ročne si Apple vezme 15 % namiesto 30 %, aj z predplatného v prvom roku.
3. **Predplatné:**
   - skupina „Encore“ a 4 produkty s presne tými ID, ktoré má appka (`ProductID.all` v `SubscriptionModels.swift`);
   - slovenský popis a ceny;
   - ku každému produktu snímka paywallu pre recenzenta.
4. **Prvé predplatné sa posiela spolu s verziou appky** (zaškrtnúť ho pri odoslaní verzie).
5. **Povinné odkazy:**
   - URL ochrany súkromia a URL podpory (web);
   - podmienky (štandardná zmluva Apple EULA alebo vlastná);
   - support e-mail `support@encore-sk.com`: pošli naň skúšobný mail a over, že chodí.
6. **App Privacy:** zbierané údaje sú e-mail, meno, používateľský obsah (zostavy, poznámky), identifikátor účtu a nákupy. Žiadne sledovanie (tracking).
7. **Informácie pre recenzenta:**
   - **testovací účet s heslom** (bez neho review neprejde);
   - poznámka, že konzola majiteľa je skrytá a vidí ju len majiteľ (2.5.19).
8. **Pred odoslaním:** nákup otestovať cez TestFlight s testovacím (sandbox) účtom.
9. ❓ Rodinné zdieľanie predplatného zapnúť alebo nie.

**Nová dohoda Apple (Developer Program License Agreement, prečítaná 22. 10.):**
- Hlavná novinka pre nás je **Príloha 14 pre EÚ** (platí od 1. 10. 2026). Pri nákupe cez Apple je v EÚ provízia 26 %, no **so Small Business Programom 15 %** (aj pri predplatnom od 2. roka).
- Alternatívne obchody, platby mimo Apple a 5 % poplatok za technológiu sa nás netýkajú, kým predávame len cez App Store.
- Prílohy pre Japonsko, Brazíliu a Čínu, EnergyKit a voliteľné API (vek používateľa, Foundation Models) sa nás netýkajú.
- 👤 Dohodu treba prijať v účte vývojára, inak nejde publikovať.

**👤 Obchodník podľa DSA (EÚ):** kto v EÚ predáva predplatné, je obchodník. Apple overí a na stránke appky v EÚ
zverejní **adresu, telefón a e-mail**. Bez vyplnenia nebude appka v EÚ dostupná, teda ani na Slovensku.
- Ako fyzická osoba by si tam mal verejne domácu adresu a osobné číslo. Obvyklé riešenie: živnosť alebo s.r.o.,
  virtuálne sídlo ako adresa, samostatné číslo (druhá SIM alebo eSIM) a `support@encore-sk.com`.
- Príjem od Apple je podnikateľský príjem; daňové riešenie prejdi s účtovníkom (toto nie je právna rada).
- Rovnaké údaje musia byť v Podmienkach v appke (dnes tam je „Jakub Kalina (fyzická osoba)“).
- ✅ V Podmienkach stojí, že Encore „sama na KSIS nechodí ani nič neobnovuje na pozadí“, a je to pravda: serverové
  úlohy volali funkciu, ktorá nikdy nebola nasadená (Cloudflare server nepustí), a 22. 10. boli vypnuté. Text treba
  zmeniť až s upozorneniami z telefónu (`docs/KSIS_PHONE_ALERTS_PLAN.md`).

**Verdikt:** po stránke kódu áno. Review môže zablokovať len to, čo je v App Store Connect (zmluva, produkty,
testovací účet, odkazy), a test nákupu cez TestFlight.

---

## 2. iPhone Duo (skladací iPhone, v predaji od 23. 10. 2026)
- Vonkajší displej 5,4", vnútorný 7,6". Netreba samostatnú appku, je to iPhone.
- Appka postavená v **Xcode 26.4** (tak ju staviame teraz) pôjde na vnútornom displeji s čiernymi okrajmi.
  Celý displej využije až po prebudovaní v **Xcode 27.1**. 👤 Nainštaluj Xcode 27.1.
- Kód je pripravený: nikde nepoužívame pevnú veľkosť obrazovky (`UIScreen.main.bounds`), rozloženie je v SwiftUI.
- Treba vyskúšať: appka je zamknutá na výšku (okrem plátna), a Apple pri Duo odporúča nerozhodovať podľa
  orientácie. Otestujeme v simulátore Duo alebo v Device Hub a prípadne zámok odstránime.
- Na veľkom displeji sa ponúka plátno a detail figúry vedľa seba (nápad na neskôr).
- Podľa správ budú od apríla 2027 snímky pre iPhone Duo povinné pre nové appky. Over v App Store Connect.

## 3. Snímky obrazovky

### App Store
Formát: **6,9" iPhone**, 1320 × 2868 px (prípadne 1290 × 2796), na výšku, 6 až 8 kusov (najviac 10). Menšie
iPhony si App Store zmenší sám. iPad netreba, appka je len pre iPhone.

**👤 Pošli mi tieto snímky** z iPhonu (najlepšie Pro Max, ale stačí akýkoľvek, osadím ich do správneho rozmeru):

| # | Obrazovka | Stav, aký má byť | Nápis, ktorý doplním |
|---|---|---|---|
| 1 | Plátno | Skutočná zostava s 8 až 12 figúrami (časť s videom), oddialené na celý parket | Celá zostava na parkete |
| 2 | Detail figúry | Video hore, poznámky s hlasovkou vo vete a videom v texte, rytmus a takty pod menom | Hlasovka priamo vo vete |
| 3 | Duel | Moje video a vzor vedľa seba, ideálne tá istá figúra | Porovnaj sa so vzorom |
| 4 | Domov | Denník s 2 až 3 poznámkami (text, hlas, video) | Po lekcii zapíšeš všetko za pár sekúnd |
| 5 | Kalendár | Týždeň s tréningami, jedna reflexia, priority | Tréningy, reflexie a priority |
| 6 | Súťaže | Tvoje výsledky z KSIS alebo Moja sezóna | Výsledky z KSIS na jednom mieste |
| 7 | Modul zostavy | Zostava s taktami, aby bolo vidno dĺžku | Dĺžka zostavy z taktov |
| 8 | Kamera so siluetou vzoru (voliteľné) | Natáčanie s priesvitným vzorom | Natáčaj podľa vzoru |

**Pravidlá:**
- Skutočné dáta, nie testovacie („1“, „Testcacacavdscy“). Názvy zostáv a figúr ako u skutočného páru.
- Čas 9:41 a plná batéria. Simulátor to nastaví sám, z iPhonu to vyretušujem.
- Žiadne cudzie osobné údaje: iné páry z KSIS buď vlastné, alebo zakryté.
- Bez cien a bez tvrdení typu „najlepšia appka“ (pravidlo 2.3).

Z tvojich snímok spravím hotové obrázky: zamatové pozadie, zlatý nápis hore, telefón v strede, v presnom
rozmere pre App Store.

### Web (na mobil)
Tie isté obrázky v menšom rozlíšení (WebP), z nich 3 až 4 do sekcie funkcií (plátno, figúra, duel, Denník),
k tomu odznak „Download on the App Store“ a náhľad pre sociálne siete (1200 × 630 px). Web sa robí v Antigravity,
takže ti len pripravím súbory.

---

## 4. Audit funkcií podľa typu tanečníka

**Typy:**
- **E–D** – začiatočník, učí sa figúry;
- **C–B** – pokročilý, vlastné zostavy, súťaží pravidelne;
- **A–S** – špička, detailná technika, veľa lekcií;
- **Zapisovač** – rád má všetko zapísané a uprataté;
- **„Mám to v hlave“** – nechce nič vypĺňať.

Známka = reálna hodnota pre daný typ (1–10).

| Funkcia | Plán | E–D | C–B | A–S | Zapisovač | V hlave | Ako by som ju reálne používal |
|---|---|---|---|---|---|---|---|
| Rýchly zápis (text, hlas, video) a Denník | Free | 9 | 9 | 8 | 9 | **10** | Hneď po lekcii nahrám 20 s hlasovku, čo povedal tréner. Večer ju dám k figúre. Pre „v hlave“ jediná vec, ktorú bude robiť. |
| Plátno so špendlíkmi | Free (1 zostava/tanec) | 6 | **9** | 9 | 8 | 7 | Poskladám zostavu po stenách a vidím, kde čo tancujem. Začiatočník má zostavu od trénera, plátno mu stačí na prehľad. |
| Takty a dĺžka zostavy | Free | 3 | 8 | **9** | 9 | 4 | Na A–S rozhoduje, či sa zmestím do kola. E–D to nerieši. |
| Detail figúry s videom a časovou osou záberov | Free, os Premium | 8 | 9 | 9 | 9 | 6 | Natočím figúru po každej lekcii a o mesiac vidím pokrok. |
| Poznámky s hlasovkou a videom v texte | Free | 7 | 9 | 9 | **10** | 6 | Pri Telemarku hlasovka trénera presne pri slove „hlava“. Zapisovač to bude milovať. |
| Duel a Porovnanie (prekrytie, čiary, korekcie) | Duel Free, nástroje Premium | 5 | 8 | **10** | 8 | 6 | Na A–S kľúčové: prekrytie so vzorom ukáže rozdiel v ráme za 10 s. E–D sa v tom stratí. |
| Kamera so siluetou vzoru a metronómom | Free | 6 | 8 | 8 | 7 | 7 | Natáčam samého seba podľa vzoru v rytme. |
| Zrkadlo | Free | 5 | 4 | 3 | 3 | 5 | Pri doma cvičení bez zrkadla. Na sále je skutočné zrkadlo. |
| Metronóm a tempo | Free | 7 | 6 | 5 | 5 | 6 | Začiatočník sa učí počítať; pokročilí majú hudbu. |
| Kalendár: režim, reflexie, priority, pripomienka | Free, pripomienka Plus | 6 | 8 | 8 | **10** | 3 | Zapisovač si po tréningu dá reflexiu a Top 3; „v hlave“ to nebude vypĺňať. |
| Súťaže a KSIS, Moja sezóna, sledovanie naživo | Free, sezóna Plus | 6 | **9** | 9 | 8 | **9** | Výsledky prídu samé. Ideálne pre „v hlave“: nemusí nič robiť. |
| Partner naživo | Free | 6 | 9 | 9 | 8 | 8 | Partnerka doma upraví figúru a ja to vidím hneď. |
| Knižnica figúr | Free | **8** | 6 | 4 | 7 | 5 | Začiatočník si tu nájde správny názov a rytmus. |
| Strih lekcie na figúry | Plus | 4 | 7 | 8 | 8 | 4 | Hodinové video z kempu rozdelím na figúry. |
| Členská karta vo Wallet | Free | 5 | 5 | 5 | 5 | 5 | Pekná vec na pridávanie priateľov cez QR, nie dôvod na stiahnutie. |
| QR zdieľanie zostavy | Free | 5 | 6 | 5 | 5 | 6 | Pošlem zostavu inému páru ako kópiu. |
| Vzhľad (ikona appky) | Plus | 3 | 3 | 3 | 3 | 3 | Doplnok. |

**Závery:**
- **Najsilnejšie pre všetkých:** rýchly zápis s Denníkom, figúra s videom a poznámkami a KSIS. To patrí na prvé snímky v App Store.
- **E–D:** Free stačí; Plus kúpi len pre viac zostáv. Najväčšia hodnota je zápis po lekcii a knižnica figúr.
- **C–B (hlavný zákazník):** Plus kvôli neobmedzeným zostavám, sezóne a pripomienke. Premium len vtedy, keď začne analyzovať videá.
- **A–S:** Premium (Porovnanie, časová os). Chýba im **prehratie zostavy s hudbou a počítaním dôb** (plánované Tréningové kolá). To by bol dôvod platiť Premium.
- **Zapisovač:** dostane všetko, čo chce (Denník, Kalendár, reflexie, takty).
- **„Mám to v hlave“:** použije hlasovku, plátno a KSIS. Nesmie ho nič nútiť vypĺňať, a to dnes appka spĺňa.

## Zdroje
- [Apple unfolds the iPhone Duo (TidBITS)](https://tidbits.com/2026/09/11/apple-unfolds-the-iphone-duo/)
- [Apple iPhone Duo makes developers think in folds (DevClass)](https://devclass.com/devops/2026/09/16/apple-iphone-duo-makes-developers-think-in-folds/5296425)
- [Apple iPhone Duo API (InfoQ)](https://infoq.com/news/2026/09/apple-iphone-duo-api)
- [App Store Connect: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications)
- [App Store screenshot sizes 2026 (Adalo)](https://studio.adalo.com/blog/app-store-screenshot-sizes-2026)
- [App Store Small Business Program (RevenueCat)](https://www.revenuecat.com/blog/engineering/small-business-program)
- [App Store fees (RevenueCat)](https://www.revenuecat.com/blog/engineering/app-store-fees)
