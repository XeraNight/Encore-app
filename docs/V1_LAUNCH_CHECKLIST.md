# Encore v1: kontrolný zoznam pred spustením

Stav k 8. 10. 2026, overené proti kódu a serveru (audit). Tento dokument nahrádza
`LEGAL_AND_COMPLIANCE_CHECKLIST.md` (ten je v niekoľkých bodoch zastaraný).

**Legenda:** ✅ hotové a overené · ❌ chyba v kóde, opraviť pred odoslaním · ⚠️ musíš urobiť ty
(účet, zmluva, rozhodnutie) · 🔍 overiť na iPhone · ⏳ až po kúpe Developer účtu

Poradie: najprv **A** (účty a zmluvy trvajú dni), súbežne **C** (kód), potom **D–E** (texty a App Store
Connect), nakoniec **F** (testy) a **G** (deň spustenia).

---

## A. Účty, zmluvy, dane

| # | Úloha | Stav | Poznámka |
|---|---|---|---|
| A1 | Apple Developer Program (99 €/rok) | ⚠️ | Ako **fyzická osoba**: v App Store bude ako predajca tvoje meno. Organizácia vyžaduje firmu a D-U-N-S číslo. |
| A2 | Dvojstupňové overenie na Apple ID, Supabase, Cloudflare, Google Cloud, GitHub | ⚠️ | Strata ktoréhokoľvek z nich = strata appky. |
| A3 | App Store Connect → Business: **Paid Apps Agreement**, bankový účet, daňový formulár (W-8BEN) | ⏳ | Bez toho nejdú predplatné ani sandbox nákupy v produkcii. |
| A4 | **App Store Small Business Program** (provízia 15 % namiesto 30 %) | ⏳ | Prihlásiť hneď po aktivácii účtu. |
| A5 | **Status obchodníka podľa DSA (EÚ)** v App Store Connect | ⏳ | Appka s predplatným = obchodník. Apple v EÚ **zverejní adresu, telefón a e-mail**. Ako adresu môžeš dať P.O. Box. Bez toho appku v EÚ nezverejnia. |
| A6 | Dane na Slovensku | ⚠️ | Rozhodni so **daňovým poradcom**: živnosť alebo licenčný (autorský) príjem; nad 18 rokov. Opýtaj sa aj na **registráciu pre DPH podľa § 7a** (príjmy od Apple z Írska). Daňové priznanie do 31. 3. nasledujúceho roka. |
| A7 | Supabase DPA (zmluva o spracovaní) | ⚠️ | Dashboard → Organization → Legal documents → vyžiadať DPA (PandaDoc) a podpísať. |
| A8 | Cloudflare DPA | ✅ | Je súčasťou Self-Serve zmluvy. Stačí si ho uložiť ako PDF k dokumentácii. |
| A9 | Supabase Pro (25 $/mes., limit výdavkov zapnutý) | ⚠️ | Free projekt sa **uspí po 7 dňoch nečinnosti**: keby sa to stalo počas review, appka nefunguje = zamietnutie. Pro dá aj denné zálohy a ochranu pred uniknutými heslami. Odporúčam zapnúť týždeň pred odoslaním. |
| A10 | Google Cloud → OAuth consent screen: stav **In production** | ⚠️ | V stave „Testing“ sa cez Google prihlásia len pridaní testeri. Vyplň názov, podporu, odkaz na zásady. |
| A11 | Doména a e-mail podpory | ⚠️ | Potrebuješ **jednu skutočnú schránku** (pozri C17) a verejnú webovú stránku pre zásady a podporu (pozri D1). |
| A12 | Názov „Encore“ | ⚠️ | Over dostupnosť v App Store Connect (pri vytváraní appky) a ochranné známky (ÚPV SR, EUIPO TMview). Pravdepodobne bude treba napríklad „Encore – Ballroom Dance“. |

## B. Certifikáty, kľúče, identifikátory (Developer portál)

