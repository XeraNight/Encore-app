# Encore: ako appka funguje, kde môže zlyhať a čo ešte opraviť (22. 10. 2026)

Kontrola kódu aj databázy podľa princípov softvérového inžinierstva (DRY, YAGNI, KISS a ďalších).
Všetko nižšie je overené v kóde alebo priamo v databáze, nič nie je odhad. Kde sa niečo nedalo
overiť bez iPhonu, je to tak označené.

✅ = v poriadku · ⚠️ = funguje, ale má slabinu · ❌ = treba opraviť

---

## 1. Ako appka funguje (jednoducho)

**Telefón je hlavný.** Všetko sa najprv uloží do databázy v iPhone (SwiftData). Appka teda funguje aj
bez signálu a server je len záloha a cesta k partnerovi.

| Čo | Kedy ide na internet | Koľko požiadaviek |
|---|---|---|
| **Uloženie zostavy** | 0,7 s po poslednej zmene (rýchle zmeny sa zlúčia do jednej) | 3: zostava, všetky figúry, zmazanie figúr, ktoré v telefóne nie sú |
| **Stiahnutie zostavy** | pri otvorení plátna, pri návrate do appky s otvoreným plátnom, po opätovnom pripojení živého kanála | 2. **Server vyhrá úplne.** |
| **Zoznam zostáv** | len keď na Domove potiahneš nadol | 1 |
| **Živé spojenie (Realtime)** | pri každom otvorení plátna, aj keď na zostave pracuješ sám | 1 trvalé spojenie + správy (pozri §4) |
| **Pri štarte a návrate do appky** | konfigurácia (najviac raz za interval), prihlásenie (overí sa v telefóne), kontrola schránky | 0 až 1 |
| **KSIS** | server: denne o 5:00, „naživo“ každé 2 min **len** v deň súťaže, ktorú niekto sleduje; stránky KSIS sa držia 30 dní v cache | 0 z telefónu |
| **Hlasovky** | nikdy, ostávajú v iPhone (partner vidí „[hlasovka 0:07]“) | 0 |
| **Videá** | originál vo Fotkách; zdieľaná kópia podľa `docs/VIDEO_STORAGE_AND_SHARING.md` | len pri zdieľaní |

Databáza má dnes 18 MB, 2 účty, 8 zostáv a 13 figúr. Všetkých 22 tabuliek má RLS (pravidlá, kto
smie čo čítať a meniť).

---

## 2. Princípy a čo znamenajú pre náš kód

