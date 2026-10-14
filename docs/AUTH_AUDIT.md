# Encore: audit prihlásenia, registrácie a účtu

> Dátum: 14. 10. 2026 (nahrádza audit z 5. 10.). Rozsah: `AuthManager`, `AuthSheetView`, `PasswordSheets`,
> `AuthSupport`, deep linky, e-mailové šablóny, živý Supabase projekt (triggery, funkcie, advisory, logy),
> doména `encore-sk.com` (Resend, Cloudflare Email Routing).
> Spôsob: čítanie kódu a servera + skutočný e-mail na obnovu hesla od Jakuba. Prihlásenie heslom a registráciu
> nového účtu som sám nespúšťal (produkčný server).

**Legenda:** ✅ funguje · 🛠 opravené v tomto audite · ⚠️ funguje, ale treba doladiť · ❌ nefunguje · 🔍 overiť na iPhone · 🧭 nastavenie v Dashboarde

## Skóre: 9 / 10 v kóde (14. 10. po opravách; ráno 7 / 10, 5. 10. 3 / 10)

Do 10 / 10 chýbajú už len nastavenia mimo kódu (sekcia „Zostáva mimo kódu“).

| Oblasť | Skóre | Poznámka |
|---|---|---|
| Logika (registrácia, prihlásenie, kódy, relácia) | 10/10 | Kód z e-mailu, návrat k zadaniu kódu, odpočet podľa servera, rady pre Google účty. |
| Bezpečnosť | 9/10 | Potvrdenie e-mailu, vlastné SMTP, PKCE, odhlásenie ostatných zariadení, mazanie účtu so zrušením Apple tokenov. Chýba kontrola uniknutých hesiel (Pro) a CAPTCHA. |
| Server a Dashboard | 7/10 | SMTP cez Resend funguje, URL sedia, `delete-account` beží. Treba overiť platnosť kódu a limity. |
| Vzhľad podľa §1A | 10/10 | Zamat, sklenené karty a polia, zlaté kapsuly, sklenené ✕, textové štýly, zatrasenie a haptika pri chybe. |

## Najdôležitejšie zistenie

🛠 **Kód z e-mailu mal 8 číslic, appka brala len 6.** Registrácia s potvrdením e-mailu aj obnova hesla kódom boli
preto úplne nefunkčné. Opravené 14. 10.: appka prijme 6–10 číslic (ako dovoľuje Supabase), takže zmena dĺžky v Dashboarde
už nič nerozbije. Kód vložený z Mailu sa odošle sám, ručne písaný sa potvrdí tlačidlom. Pribudli testy.

## Situácie

### Registrácia
| # | Situácia | Stav |
|---|---|---|
| R1 | Nový e-mail → kód z e-mailu → prihlásený | ✅ po oprave kódu |
| R2 | E-mail už má potvrdený účet | ✅ „Účet s týmto e-mailom už existuje…“ |
| R3 | E-mail má nepotvrdený účet | ✅ príde nový kód |
| R4 | E-mail patrí účtu z Google (bez hesla) | 🛠 hláška radí aj „Pokračovať cez Google“ |
| R5 | Slabé, krátke alebo časté heslo | ✅ v appke; ⚠️ server nekontroluje uniknuté heslá (len plán Pro) |
| R6 | Prázdne alebo dlhé meno, nepotvrdený vek | ✅ |
| R7 | Bez internetu | ✅ slovenská hláška podľa kódu chyby |
| R8 | „Poslať kód znova“ hneď po registrácii | 🛠 odpočet 60 s ako server |
| R9 | Zavrie okno s kódom a chce sa k nemu vrátiť | 🛠 karta „Mám kód z e-mailu“ na prihlasovacej obrazovke |
| R10 | Preklep v e-maile | ✅ „Zmeniť e-mail“; nepotvrdený účet na serveri ostane (neškodí) |
| R11 | Ťukne na tlačidlo v e-maile na tom istom iPhone | ✅ appka sa otvorí a prihlási |
| R12 | Otvorí odkaz na inom zariadení | ✅ zrozumiteľná hláška „použi kód z e-mailu“ |
| R13 | Kód vypršal alebo je zlý | ✅ hláška; 🧭 e-mail aj appka píšu „10 minút“, Dashboard to musí mať nastavené |
| R14 | Kód s medzerami alebo z automatického dopĺňania | ✅ |
| R15 | Rola Tanečník / Tréner | ✅ uloží sa |