| # | Čo | Stav | Na čo |
|---|---|---|---|
| B1 | App ID `com.jakub.encore` + capability **Sign in with Apple** | ⏳ | Povinné, pozri C3. |
| B2 | Podpisový certifikát a profily | ⏳ | Nechaj Xcode „Automatically manage signing“, nič nesťahuj ručne. |
| B3 | **Sign in with Apple kľúč (.p8)** + Services ID | ⏳ | Pre Supabase Auth (Apple provider) a pre zrušenie tokenu pri zmazaní účtu (C4). Kľúč ulož bezpečne, stiahneš ho iba raz. |
| B4 | **Pass Type ID** + certifikát (.p12) + Apple **WWDR G4** | ⏳ | Len ak Peňaženka ide do v1 (C8). |
| B5 | **In-App Purchase kľúč (.p8)** (App Store Connect → Users and Access → Integrations) | ⏳ | Pre overenie nákupov na serveri (C5) a App Store Server Notifications. |
| B6 | APNs (push) kľúč | — | Netreba, v1 nemá push. |
| B7 | Live Activities, widget | ✅ | Bez push, bez špeciálneho certifikátu. |

## C. Kód a nastavenia appky (audit)

### C-I. Opravené v tomto kroku
| # | Čo | Stav |
|---|---|---|
| C0a | Hodinky: odstránený nepoužívaný `WatchCueingManager.swift`, žiadny watch target. Plán: `docs/WATCHOS_V1_1_PLAN.md` | ✅ |
| C0b | Režim na pozadí `remote-notification` odstránený (appka push nepoužíva, inak riziko 2.5.4) | ✅ |
| C0c | `NSSupportsLiveActivitiesFrequentUpdates` odstránené (iba pre push) | ✅ |
| C0d | Šablónový widget „Favorite Emoji“ odstránený; akcie Live Activity po slovensky | ✅ |
| C0e | Privacy manifest: správny dôvod pre metadáta súborov (C617.1) a vyplnené zbierané dáta | ✅ |
| C0f | Text Face ID zodpovedá skutočnosti (zámok appky, potvrdenie zmazania) | ✅ |
| C0g | Nepoužitý obrázok `bg_fluid` odstránený | ✅ |