| Princíp | Čo znamená | Kde ho dodržiavame ✅ | Kde nie ❌ |
|---|---|---|---|
| **KISS** (Keep It Simple) | Najjednoduchšie riešenie, ktoré funguje | Telefón je hlavný, server záloha. Zostava sa posiela celá naraz. | „Posielaj celú zostavu a zmaž všetko, čo nemám“ je až príliš jednoduché, viď §3 (B). |
| **YAGNI** (You Aren't Gonna Need It) | Nestavať nič „na neskôr“ | Odstránená mapka trasy, prázdne `setup()` analytiky | 12 analytických udalostí, ktoré nikto nevolá (napr. `radarCoupleFollowed`, `walletPassSharedProximity`); `SyncStatus` sa nastavuje, ale nikto ho nečíta; `syncRoutineImmediatelyOnBackground` sa nepoužíva |
| **DRY** (Don't Repeat Yourself) | Každé pravidlo či hodnota na jednom mieste | Farby a texty cez tokeny (`textSecondary`), jeden krokovač, jedna kópia hlasovky, jeden výpočet trvania | Kód nekopírujeme naslepo, ale ani nezlučujeme predčasne: spoločnú časť vytiahneme až pri druhom skutočnom výskyte. |
| **Local-first** | Zmena nesmie zmiznúť bez internetu | Ukladá sa hneď do iPhonu | Neodoslaná zmena sa neopakuje a server ju pri stiahnutí prepíše, viď §3 (A) |
| **Idempotencia** | To isté odoslanie viackrát = rovnaký výsledok | `upsert` podľa ID | Odoslanie starej kópie maže cudzie figúry, viď §3 (B) |
| **Never trust the client** | Bezpečnosť len na serveri | RLS na všetkých tabuľkách, poistka trénera, blokovanie | Správy živého kanála a QR kód appka berie ako pravdu, viď §5 |
| **Least privilege** | Každý má len prístup, ktorý potrebuje | Service-role kľúč len v Edge Functions, súkromné úložisko | Živý kanál je verejný |

---

## 3. Nečakané situácie (edge cases)

### (A) ❌ KRITICKÉ: lietadlo a hotelová Wi-Fi

1. Na letisku upravíš zostavu a pridáš figúru, telefón ju uloží.
2. O 0,7 s sa ju appka pokúsi odoslať, ale si už v režime lietadla. **Odoslanie zlyhá a nikde sa
   nezapamätá, že čaká.** Opakuje sa len pri ďalšej úprave tej istej zostavy.
3. V hoteli (aj mimo EÚ) sa pripojíš na Wi-Fi a otvoríš appku. Plátno pri návrate a pri opätovnom
   pripojení stiahne zostavu zo servera a **server vyhrá úplne**. Figúru pridanú v lietadle appka
   v telefóne **zmaže** a tvoje úpravy prepíše starými.

Rovnako dopadne: **zatvorenie appky** počas tých 0,7 s (čakanie je len v pamäti), **hotelová Wi-Fi
s prihlasovacou stránkou** (požiadavky zlyhajú ako offline) a **slabý signál v sále v podzemí**.

**Oprava (návrh):**
- zostava dostane trvalú značku „čaká na odoslanie“ uloženú v iPhone;
- pri návrate siete a appky sa najprv odošle a až potom stiahne;
- stiahnutie nikdy neprepíše zostavu, ktorá ešte čaká.

### (B) ❌ KRITICKÉ: dvaja partneri, jeden offline

1. Ty si offline a pohneš figúrou. Partnerka je online a pridá novú figúru.
2. Ty sa pripojíš a niečo upravíš. Appka pošle **celú tvoju zostavu** a potom zmaže na serveri
   všetky figúry, ktoré v tvojom telefóne nie sú, **teda aj figúru partnerky**.

**Oprava:** namiesto „zmaž, čo nemám“ posielať zoznam figúr, ktoré si naozaj zmazal (tzv.
tombstones). Pri zmene tej istej figúry z oboch strán rozhodne čas zmeny na serveri, nie v telefóne.

### (C) ❌ Partner zmaže figúru a ona sa vráti

Mazať figúry smie podľa RLS len majiteľ zostavy. Keď zmaže partner, server požiadavku potichu
nevykoná (0 riadkov, žiadna chyba) a pri ďalšom stiahnutí sa figúra vráti.
**Rozhodni:** má partner smieť mazať figúry? Pre trénera platí, že nesmie (zámer).

### (D) ⚠️ Zlé hodiny v telefóne

Zoznam zostáv rozhoduje „novšia vyhrá“ podľa času uloženého v telefóne. Telefón s ručne zmeneným
časom alebo zlým časovým pásmom tak môže prehrať novšiu verziu staršou. Riešenie: čas zmeny určuje
server (`now()` v databáze).

### (E) ❌ Skopírovaný odkaz z YouTube otvorí okno pozvánky

Pri každom návrate do appky sa kontroluje, či je v schránke nejaký odkaz (`hasURLs`). Akýkoľvek
odkaz, aj z YouTube, otvorí okno pre odloženú pozvánku. Správne by to malo byť len pri prvom
spustení po inštalácii, na čo je odložená pozvánka určená.

### (F) ✅ Iná krajina, mimo EÚ

Databáza je v Írsku (eu-west-1) a appka funguje odkiaľkoľvek, len s trochu dlhšou odozvou. Dáta
ostávajú v EÚ (GDPR). Problém mimo EÚ nie je krajina, ale nestabilné pripojenie, čiže body (A) a (B).

### (G) ❌ QR kód nesie pôvodné ID zostavy aj figúr

Import z QR ponechá pôvodné ID. Kto naskenuje tvoj QR kód:
- má kópiu, ktorá sa nikdy neuloží na server (ID už patrí tebe a RLS jeho uloženie odmietne,
  potichu);
- **po otvorení plátna sa pripojí do tvojho živého kanála** (`canvas_<ID>`), takže jeho ťahanie
  figúr sa prejaví u teba a tvoje u neho.

**Oprava:** import cudzej zostavy dostane nové ID. Pôvodné ID ponechať len pri obnove vlastnej
zostavy.

---

## 4. 10 000 ľudí naraz a účet za Supabase

Limity bezplatného plánu pre živé spojenie (oficiálna tabuľka Supabase):

| Limit | Free | Pro |
|---|---|---|
| Súčasné spojenia | **200** | 500 |
| Správy za sekundu | **100** | 500 |
| Správy o prítomnosti za sekundu | **20** | 50 |
| Pripojenia do kanála za sekundu | 100 | 500 |

Ďalšie limity bezplatného plánu podľa cenníkov (pred spustením over v dashboarde): databáza 500 MB,
úložisko 1 GB, prenos 5 GB, 50 000 aktívnych používateľov mesačne. **Projekt sa uspí po 7 dňoch bez
aktivity.**

| Situácia | Čo sa stane dnes |
|---|---|
| 200 ľudí má naraz otvorené plátno | Každé plátno = 1 spojenie, **aj keď niekto pracuje sám**. Dvestoprvý sa nepripojí a vidí „Offline“. Ukladanie cez REST funguje ďalej. ❌ |
| 1 človek ťahá figúru | Prítomnosť (kurzor partnera) sa posiela pri **každom** pohybe prsta, 60 až 120-krát za sekundu, aj keď nikto nepočúva. Limit 20 za sekundu pre celý projekt prekročí sám. Supabase potom môže odpájať spojenia. ❌ |
| 4 ľudia ťahajú naraz | Ťahanie pošle až 25 správ za sekundu na osobu, takže 4 ľudia prekročia 100 za sekundu. ❌ |
| 10 000 ľudí uloží zostavu za deň | 3 malé požiadavky na jedno uloženie (kB). Databáza ani prenos to zvládnu. ✅ |
| 10 000 ľudí uloží zostavu **v tú istú minútu** | Asi 30 000 požiadaviek. Malý server bezplatného plánu by spomalil a časť požiadaviek by zlyhala, a tie sa dnes neopakujú, viď (A). ⚠️ |
| Veľkosť dát | Zostava má pár kB a hlasovky ostávajú v telefóne. 500 MB stačí na tisíce používateľov. ✅ |
| KSIS | Server ťahá KSIS sám, nie každý telefón, s cache a „naživo“ len v deň súťaže. ✅ |

**Oprava (zároveň šetrí batériu):**
- živý kanál pripojiť len pri zostave zdieľanej s partnerom alebo trénerom;
- prítomnosť posielať najviac 4-krát za sekundu a len keď je partner pripojený;
- ťahanie posielať najviac 10-krát za sekundu a len s partnerom v kanáli;
- neúspešné odoslanie opakovať s narastajúcim odstupom (1 s, 5 s, 30 s…), nie hneď všetci naraz.

---

## 5. Ako by nás mohli hacknúť (zdieľanie s partnerom)

| Útok | Stav |
|---|---|
| Niekto zoberie verejný anon kľúč z appky a číta cudzie zostavy | ✅ RLS: zostavy vidí len majiteľ, prijatý partner alebo tréner a majiteľ appky |
| Tréner prepíše figúry žiaka | ✅ Poistka v databáze povolí trénerovi meniť len poznámku trénera (aj takty) |
| Bývalý partner po odpojení číta zostavy | ✅ RLS po zrušení prepojenia prístup zoberie |
| Bývalý partner, ktokoľvek s QR kódom alebo hosťujúci tréner po konci kľúča **sa pripojí do živého kanála** a pošle „figúra zmazaná“ | ❌ **Kanál je verejný** (žiadne pravidlá v `realtime`). Appka takú správu berie ako pravdu, zmaže figúru u seba a pri ďalšom odoslaní, viď (B), aj na serveri. Treba súkromný kanál s pravidlami a správy brať len ako signál „obnov zo servera“. |
| Spam pozvánok, hromadné hľadanie tanečníkov | ⚠️ Chýba rate limiting (je v pláne) |
| Uhádnutie pozvánky | ✅ Tokeny sú náhodné, krátkodobé a odvolateľné, bez osobných údajov |
| Prístup k cudzím videám | ✅ Úložisko je súkromné |
| Ukradnutý účet majiteľa appky | ⚠️ Konzola majiteľa má veľkú moc. Zapni dvojstupňové overenie na Apple ID, Supabase, GitHube a Verceli. |

---

## 6. Batéria

| Čo | Stav |
|---|---|
| AirPlay hľadá televízor len na plátne | ✅ |
| Video v poznámkach: vždy len jedno, bez zvuku | ✅ |
| Žiadne časovače na pozadí (audit Kalendára) | ✅ |
| Živé spojenie a správy aj pri práci osamote | ❌ viď §4 |
| Plátno nechá obrazovku stále zapnutú (zámer pre sálu) | ⚠️ Ak ho niekto nechá otvorené v taške, vybije baterku. Návrh: po 10 min bez dotyku dovoliť zhasnutie. |

---

## 7. Checklisty

### Dáta a offline
- [x] Každá zmena sa uloží hneď do iPhonu
- [x] Prázdna odpoveď servera nezmaže figúry v telefóne
- [x] Takty prázdne idú ako `null` (vymazané takty sa nevrátia)
- [ ] Neodoslaná zmena sa pamätá aj po zatvorení appky a opakuje sa (A)
- [ ] Stiahnutie neprepíše neodoslané zmeny (A)
- [ ] Stará kópia nemôže zmazať figúry partnera (B)
- [ ] Partnerovo mazanie: rozhodnúť a dorobiť (C)
- [ ] Čas zmeny určuje server, nie telefón (D)
- [ ] Import z QR dostane nové ID (G)

### Náklady (účet)
- [x] KSIS ťahá server s cache, „naživo“ len v deň súťaže
- [x] Konfigurácia najviac raz za interval
- [x] Zoznam zostáv len pri potiahnutí nadol
- [x] Hlasovky sa neposielajú na server
- [ ] Živý kanál len pri zdieľanej zostave (§4)
- [ ] Prítomnosť a ťahanie obmedzené a len s partnerom (§4)
- [ ] Opakovanie s narastajúcim odstupom (§4)

### Bezpečnosť
- [x] RLS na všetkých 22 tabuľkách
- [x] Service-role kľúč len v Edge Functions, žiadne tajomstvá v gite
- [x] Blokovanie, poistka trénera, súkromné úložisko
- [ ] Súkromný živý kanál s pravidlami (§5)
- [ ] Správy kanála len ako signál, nie pravda (§5)
- [ ] Rate limiting (pozvánky, hľadanie)
- [ ] Dvojstupňové overenie na všetkých účtoch (úloha pre teba)

### Kód (DRY, YAGNI, KISS)
- [x] Žiadne varovania kompilátora (pripravené na Swift 6)
- [x] Spoločné tokeny a komponenty namiesto kópií
- [ ] Zmazať nepoužívané analytické udalosti, `SyncStatus` a `syncRoutineImmediatelyOnBackground`
- [ ] Rozhodnúť o analytike: buď zapojiť (s App Privacy), alebo zmazať celú kostru
- [ ] Okno pozvánky zo schránky len pri prvom spustení (E)

---

## 8. Navrhované poradie opráv

1. **Offline a konflikty (A, B, D):** značka „čaká na odoslanie“, opakovanie pred stiahnutím,
   zoznam zmazaných figúr, čas zo servera. Najdôležitejšie, inak môžu zmiznúť dáta.
2. **Živý kanál (§4, §5, G):** súkromný kanál s pravidlami, pripojenie len pri zdieľanej zostave,
   obmedzenie správ, správy ako signál, nové ID pri QR importe. Šetrí účet, batériu aj bezpečnosť
   naraz.
3. **Rozhodnutia:** mazanie partnerom (C), analytika.
4. **Drobnosti:** schránka (E), YAGNI upratanie, zhasnutie obrazovky na plátne.
5. **Rate limiting** (už v pláne).

Body 1 a 2 menia databázu (pravidlá, stĺpce), takže SQL ukážem vopred. Každý krok vyskúšame na
iPhone podľa testu nižšie.

### Test na iPhone (po oprave 1)
1. Otvor zostavu, zapni režim lietadla, pridaj figúru a jednou pohni.
2. Zatvor appku úplne (potiahni nahor z prepínača appiek).
3. Vypni režim lietadla a otvor appku a zostavu. Figúra aj posun musia ostať a po chvíli byť aj
   u partnera.
4. To isté na dvoch iPhonoch: jeden offline pohne figúrou, druhý online pridá figúru. Po pripojení
   musia mať oba obe zmeny.

## Zdroje
- [Supabase: Realtime Limits](https://supabase.com/docs/guides/realtime/limits)
- [Supabase Pricing 2026 (Jet Admin)](https://www.jetadmin.io/blog/supabase-pricing-2026-guide-to-plans-limits-and-real-world-costs/)
- [Supabase pricing (CloudZero)](https://www.cloudzero.com/blog/supabase-pricing/)
