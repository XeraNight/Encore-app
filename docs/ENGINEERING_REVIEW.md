# Encore: ako appka funguje, kde môže zlyhať a čo je opravené (aktualizované 22. 10. 2026)

Kontrola kódu aj databázy podľa princípov softvérového inžinierstva (DRY, YAGNI, KISS a ďalších) a audit
60 nečakaných situácií. Všetko je overené v kóde alebo priamo v databáze. Čo sa dá overiť len na iPhone,
je označené 🔍.

✅ ošetrené (overené) · 🛠 opravené 22. 10. · ⚠️ funguje, ale má slabinu · ❌ treba opraviť · ❓ rozhodnúť · 🔍 vyskúšať na iPhone

---

## 1. Ako appka funguje (jednoducho)

**Telefón je hlavný.** Všetko sa najprv uloží do databázy v iPhone (SwiftData). Appka funguje aj bez signálu,
server je záloha a cesta k partnerovi.

| Čo | Kedy ide na internet | Koľko požiadaviek |
|---|---|---|
| **Uloženie zostavy** | Zostava sa hneď označí ako „čaká na odoslanie“ (pamätá si to aj po zatvorení appky); odošle sa 0,7 s po poslednej zmene | 1 až 3: zostava, **len zmenené figúry**, **len figúry zmazané v tomto iPhone** |
| **Neúspešné odoslanie** | Opakuje sa po 1 s, 5 s, 30 s a potom každých 5 min (náhodne posunuté), pri návrate siete a pri návrate do appky | rovnako |
| **Stiahnutie zostavy** | Pri otvorení plátna a návrate do appky. **Najprv sa odošle, čo čaká.** Ak sa to nedá, stiahnutie počká, takže nič neprepíše. | 2 |
| **Zoznam zostáv** | Potiahnutím nadol na Domove (najprv odošle, čo čaká) | 1 |
| **Živé spojenie** | Len keď máš prijatého partnera, trénera alebo žiaka. Súkromný kanál: pustí len majiteľa zostavy a partnera. | 1 spojenie; ťahanie najviac 10×/s a kurzor 4×/s, a len keď je partner v kanáli |
| **Pri štarte a návrate** | Konfigurácia (najviac raz za interval), prihlásenie (overí sa v telefóne), odoslanie čakajúcich zmien | 0 až 2 |
| **KSIS** | Server: denne o 5:00, „naživo“ každé 2 min len v deň sledovanej súťaže, cache 30 dní | 0 z telefónu |
| **Hlasovky** | Nikdy, ostávajú v iPhone (partner vidí „[hlasovka 0:07]“) | 0 |
| **Predplatné** | Overuje ho iPhone cez StoreKit (Apple ho podpisuje). Server berie do úvahy len darovanie od majiteľa. | 0 |

**Záznamník synchronizácie** (`SyncLedger`) si v iPhone pamätá:
- ktoré zostavy čakajú na odoslanie;
- ktoré figúry a zostavy si zmazal;
- otlačok SHA-256 každej figúry z posledného odoslania alebo stiahnutia.

Posiela sa len to, čo sa v tomto iPhone naozaj zmenilo. Stará kópia preto nemôže prepísať prácu partnera
a na serveri zmizne len to, čo si naozaj zmazal.

---

## 2. Princípy a kde sme

| Princíp | Čo znamená | Stav |
|---|---|---|
| **KISS** | Najjednoduchšie riešenie, ktoré funguje | ✅ Telefón hlavný, server záloha; jeden záznamník namiesto zložitého zlučovania |
| **YAGNI** | Nestavať nič „na neskôr“ | 🛠 Zmazaných 14 nevolaných analytických funkcií, `SyncStatus`, mŕtvy dizajnový systém (ukážka, tlačidlá, karty), falošné voľby pri ukladaní videa |
| **DRY** | Každé pravidlo na jednom mieste | 🛠 Jedna kontrola „majiteľ alebo partner“ pre kanál aj mazanie, jedna kópia hlasovky, jedno mazanie videa, jeden štýl oznámení, jeden krokovač |
| **Local-first** | Zmena nezmizne bez internetu | 🛠 Záznamník a opakovanie |
| **Idempotencia** | Rovnaké odoslanie viackrát = rovnaký výsledok | 🛠 `upsert` len zmenených figúr, mazanie len podľa zoznamu |
| **Never trust the client** | Bezpečnosť len na serveri | 🛠 Súkromný kanál, QR ako kópia, predplatné cez StoreKit, limity |
| **Least privilege** | Každý len to, čo potrebuje | 🛠 Kanál len majiteľ a partner; funkcia na zápis nákupu zatvorená |