### C-II. Musí sa opraviť pred odoslaním (čaká na tvoje schválenie, pozri koniec dokumentu)
| # | Problém | Riziko | Návrh |
|---|---|---|---|
| C1 | Appka je nastavená pre **iPhone, iPad, Vision Pro aj Mac** (`TARGETED_DEVICE_FAMILY = 1,2,7`, Mac Catalyst zapnutý) | Apple testuje aj iPad; nedoladené rozloženie = zamietnutie (2.1/4.0) | **Len iPhone**: Xcode → target Encore → General → Supported Destinations: nechaj iba iPhone (urobíš ty v Xcode). V App Store Connect vypni „Mac (Apple Silicon)“ a „Apple Vision Pro“. |
| C2 | ✅ 9. 10.: paywall a popisy plánov uvádzajú len hotové funkcie. Pôvodne paywall sľuboval funkcie, ktoré neexistujú: **Top 3 priority**, **7-dňový kľúč pre trénera**, **Parket Optima a exkluzívne ikony**, **KSIS Radar s notifikáciami**, **„Čo sme robili naposledy“ a Zero-Delete**; „biomechanická analýza s detekciou“ je v skutočnosti ručné meranie uhlov | Zamietnutie (2.3.1, 3.1.2): predplatné musí dodať to, čo sľubuje | Z paywallu a popisov plánov odstrániť, čo nie je; analýzu premenovať na „Meranie uhlov a sklonu vo videu“. Doplniť limit zdieľaných videí 1/10/50 GB. |
| C3 | **Sign in with Apple** je skryté (`AuthFeatureFlags.appleSignInEnabled = false`), Google je zapnutý | Zamietnutie (4.8) | Po kúpe účtu: capability, Apple provider v Supabase (B3), zapnúť príznak, otestovať. ⏳ |
| C4 | Pri zmazaní účtu sa **nezruší Apple token** (TODO v `delete-account`) | Apple to vyžaduje pri Sign in with Apple | Doplniť volanie `appleid.apple.com/auth/revoke` (B3). ⏳ |
| C5 | Server **verí appke**, aký plán si kúpila (`record_app_store_transaction`) | Ktokoľvek si zapne Premium a 50 GB zadarmo | Serverová funkcia overí podpísaný doklad od Apple (JWS) + App Store Server Notifications V2. ⏳ (B5) |
| C6 | ✅ 8. 10. opravené: nahlásenie otvorí e-mail podpore s menom a Dancer ID. Pôvodne **„Nahlásiť používateľa“ bolo falošné**: ukáže „Podnet bol prijatý, preveríme do 24 h“, ale nič neodošle | Klamanie používateľa, Guideline 1.2 (UGC musí mať funkčné nahlásenie) | Skutočné nahlásenie: e-mail na podporu s menom a Dancer ID, alebo tabuľka `reports` (SQL ukážem). |
| C7 | QR pozvánky a odkazy vedú na **mŕtvu adresu** `encore-app.vercel.app/add` | Skener v appke funguje, no Fotoaparát iPhonu otvorí chybovú stránku 404 (2.1) | Stránka `/add` na tvojom novom webe (otvorí appku alebo App Store), alebo odkaz `encore://`. |
| C8 | **Peňaženka** volá mŕtvu adresu `/api/wallet/pass` | Tlačidlo nefunguje (2.1) | Buď dokončiť (B4 + nasadiť `generate-wallet-pass`), alebo tlačidlo vo v1 skryť. |
| C9 | ✅ 9. 10.: vynútená aktualizácia a údržba sa čítajú z tabuľky `app_config` v Supabase (SQL `20261009_app_config.sql` treba spustiť), nepoužívané prepínače odstránené. Pôvodne **`RemoteConfigManager` volal mŕtvu `/api/app-config`** | Bez dopadu na používateľa, zbytočná požiadavka | Presunúť do Supabase tabuľky (SQL ukážem) alebo odstrániť. |
| C10 | **Obrázky s neistým pôvodom**: `EncoreStageBackground` (pozadie **každej obrazovky**) a `DanceParquetFloor` (parket na plátne). Starý dokument ich označil ako možno z Pinterestu | Zamietnutie (5.2.1) alebo žaloba | Potvrď pôvod a licenciu (vlastný, AI s komerčnými právami, platená licencia), alebo ich nahradím kódom (gradient, kreslený parket). |
| C11 | Režim na pozadí **audio** | Musí mať viditeľný dôvod (2.5.4) | 🔍 Over, že metronóm / hudba hrá aj pri zamknutom telefóne. Ak nie, režim odstránim. |
| C12 | **E-maily pri registrácii**: overenie e-mailu je zapnuté, no vlastný e-mailový server nie je nastavený (`send-email` nie je nasadená) | Supabase so zabudovaným e-mailom posiela len na adresy tímu a pár správ za hodinu → **registrácia nebude fungovať** | Nastaviť SMTP (napr. Resend / Brevo zadarmo) na tvojej doméne: SPF, DKIM, Supabase → Auth → SMTP. Šablóny už sú v `supabase/templates`. |
| C13 | ✅ 9. 10.: zmazaná zo Supabase aj z projektu. Testovacia serverová funkcia `ksis-connectivity-test` bola nasadená a v kóde mala **predvolené heslo** | Zbytočný verejný vstup, heslo je v gite | Zmazať v Supabase aj priečinok funkcie pred spustením. |
| C14 | ✅ 9. 10.: všetkých 25 volaní nahradených `Logger`. Pôvodne `print()` v 15 súboroch | Pravidlo projektu (Logger), nie riziko zamietnutia | Nahradiť `Logger`. |
| C15 | Minimálna verzia iOS je **26.4** | Ľudia s iOS 26.0 až 26.3 appku nestiahnu | Rozhodni: 26.0 (viac ľudí, treba otestovať) alebo nechať 26.4. |
| C16 | ✅ 8. 10. opravené. Majiteľská konzola mala ako ukážku tvoj **osobný e-mail** | Únik osobného údaja v binárke | Nahradiť „meno@domena.sk“. |
| C17 | ✅ 13. 10.: jeden e-mail podpory `support@encore-sk.com` (doména encore-sk.com, preposielanie cez Cloudflare Email Routing) v `AppContact.swift`, v zásadách (PRIVACY_POLICY.html) a na webe (privacy, terms, support, delete-account). Pôvodne **štyri rôzne kontaktné e-maily** | Nefunkčný kontakt = problém pri GDPR aj review | Zmena len v `AppContact.swift` a na webe. |
| C18 | ✅ 8. 10.: v zásadách je meno Jakub Kalina a kontakt. Pôvodne „Prevádzkovateľom je autor aplikácie“ | GDPR čl. 13 vyžaduje **meno a kontakt** prevádzkovateľa | Doplniť meno, kontakt (a adresu alebo P.O. Box ako v DSA). |
| C19 | Vekové obmedzenie nie je nikde v appke ani v podmienkach | GDPR (vek digitálneho súhlasu na Slovensku je 16), plánovaný slovenský zákon o sociálnych sieťach | Rozhodni: **16+** (odporúčam), alebo 13+ so súhlasom rodiča. Potom potvrdenie pri registrácii + text v podmienkach. |
| C20 | ✅ Overené 9. 10.: pri registrácii je veta „Pokračovaním súhlasíš s Podmienkami… a Zásadami…“ s funkčnými odkazmi a potvrdenie veku (16+ alebo súhlas rodiča). Pôvodný záznam: chýba výslovný súhlas s Podmienkami a Zásadami | Dôkaz súhlasu pri predplatnom a UGC | Riadok „Registráciou súhlasíš s…“ (odkazy už sú) alebo zaškrtávacie pole. |
| C22 | ✅ 9. 10.: KSIS sa číta zo stránky otvorenej v appke (`ksis-page`), funguje zadarmo bez povolenia; paywall KSIS nepredáva. Pôvodne: **KSIS náš server blokuje** (Cloudflare 403, test 9. 10.). Nefunguje „Importovať výsledok“ ani automatika. Paywall pritom sľubuje „KSIS kalkulačku“ a Plus má KSIS v popise | Zamietnutie (2.1, 3.1.2): platená funkcia nefunguje | Do vydania buď povolenie od SZTŠ / KSIS, alebo import z otvorenej stránky KSIS v appke (`docs/KSIS_SAMPLES_NEEDED.md` §1). Inak KSIS z paywallu a popisu Plus odstrániť. |