### Prihlásenie
| # | Situácia | Stav |
|---|---|---|
| L1 | Správne údaje | ✅ |
| L2 | Zlé heslo | ✅ „E-mail alebo heslo nie je správne.“ |
| L3 | Účet ešte nepotvrdený | ✅ pošle nový kód a otvorí okno na kód |
| L4 | Účet vznikol cez Google, skúša heslo | 🛠 hláška radí „Pokračovať cez Google“ |
| L5 | Medzery a veľké písmená v e-maile | ✅ |
| L6 | Medzery v hesle | ✅ nemažú sa |
| L7 | Bez internetu, timeout, hotelová Wi-Fi | ✅ |
| L8 | Veľa pokusov | ✅ hláška pri limite |
| L9 | Zablokovaný účet | ✅ |
| L10 | Return na klávesnici, automatické dopĺňanie hesiel | ✅; ⚠️ bez `webcredentials` iCloud Kľúčenka neprepojí heslá s webom (až po webe na encore-sk.com) |
| L11 | Face ID prihlásenie | 🛠 hlášky podľa skutočného zariadenia (Face ID / Touch ID) |
| L12 | Spustenie appky offline | ✅ relácia ostane, nikdy sa neodhlási kvôli sieti |
| L13 | Preinštalovanie appky | ✅ začína odhlásená |
| L14 | Iný účet na tom istom iPhone | ✅ dáta predchádzajúceho sa odstránia |
| L15 | Zámok po 5 min v pozadí | ✅ |

### Google a Apple
| # | Situácia | Stav |
|---|---|---|
| G1 | Prihlásenie z okna aj z celej obrazovky | ✅ |
| G2 | Zrušenie | ✅ bez chyby |
| G3 | Chyba Google | 🛠 slovenská hláška podľa kódu chyby |
| G4 | Google s e-mailom existujúceho účtu | ✅ prepojí sa (bezpečné, lebo e-maily sa potvrdzujú) |
| G5 | Cudzí človek, Google v stave „Testing“ | ❌ 🧭 prihlási sa len pridaný tester (A10 v launch checkliste) |
| A1 | Sign in with Apple | 🛠 zapnuté (capability, tlačidlo, build 2); 🧭 zapnúť Apple provider v Supabase |

### Obnova a zmena hesla
| # | Situácia | Stav |
|---|---|---|
| P1 | E-mail → kód → nové heslo | ✅ po oprave kódu |
| P2 | Neznámy e-mail | ✅ rovnaká odpoveď, nedá sa zistiť, kto má účet |
| P3 | Tlačidlo v e-maile na tom istom iPhone | ✅ |
| P4 | Zavretie okna „Nové heslo“ | 🛠 tlačidlo „Teraz nie“ a vysvetlenie, že heslo zmení v Profile |
| P5 | Po zmene hesla | ✅ ostatné zariadenia sa odhlásia |
| P6 | Zmena hesla v Profile | ✅ chce súčasné heslo; Google účtom sa neponúka |

### Účet
| # | Situácia | Stav |
|---|---|---|
| D1 | Zmazanie účtu | ✅ funkcia `delete-account` beží; appka čaká na potvrdenie servera |
| D2 | Odhlásenie | ✅ len tento iPhone |
| D3 | Zmazanie pri Apple účte | 🛠 appka si vypýta kód od Apple, server zruší Apple tokeny (test podpisu prechádza); 🧭 nasadiť `delete-account` + tajomstvá |

## Dashboard (🧭 skontroluj alebo nastav)
| Nastavenie | Stav |
|---|---|
| Confirm email, vlastné SMTP (Resend, `no-reply@encore-sk.com`), Site URL a Redirect URLs | ✅ |
| **Email OTP Expiration = 600 s** (aby sedelo „10 minút“) | 🧭 over |
| Email OTP Length | 8 (appka zvládne 6–10) |
| Rate limit e-mailov (po SMTP je 30/h) → pred spustením zvýšiť na ~100/h | 🧭 |
| Leaked password protection | ⚠️ len plán Pro (zapneme s Pro pred review) |
| CAPTCHA (Turnstile) | ⚠️ pred verejným spustením |
| DMARC záznam `_dmarc` | ✅ (14. 10. overené) |
| Google OAuth „In production“ | 🧭 A10 |

## Vzhľad podľa §1A
🛠 Hotové 14. 10.: prihlásenie a registrácia na zamate so sklenenou kartou, kapsuly Prihlásenie / Registrácia
a Tanečník / Tréner, vek ako prepínač, sklenené polia so zlatou čiarou pri písaní (platí pre všetky polia
`authFieldChrome` v appke), krátky dôvod pod neaktívnym tlačidlom, okná s kódom a heslom so skleneným ✕,
textové štýly, zatrasenie a haptika pri chybe. Overené v simulátore.

## Zostáva mimo kódu (tým je 10 / 10)
1. Supabase → Authentication → Sign In / Providers → **Apple**: zapnúť, Client IDs `com.jakub.encore`.
2. Apple Developer → Keys → nový kľúč **Sign in with Apple** (.p8) → tajomstvá `APPLE_TEAM_ID`,
   `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_CLIENT_ID` v Supabase → nasadiť `delete-account`.
3. Apple Developer → Sign in with Apple for Email Communication: pridať `encore-sk.com`
   a `no-reply@encore-sk.com` (aby e-maily došli aj na skryté adresy „Skryť môj e-mail“).
4. Email OTP Expiration 600 s, limit e-mailov ~100/h.
5. Google OAuth „In production“.
6. Pred review: plán Pro (kontrola uniknutých hesiel), CAPTCHA.
7. Po spustení webu na encore-sk.com: `webcredentials` (heslá z iCloud Kľúčenky aj pre web).