---

## 3. Čo je opravené 22. 10.

| Problém | Následok predtým | Oprava |
|---|---|---|
| Zmeny z lietadla | Neodoslali sa a po návrate ich zmazalo stiahnutie zo servera | Záznamník, opakovanie, stiahnutie čaká |
| Stará kópia partnera | Zmazala figúry, ktoré pridal druhý | Len zmenené figúry, mazanie len podľa zoznamu |
| Zostava na novom iPhone bez figúr | Premenovanie zmazalo všetky jej figúry na serveri | To isté |
| Zostava zmazaná offline | Po obnove sa vrátila | Zmazanie čaká v záznamníku |
| Verejný živý kanál | Bývalý partner alebo ktokoľvek s QR mohol poslať „figúra zmazaná“ | Súkromný kanál (RLS na `realtime.messages`), len majiteľ a partner |
| QR import | Kópia mala ID originálu, pripojila sa do jeho kanála; podvrhnutý QR mohol prepísať zostavu | Vždy nové ID, kód už ID nenesie, kontrola obsahu |
| Kurzor partnera | 60 až 120 správ/s aj osamote (limit projektu 20/s) | 4/s a len s partnerom; ťahanie 10/s; bez partnera žiadne spojenie |
| **Zápis Premium** | Ktokoľvek prihlásený si cez API zapísal Premium zadarmo | Funkcia zatvorená; appka verí StoreKitu a darovaniu majiteľa |
| Hľadanie „%%“ | Vrátilo všetkých, dal sa vypísať zoznam používateľov | `%` a `_` sú obyčajné znaky; najviac 120 hľadaní za 10 min |
| Spam | Bez limitov | Žiadosti 30/deň, pozvánky 20/deň, zápisy zostáv 2000/deň a figúr 5000/deň |
| Partner maže figúru | Server potichu odmietol, figúra sa vrátila | Partner smie mazať (tréner nie) |
| Hodiny v telefóne | Rozhodovali, čo je novšie | Čas zmeny dáva server; uložené poznámky a videá sa ukazujú v čase SR, v zahraničí s označením „(čas SR)“ |
| Video z Denníka vo figúre | Zmazanie figúry, jej videa alebo zostavy zmazalo video aj z Denníka | Súbor sa zmaže, len keď ho nič iné nepoužíva |
| Ukladanie videa | Okno zbieralo rolu, štítky a názov a zahodilo ich; krížik zahodil natočené video bez opýtania | Poctivé okno s náhľadom a orezaním, zahodenie len po potvrdení |
| Hľadanie tanečníkov | Požiadavka pri každom písmene, stará odpoveď mohla prepísať novú | Čaká na pauzu v písaní, stará odpoveď nevyhrá |
| Schránka | Každý skopírovaný odkaz otvoril okno pozvánky | Kontrola len raz po inštalácii |
| Paywall | Bez odpovede App Store ukázal ceny v eurách natvrdo | Ceny len z App Store („…“, kým neodpovie) |
| Plátno nechané otvorené | Obrazovka nikdy nezhasla | Zhasne po 10 min bez dotyku |

---

## 4. Audit 60 nečakaných situácií