### C-III. Overené ako v poriadku
| # | Čo | Stav |
|---|---|---|
| C21 | Zmazanie účtu priamo v appke, s potvrdením a Face ID, maže aj súbory a zdieľané videá | ✅ |
| C22 | Stiahnutie osobných údajov (GDPR čl. 15 a 20) | ✅ (nasadiť `20261008_export_shared_videos.sql`) |
| C23 | RLS na všetkých tabuľkách, majiteľ iba zo servera, kontrola bezpečnosti Supabase bez varovaní k novým častiam | ✅ |
| C24 | Žiadne tajné kľúče v kóde ani v histórii gitu (iba verejná URL a anon kľúč) | ✅ (repozitár na GitHube nech je **súkromný**) |
| C25 | `ITSAppUsesNonExemptEncryption = false` (iba štandardné HTTPS) | ✅ |
| C26 | Ikona 1024×1024 bez priehľadnosti, tmavá aj tónovaná verzia, launch screen | ✅ |
| C27 | Predplatné: cena, obdobie, text o automatickom obnovení, Obnoviť nákupy, odkazy na podmienky a zásady | ✅ |
| C28 | Žiadne sledovanie, reklama ani analytika (PostHog je iba prázdna príprava) | ✅ |
| C29 | Texty oprávnení (kamera, mikrofón, Fotky, kalendár, reč, Face ID) po slovensky a pravdivé | ✅ |
| C30 | Simulovaný QR sken existuje iba v simulátore | ✅ |
| C31 | Build s Xcode 26 / iOS 26 SDK (povinné od 28. 4. 2026); od apríla 2027 bude treba iOS 27 SDK | ✅ |
| C32 | Videá: Fotky + Cloudflare R2, limity, bezpečnosť (`docs/VIDEO_STORAGE_AND_SHARING.md`) | ✅ (🔍 test na dvoch iPhonoch) |

## D. Právne dokumenty

