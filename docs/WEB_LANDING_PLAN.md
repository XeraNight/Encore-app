# Web encore-sk.com: UI/UX audit a plán novej propagačnej stránky

> 14. 10. 2026. Prezreté naživo na `https://www.encore-sk.com` (desktop aj mobil 375 px) a v kóde `web/`.
> Stav: **návrh na schválenie**, v kóde webu sa zatiaľ nič nemenilo (okrem domény a favicony).

## 1. Audit súčasného webu

### Čo je dobré
- Silná prvá obrazovka: veľký serif nadpis, zlatý gradient a zamatové pozadie sedia so značkou.
- Na mobile nevzniká vodorovné posúvanie, menu sa zbalí, existuje spodná lišta „Stiahnuť“.
- Právne stránky (`/privacy`, `/terms`, `/support`, `/delete-account`) fungujú a majú správny e-mail `support@encore-sk.com`.
- PostHog beží bez cookies (`persistence: memory`), takže netreba cookie lištu.

### 🔴 Musí sa opraviť (právne riziko alebo zamietnutie v App Store)
| # | Problém | Prečo |
|---|---|---|
| W1 | „★★★★★ **4.9 v App Store & Google Play**“ | Appka ešte nie je vydaná. Vymyslené hodnotenie je klamlivá reklama (zákon o ochrane spotrebiteľa) a Apple to môže brať ako zavádzanie. |
| W2 | „Navrhnuté s **trénermi SZTŠ**“, „**OFICIÁLNY REGISTER SZTŠ**“, „Prepojenie s **oficiálnou databázou**“ | Dohoda so SZTŠ neexistuje. Text naznačuje oficiálne partnerstvo. |
| W3 | „**Automatický** import bodov SZTŠ z ksis.eu“ | Import robí používateľ sám v appke cez KSIS. |
| W4 | „Dospelí B → A, podľa súťažného poriadku“ | Appka postup do triedy nepočíta (pravidlo projektu: žiadne vymyslené pravidlá postupu). |
| W5 | Ceny a plány: Plus **4,99 €**, „**Encore Studio** 14,99 €“ | V appke je Plus 5,99 € / 49,99 €, Premium 14,99 € / 129,99 € a plán sa volá **Premium**. Funkcie v cenníku nesedia s appkou (napr. „Roster párov“, „Posture Angle Lines“). |
| W6 | Tlačidlo App Store vedie na `apps.apple.com/search?term=Encore` → **„stránka sa nenašla“** | Appka nie je v App Store. Do vydania: „Čoskoro v App Store“ + odber noviniek / TestFlight. |
| W7 | Google Play a „Android tablety & mobily“ | Android neexistuje. Odstrániť alebo „Android neskôr“. |
| W8 | Zásady ochrany súkromia nespomínajú **PostHog, Vercel Analytics, Formspree, Resend, Cloudflare (R2, e-mail)** a nemajú dátum účinnosti | GDPR čl. 13: zoznam príjemcov údajov. |
| W9 | Pätička: „© 2026 Encore / **Ellegnote**“, chýba prevádzkovateľ (meno, kontakt) | Starý názov; pri predaji predplatného má byť jasné, kto službu poskytuje. |

### 🟠 UX a dizajn
| # | Problém |
|---|---|
| U1 | Hlavička je pri posúvaní priehľadná: text menu sa prekrýva s obsahom pod ňou (napr. „TRÉNING V SÁLE“ cez telefón). |
| U2 | Interaktívny HTML telefón (921 riadkov, Web Audio metronóm) je ťažký, na mobile zaberá celú obrazovku a nie je to skutočná appka. Najlepšie stránky appiek ukazujú **skutočné screenshoty alebo krátke video**. |
| U3 | Sekcie sa objavujú až pri posúvaní: počas rýchleho posunu sú prázdne tmavé plochy. |
| U4 | Tykanie a vykanie sa miešajú („Zvoľ si“ vs. „Kliknite“, „Naskenujte“). Appka tyká. |
| U5 | Technický žargón: „Realtime WebSocket“, „Bezierove krivky“, „Syntetický PCM metronóm“, „3000 × 3000 pt“. |
| U6 | Logo „ENCORE **DANCE STUDIO**“ pôsobí ako tanečné štúdio, nie appka. |
| U7 | Mobil: spodná lišta „Stiahnuť“ prekrýva koniec pätičky; krúžok „E“ v lište nič nehovorí. |
| U8 | Chýba FAQ (KSIS, súkromie, offline, partner, cena, Android) a „Ako to funguje“ v 3 krokoch. |
| U9 | Titulky stránok majú značku dvakrát („… \| Encore \| Encore“). Obrázok na zdieľanie (OG) bol na starej doméne (opravené, nasadí sa pushom). |
| U10 | 1 obrázok bez `alt` textu. |