### A. Sieť a synchronizácia
| # | Situácia | Stav |
|---|---|---|
| 1 | Režim lietadla počas ukladania | 🛠 čaká v záznamníku, odošle sa pri návrate siete |
| 2 | Appka zabitá počas 0,7 s čakania | 🛠 zostava je označená hneď, odošle sa pri ďalšom spustení |
| 3 | Hotelová Wi-Fi s prihlasovacou stránkou (sieť „je“, ale nič neprejde) | 🛠 opakovanie s narastajúcim odstupom, stiahnutie čaká |
| 4 | Odoslanie prejde napoly (zostava áno, figúry nie) | 🛠 záznamník sa vyčistí až po celom úspechu; opakovanie pošle znova |
| 5 | Partner offline upraví, druhý medzitým pridá figúru | 🛠 nič sa nestratí |
| 6 | Obaja offline upravia **tú istú** figúru | ⚠️ vyhrá ten, kto sa pripojí neskôr (pre v1 v poriadku) |
| 7 | Zostava stiahnutá na nový iPhone, premenovaná pred otvorením | 🛠 figúry na serveri ostanú |
| 8 | Zostava zmazaná offline | 🛠 neobjaví sa znova |
| 9 | Zle nastavené hodiny alebo pásmo v telefóne | 🛠 čas zmeny dáva server |
| 10 | Odhlásenie s neodoslanými zmenami | 🛠 čakajú na prihlásenie toho istého účtu |
| 11 | Iný účet na tom istom iPhone | ✅ dáta aj záznamník sa vymažú, nič sa neodošle pod cudzím účtom |
| 12 | 10 000 iPhonov sa naraz vráti online | 🛠 náhodne posunuté opakovanie |
| 13 | Údržba alebo výpadok Supabase | ✅ obrazovka údržby, práca offline, zmeny čakajú |
| 14 | Bezplatný projekt Supabase sa po 7 dňoch nečinnosti uspí | ⚠️ pred spustením: Pro plán alebo pravidelná aktivita (úloha pre teba) |
| 15 | Server odmietne zápis (limit) | ✅ limity sú pre bežné tancovanie ďaleko; zápis sa skúsi neskôr |

### B. Partner a živé spojenie
| # | Situácia | Stav |
|---|---|---|
| 16 | Bývalý partner sa pripojí do kanála | 🛠 súkromný kanál ho nepustí |
| 17 | Kópia z QR sa pripojí k originálu | 🛠 nové ID |
| 18 | Podvrhnutý QR prepíše tvoju zostavu | 🛠 import je vždy kópia |
| 19 | QR s nezmyselnými súradnicami alebo obrovskými textami | 🛠 kontrola a orezanie |
| 20 | QR prezradí tvoje osobné poznámky k figúram | ❓ dnes kód nesie aj poznámky; rozhodni, či ich má niesť |
| 21 | Partner zmaže figúru | 🛠 povolené |
| 22 | Tréner chce meniť figúry | ✅ poistka v databáze to nedovolí |
| 23 | Partner zablokovaný počas spoločnej práce | 🔍 over: po zablokovaní má prísť o prístup okamžite |
| 24 | Partner zruší účet | ✅ jeho dáta sa vymažú, prístup zanikne |
| 25 | Obaja ťahajú tú istú figúru | ✅ figúru, ktorú ťahá partner, ukazuje zámok |
| 26 | Práca osamote | 🛠 žiadne spojenie, žiadne správy |

### C. Médiá
| # | Situácia | Stav |
|---|---|---|
| 27 | Video zmazané z Fotiek | ✅ „Video bolo zmazané z Fotiek.“ |
| 28 | Zakázaný prístup k Fotkám | ✅ výzva do Nastavení; kamera uloží video do appky |
| 29 | Video len v iCloude (optimalizované úložisko) a offline | 🔍 over, či sa ukáže zrozumiteľná hláška |
| 30 | Plný disk počas nahrávania | 🔍 over na iPhone s takmer plným úložiskom |
| 31 | Hovor počas nahrávania videa alebo hlasovky | 🔍 over, či sa nahrávka uloží |
| 32 | Zmazaná figúra s videom z Denníka | 🛠 video ostane v Denníku |
| 33 | Zmazaná poznámka v Denníku, ktorej hlasovka je vo figúre | ✅ figúra má vlastnú kópiu |
| 34 | Zatvorenie okna po natočení | 🛠 pýta sa |
| 35 | Súbor hlasovky chýba (obnova zálohy bez súborov) | 🔍 over, čo ukáže hlasovka |