| # | Dokument | Stav | Poznámka |
|---|---|---|---|
| D1 | **Zásady ochrany osobných údajov na verejnej URL** | ⚠️ | App Store Connect vyžaduje verejný odkaz. Obsah z appky (`LegalComplianceView`) daj na web, napríklad `tvojadomena.sk/sukromie`. |
| D2 | Obsah zásad | ❌ čiastočne | Doplniť: meno a kontakt prevádzkovateľa (C18); zoznam spracovateľov: **Supabase** (databáza, EÚ), **Cloudflare** (zdieľané videá, Európa), **Apple** (nákupy, Prihlásenie s Apple), **Google** (prihlásenie); doba uchovávania (účet do zmazania, zálohy X dní); prenosy mimo EÚ (Cloudflare a Supabase sú americké a singapurské firmy → štandardné zmluvné doložky v ich DPA); vek (C19); práva vrátane sťažnosti na Úrad na ochranu osobných údajov SR. |
| D3 | **Podmienky používania (EULA)** na verejnej URL | ⚠️ | Pri predplatnom povinný odkaz. Buď štandardná EULA od Apple plus vlastné podmienky (pravidlá obsahu, vek, zdravotný disclaimer, informatívnosť KSIS bodov), alebo vlastná EULA. Texty máš v appke. |
| D4 | Stránka podpory (Support URL) | ⚠️ | Povinná v App Store Connect: kontakt a krátke FAQ. |
| D5 | Záznamy o spracovateľských činnostiach (GDPR čl. 30) | ⚠️ | Jednoduchá tabuľka: aké dáta, prečo, kde, ako dlho. Pomôže aj pri otázkach Úradu. |
| D6 | Licencie obrázkov a ikon | ⚠️ | Pozri C10. Zapíš si pôvod každého assetu (súbor + zdroj + licencia). |
| D7 | SZTŠ / KSIS | ⚠️ | Pošli informačný e-mail SZTŠ (text je v `LEGAL_AND_COMPLIANCE_CHECKLIST.md` §5.3). V App Store Connect pri „Content Rights“ uveď, že appka zobrazuje údaje tretej strany (KSIS). |
| D8 | Kontrola právnikom | ⚠️ | Odporúčané pre zásady a podmienky pred spustením s predplatným. |

## E. App Store Connect

| # | Položka | Stav | Poznámka |
|---|---|---|---|
| E1 | Názov (do 30 znakov), podtitul, kľúčové slová, popis (SK, ideálne aj EN), promo text | ⚠️ | Popis smie sľubovať len to, čo appka vie (C2). |
| E2 | Kategória | ⚠️ | Návrh: **Sports**, druhá Health & Fitness. |
| E3 | **Vekové hodnotenie** (nový dotazník vrátane otázok o sociálnych funkciách, povinných od septembra 2026) | ⚠️ | Odpovedaj pravdivo: obsah od používateľov zdieľaný s prepojenými ľuďmi, vyhľadávanie tanečníkov. „Sociálne médiá: áno“ znamená minimálne 13+. |
| E4 | **App Privacy** (štítky súkromia) | ⚠️ | Rovnako ako privacy manifest: e-mail, meno, ID používateľa, fotky (profilová fotka; zdieľané videá sú vo v1 vypnuté), iný obsah (zostavy, poznámky, výsledky), história nákupov. Všetko „prepojené s používateľom“, „funkčnosť appky“, **bez sledovania**. Diagnostika: nie. |
| E5 | Snímky obrazovky **6,9" iPhone 1320×2868** (3 až 10 ks), voliteľne video 15–30 s | ⚠️ | Iba iPhone (C1). Iba skutočné obrazovky, bez sľubov, ktoré appka nesplní. |
| E6 | Predplatné: jedna skupina „Encore“: Plus mesačne a ročne, Premium mesačne a ročne (`com.jakub.encore.plus.*`, `com.jakub.encore.premium.*`) | ⏳ | Lokalizované názvy a popisy, ceny, screenshot paywallu pre review. Rozhodni, či povolíš Family Sharing. |
| E7 | App Store Server Notifications V2 URL | ⏳ | Na serverovú funkciu z C5. |
| E8 | **Poznámky pre review + 2 demo účty** | ⚠️ | Dva účty s overeným e-mailom (napríklad partner a partnerka), prepojené, s ukážkovou zostavou a figúrami. Napíš, ako otestovať spoločnú zostavu naživo a predplatné (sandbox). Účty vytvoríš ty. |
| E9 | Dostupnosť: krajiny, cena | ⚠️ | Mac a Vision Pro vypnúť (C1). |
| E10 | Export compliance | ✅ | Vyrieši kľúč v `Info.plist` (C25). |
| E11 | Accessibility Nutrition Labels | voliteľné | Môžeš vyplniť neskôr. |