## 2. Plán novej stránky

Inšpirácia: osvedčená štruktúra najlepších stránok appiek (Flighty, Things, Strava, Structured, Duolingo):
**jedna jasná veta → skutočná appka → 3 dôvody → ako to funguje → pre koho → cena → FAQ → stiahni**.
Žiadne vymyslené čísla a hodnotenia: dôveru budujú skutočné screenshoty a poctivé texty.

| Sekcia | Obsah |
|---|---|
| **Hlavička** | Sklenená (rozmazané pozadie), logo ENCORE, odkazy Funkcie · Pre trénerov · Cena · FAQ, tlačidlo „Stiahnuť“. |
| **Hero** | Nadpis (napr. „Tvoj tanec. Každá figúra, každý tréning, každá súťaž.“), podnadpis v jednej vete, oficiálny odznak App Store („Čoskoro“ do vydania), vpravo skutočný iPhone so screenshotom (Domov) s jemným 3D náklonom pri pohybe myši. |
| **Pás dôvery** | Len pravdivé fakty: „Navrhnuté tanečníkom pre tanečníkov“, „Dáta v EÚ“, „Funguje aj offline v sále“, „Slovensky“. |
| **3 piliere** | Zostavy (parket a figúry) · Tréning (poznámky, Top 3, Plán) · Súťaže (KSIS denník, kalendár). Karty so skutočným výrezom obrazovky. |
| **Funkcie striedavo** | 4–5 blokov text ↔ screenshot: Parket a zostavy, Poznámky hlasom, Video vedľa seba, Plán s kalendárom, Súťaže z KSIS. Krátke nadpisy, 2 vety, 3 odrážky. |
| **Ako to funguje** | 3 kroky: Vytvor zostavu → Trénuj a zapisuj → Sleduj súťaže. |
| **Pre koho** | Prepínač Tanečník · Pár · Tréner (rola, nie plán), pri každom 3 konkrétne prínosy. |
| **Cena** | Free / Plus / Premium presne podľa appky, prepínač Mesačne/Ročne (ročne „ušetríš X %“), poznámka o automatickom obnovení. |
| **FAQ** | 8–10 otázok (akordeón), aj pre Google: Je to oficiálna appka SZTŠ? (nie) · Ako funguje KSIS? · Kde sú moje dáta? · Funguje offline? · Android? · Zrušenie predplatného? · Partner a tréner? |
| **Záverečná výzva** | Veľký nadpis + App Store odznak + QR kód pre počítač. |
| **Pätička** | Prevádzkovateľ, `support@encore-sk.com`, Súkromie · Podmienky · Zmazanie účtu · Podpora, upozornenie „Encore nie je oficiálna aplikácia SZTŠ“. |

**Technicky:** Next.js ako dnes, bez nových balíčkov. Screenshoty vyrobím zo simulátora (s ukážkovými dátami) ako optimalizované obrázky. Interaktívny HTML telefón, maskota a „stage lighting“ nahradia skutočné screenshoty → rýchlejšie načítanie. Pohyb: jemné objavenie sekcií (bez prázdnych plôch), parallax telefónu, rešpektuje „Obmedziť pohyb“. Mobil najprv, 16 px okraje, bez prekrývania lištou.

**Hneď popri tom:** opraviť zásady ochrany súkromia (W8, s dátumom účinnosti) a pätičku (W9).

## 3. Otázky
1. Texty a vzhľad webu robí aj Antigravity. Mám web prerobiť ja tu (súbory v `web/`), alebo pripraviť zadanie pre Antigravity?
2. Kto je prevádzkovateľ do pätičky a zásad: tvoje meno + mesto (bez adresy), alebo počkáme na rozhodnutie o živnosti?
3. Do vydania appky: tlačidlo „Čoskoro v App Store“ s odberom e-mailu, alebo odkaz na verejný TestFlight?