### D. Účet a bezpečnosť
| # | Situácia | Stav |
|---|---|---|
| 36 | Zápis Premium cez API | 🛠 zatvorené |
| 37 | Vypísanie všetkých používateľov hľadaním | 🛠 |
| 38 | Spam žiadostí, pozvánok, hľadaní, zápisov | 🛠 limity |
| 39 | SQL injection | ✅ appka posiela len parametre, v databáze nie je dynamické SQL zo vstupu |
| 40 | Uhádnutie tokenu pozvánky | ✅ náhodné, krátkodobé, odvolateľné |
| 41 | Zmazanie účtu | ✅ v appke, so zmazaním karty vo Wallet |
| 42 | Ukradnutý odomknutý telefón | ✅ voliteľný zámok Face ID pri otvorení |
| 43 | Vypršané prihlásenie počas ukladania | ✅ SDK ho obnoví, inak sa zápis zopakuje |
| 44 | Zablokovaný (banned) účet | ✅ oznámenie a RLS `active_account_only` (restrictive na 11 tabuľkách) |
| 45 | Odkaz z cudzej domény | ✅ appka spracuje len vlastné odkazy |
| 46 | Ukradnutý účet majiteľa appky | ⚠️ zapni dvojstupňové overenie na Apple ID, Supabase, GitHube a Verceli |

### E. Predplatné
| # | Situácia | Stav |
|---|---|---|
| 47 | Vrátené peniaze (refund) | ✅ StoreKit odobratie berie do úvahy, zmeny prídu cez `Transaction.updates` |
| 48 | Spustenie offline s Plus | ✅ posledný overený stav z iPhonu |
| 49 | Plus vyprší a v jednom tanci máš 3 zostavy | 🔍 over: zostavy majú ostať čitateľné, len nová sa nevytvorí |
| 50 | Iná krajina a mena | 🛠 ceny len z App Store |
| 51 | Rodinné zdieľanie | ❓ zapnúť alebo nie v App Store Connect |

### F. Čas
| # | Situácia | Stav |
|---|---|---|
| 52 | Poznámka uložená v USA | 🛠 ukáže sa v čase SR, v zahraničí s označením „(čas SR)“ |
| 53 | Zmena letného času | ✅ test |
| 54 | Tréning cez polnoc | ✅ Kalendár počíta s časom po polnoci |
| 55 | Tréning naplánovaný doma, si v USA | ✅ Kalendár ukazuje miestny čas, ako každý kalendár |

### G. Ostatné
| # | Situácia | Stav |
|---|---|---|
| 56 | Skopírovaný odkaz z YouTube | 🛠 okno pozvánky už nevyskočí |
| 57 | Rýchle písanie pri hľadaní tanečníka | 🛠 jedna požiadavka, správne výsledky |
| 58 | Plátno nechané otvorené v taške | 🛠 zhasne po 10 min |
| 59 | Veľké písmo v iPhone | 🛠 poznámky a špendlíky; ⚠️ iné obrazovky majú ešte pevné veľkosti |
| 60 | VoiceOver | ⚠️ hlavné ovládacie prvky majú popisy, celý audit ešte nebol |

---

## 5. Čo ostáva

1. **Overenie nákupu podpisom Apple** (Edge Function s podpísanou transakciou), aby server spoľahlivo
   poznal platiacich. Treba to pred spustením zdieľaných videí a trénerských funkcií.
2. **Supabase Dashboard → Realtime → Settings: vypnúť „Allow public access“**, aby sa nedali otvárať verejné
   kanály (úloha pre teba, 1 klik).
3. Rozhodnutia: poznámky v QR (20), rodinné zdieľanie (51).
4. Testy na iPhone: 23, 29, 30, 31, 35, 49.
5. Pred spustením: Supabase Pro alebo pravidelná aktivita (14), dvojstupňové overenie (46).
6. Dynamic Type a VoiceOver na zvyšných obrazovkách (59, 60).

### Test na iPhone: lietadlo
1. Otvor zostavu, zapni režim lietadla, pridaj figúru a jednou pohni.
2. Zatvor appku úplne (potiahni nahor v prepínači appiek).
3. Vypni režim lietadla a otvor appku a zostavu. Figúra aj posun musia ostať a po chvíli byť aj u partnera.
4. To isté na dvoch iPhonoch: jeden offline pohne figúrou, druhý online pridá figúru. Po pripojení majú obaja
   obe zmeny.

## Zdroje
- [Supabase: Realtime Limits](https://supabase.com/docs/guides/realtime/limits)
- [Supabase Pricing 2026 (Jet Admin)](https://www.jetadmin.io/blog/supabase-pricing-2026-guide-to-plans-limits-and-real-world-costs/)
- [Supabase pricing (CloudZero)](https://www.cloudzero.com/blog/supabase-pricing/)