### Návrh textov do App Store (16. 10. 2026, v1 bez trénera a zdieľaných videí)
**Podtitul** (do 30 znakov): Zostavy, tréningy a súťaže

**Promo text:** Zostavy na parkete, poznámky z lekcie a výsledky z KSIS v jednej appke. Pre tanečníkov a páry štandardných a latinskoamerických tancov.

**Popis:**
> Encore je tréningový denník pre tanečníkov a páry štandardných a latinskoamerických tancov.
>
> PARKET A ZOSTAVY
> • Poskladaj figúry na parkete tak, ako idú v sále, s dobami a smerom tanca.
> • Partner vidí tú istú zostavu a každú zmenu hneď.
> • Zostavu pošleš aj QR kódom.
>
> POZNÁMKY A VIDEO
> • Nadiktuj, čo tréner povedal. Encore to prepíše po slovensky a uloží k tancu alebo figúre.
> • Natoč figúru, video sa uloží do tvojich Fotiek.
>
> KALENDÁR
> • Týždenný režim, samotréningy, lekcie a súťaže na jednom mieste, aj v Apple Kalendári.
> • Po tréningu krátka reflexia, pripomienka uzávierky prihlášok.
>
> SÚŤAŽE
> • Výsledky a krížiky tvojho páru z verejného systému KSIS.
>
> NÁSTROJE
> • Zrkadlo, metronóm a hudba pomalšie bez zmeny tóniny.
>
> PLUS A PREMIUM
> • Plus: neobmedzené zostavy, Top 3 priority po lekcii, Moja sezóna (v ktorom tanci dostávaš najmenej krížikov a vývoj počas sezóny), súťažný deň (tance v poradí a pri každom tvoje Top 3) a strih hodinovej lekcie na figúry.
> • Premium: porovnanie tvojho videa so vzorom, olovnica, sklon ramien a korekcie uložené k figúre.
>
> Encore nie je oficiálna aplikácia SZTŠ. Výsledky pochádzajú z verejného systému KSIS.
> Predplatné sa obnovuje automaticky, zrušíš ho v Nastaveniach iPhonu.
> Podmienky: https://www.encore-sk.com/terms · Súkromie: https://www.encore-sk.com/privacy

**Popisy predplatného** (ako v `EncoreProducts.storekit`): Plus „Neobmedzené zostavy, Top 3 priority, strih lekcie“,
Premium „Porovnanie videa so vzorom a všetko z Plus“.
| E12 | Copyright riadok | ⚠️ | Napríklad „© 2026 Jakub Kalina“. |

## F. Testovanie pred odoslaním (TestFlight)

Zariadenia: najmenší iPhone, aký máš, plus najväčší (napríklad iPhone SE alebo 13 mini a 17 Pro Max), aspoň
jeden reálny iPhone s iOS z C15. Interní testeri hneď; externí testeri potrebujú beta review (1–2 dni).

- [ ] Registrácia e-mailom → overovací e-mail príde (C12) → prihlásenie
- [ ] Prihlásenie Google a Apple (C3), odhlásenie, zabudnuté heslo
- [ ] Face ID: zapnutie, zámok po 5 min na pozadí, odhlásenie zo zámku
- [ ] Domov: text, hlas, video → video je vo Fotkách v albume Encore
- [ ] Zostava: vytvorenie, figúry, poznámky s formátovaním, otočenie videa, duel
- [ ] Prepojenie s partnerom cez QR (skener v appke aj Fotoaparát, C7), spoločná zostava a poznámky naživo
- [ ] Žiadne stopy po trénerovi a zdieľaní videí (registrácia, Profil, Prepojenia, Nástroje, plátno ⋯, detail figúry, paywall)
- [ ] Nahlásenie a zrušenie prepojenia (C6)
- [ ] Plán: tréningy, súťaže, pridanie a hromadné odstránenie z Apple Kalendára
- [ ] KSIS: prepojenie páru, import výsledkov, body
- [ ] Predplatné v sandboxe: kúpa Plus, prechod na Premium, zrušenie, obnovenie nákupov, limit zostáv vo Free
- [ ] Stiahnuť moje dáta, zmazať účet (všetko zmizne, aj zdieľané videá)
- [ ] Bez internetu: appka nespadne, zobrazí zrozumiteľné správy
- [ ] Odmietnuté oprávnenia (kamera, mikrofón, Fotky, kalendár) → zrozumiteľné správy
- [ ] VoiceOver na hlavných obrazovkách, väčšie písmo (Dynamic Type), Znížiť pohyb
- [ ] Málo miesta v iPhone, dlhé video, prerušenie hovorom počas nahrávania
- [ ] Žiadne pády v Xcode → Organizer → Crashes

## G. Deň spustenia a potom

- [ ] Supabase Pro zapnutý, zálohy, limit výdavkov; upozornenie na výdavky v Cloudflare (5 $)
- [ ] Odoslať na review (zvyčajne 1–3 dni); pri zamietnutí odpovedať v Resolution Center
- [ ] Release: manuálne (aby si mal kontrolu nad dňom)
- [ ] Sledovať: Supabase logy funkcií, Cloudflare metriky, pády, recenzie, e-mail podpory
- [ ] `npx wrangler logout`, ak už Cloudflare cez Mac nepotrebuješ
- [ ] Plán 1.0.1 (opravy) a 1.1 (hodinky, `docs/WATCHOS_V1_1_PLAN.md`; krok 3 videí; poznámky a Plán na server)

---

## Rozhodnutia z 8. 10. 2026
- Paywall: funkcie **dorobíme** (`docs/V1_PAYWALL_FEATURES_PLAN.md`); kým nie sú hotové, paywall ich nespomenie.
- Peňaženka: dorobí sa po kúpe Developer účtu.
- Obrázky: nájdeš voľne použiteľné (Unsplash, Pexels; licencia dovoľuje komerčné použitie). Pre každý
  si zapíš odkaz, licenciu a dátum, bez rozpoznateľných ľudí a značiek.
- E-mail podpory: support@encore-sk.com (od 13. 10. 2026, appka, zásady a web). Cloudflare Email Routing ho preposiela do encore.support.sk@gmail.com. Prihlasovací účet majiteľa ostáva jakubkalina05@gmail.com.
- iOS 26.0: zmeníš v Xcode (target Encore → General → Minimum Deployments → 26.0), potom opravím, čo
  by vyžadovalo novší iOS. Liquid Glass je dostupný od 26.0.
- Vek: konzultujeme (pozri C19 a návrh nižšie).

### Návrh pre maloletých (C19), na konzultáciu s právnikom
- Účet si zakladá osoba **od 16 rokov**. Pre mladších (Deti, Junior) **účet založí a spravuje rodič**,
  ktorý ho používa spolu s dieťaťom. Pri registrácii: „Mám 16 rokov alebo zakladám účet pre svoje dieťa
  ako rodič.“
- Profil maloletého sa nezobrazuje vo vyhľadávaní tanečníkov.
- Nákupy rieši Apple (Rodinné zdieľanie, schválenie nákupu rodičom).
- Vekové hodnotenie v App Store podľa obsahu a sociálnych funkcií (pravdepodobne 13+).

## Čo čaká na tvoje rozhodnutie (potom to v kóde urobím)

1. **C2 paywall**: odstrániť neexistujúce funkcie (odporúčam) alebo niektorú dorobiť pred spustením?
2. **C8 Peňaženka**: dokončiť vo v1 (po kúpe účtu) alebo skryť?
3. **C10 obrázky**: máš licenciu, alebo ich nahradím kódom?
4. **C17 e-mail podpory**: ktorá adresa je skutočná?
5. **C19 vek**: 16+ alebo 13+ so súhlasom rodiča?
6. **C15 iOS**: 26.0 alebo 26.4?
7. **C1 iba iPhone**: zmeníš v Xcode (Supported Destinations)?
8. **C6, C7, C9, C12, C13, C14, C16, C18, C20**: môžem pripraviť (SQL a e-mailové nastavenie najprv ukážem)?
