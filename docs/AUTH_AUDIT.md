# Encore: audit prihlásenia, registrácie a účtu

> Dátum: 14. 10. 2026 (nahrádza audit z 5. 10.). Rozsah: `AuthManager`, `AuthSheetView`, `PasswordSheets`,
> `AuthSupport`, deep linky, e-mailové šablóny, živý Supabase projekt (triggery, funkcie, advisory, logy),
> doména `encore-sk.com` (Resend, Cloudflare Email Routing).
> Spôsob: čítanie kódu a servera + skutočný e-mail na obnovu hesla od Jakuba. Prihlásenie heslom a registráciu
> nového účtu som sám nespúšťal (produkčný server).

**Legenda:** ✅ funguje · 🛠 opravené v tomto audite · ⚠️ funguje, ale treba doladiť · ❌ nefunguje · 🔍 overiť na iPhone · 🧭 nastavenie v Dashboarde

## Skóre: 7 / 10 (5. 10. bolo 3 / 10)

| Oblasť | Skóre | Poznámka |
|---|---|---|
| Logika (registrácia, prihlásenie, kódy, relácia) | 8/10 | Po oprave kódu z e-mailu je tok správny. Chýbajú drobnosti nižšie. |
| Bezpečnosť | 7/10 | Potvrdenie e-mailu, vlastné SMTP, PKCE, odhlásenie ostatných zariadení po zmene hesla, mazanie účtu na serveri. Chýba kontrola uniknutých hesiel (Pro) a CAPTCHA. |
| Server a Dashboard | 7/10 | SMTP cez Resend funguje, URL sedia, `delete-account` beží. Treba overiť platnosť kódu a limity. |
| Vzhľad podľa §1A | 3/10 | Prihlasovacia obrazovka je stále starý „zlato na čiernom“ dizajn, okná používajú staré tlačidlá a pevné veľkosti písma. |

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
| R4 | E-mail patrí účtu z Google (bez hesla) | ⚠️ hláška „už existuje“ by mala poradiť „Pokračovať cez Google“ |
| R5 | Slabé, krátke alebo časté heslo | ✅ v appke; ⚠️ server nekontroluje uniknuté heslá (len plán Pro) |
| R6 | Prázdne alebo dlhé meno, nepotvrdený vek | ✅ |
| R7 | Bez internetu | ✅ slovenská hláška podľa kódu chyby |
| R8 | „Poslať kód znova“ hneď po registrácii | ⚠️ odpočet 30 s, server pustí až po 60 s → zbytočná chyba |
| R9 | Zavrie okno s kódom a chce sa k nemu vrátiť | ⚠️ dá sa len opätovným prihlásením; chýba „Zadať kód“ na prihlasovacej obrazovke |
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
| L4 | Účet vznikol cez Google, skúša heslo | ⚠️ len „nesprávne“, chýba rada „použi Google“ |
| L5 | Medzery a veľké písmená v e-maile | ✅ |
| L6 | Medzery v hesle | ✅ nemažú sa |
| L7 | Bez internetu, timeout, hotelová Wi-Fi | ✅ |
| L8 | Veľa pokusov | ✅ hláška pri limite |
| L9 | Zablokovaný účet | ✅ |
| L10 | Return na klávesnici, automatické dopĺňanie hesiel | ✅; ⚠️ bez `webcredentials` iCloud Kľúčenka neprepojí heslá s webom (až po webe na encore-sk.com) |
| L11 | Face ID prihlásenie | ✅; ⚠️ niektoré hlášky píšu „Face ID“ aj na Touch ID |
| L12 | Spustenie appky offline | ✅ relácia ostane, nikdy sa neodhlási kvôli sieti |
| L13 | Preinštalovanie appky | ✅ začína odhlásená |
| L14 | Iný účet na tom istom iPhone | ✅ dáta predchádzajúceho sa odstránia |
| L15 | Zámok po 5 min v pozadí | ✅ |

### Google a Apple
| # | Situácia | Stav |
|---|---|---|
| G1 | Prihlásenie z okna aj z celej obrazovky | ✅ |
| G2 | Zrušenie | ✅ bez chyby |
| G3 | Chyba Google | ⚠️ ukáže surový text (môže byť anglicky); hláška spomína „Continue with Google“ |
| G4 | Google s e-mailom existujúceho účtu | ✅ prepojí sa (bezpečné, lebo e-maily sa potvrdzujú) |
| G5 | Cudzí človek, Google v stave „Testing“ | ❌ 🧭 prihlási sa len pridaný tester (A10 v launch checkliste) |
| A1 | Sign in with Apple | ⚠️ kód hotový, skrytý; App Store ho vyžaduje → capability + Supabase provider |

### Obnova a zmena hesla
| # | Situácia | Stav |
|---|---|---|
| P1 | E-mail → kód → nové heslo | ✅ po oprave kódu |
| P2 | Neznámy e-mail | ✅ rovnaká odpoveď, nedá sa zistiť, kto má účet |
| P3 | Tlačidlo v e-maile na tom istom iPhone | ✅ |
| P4 | „Preskočiť“ nové heslo | ⚠️ ostane prihlásený bez známeho hesla (zmení si ho v Profile) |
| P5 | Po zmene hesla | ✅ ostatné zariadenia sa odhlásia |
| P6 | Zmena hesla v Profile | ✅ chce súčasné heslo; Google účtom sa neponúka |

### Účet
| # | Situácia | Stav |
|---|---|---|
| D1 | Zmazanie účtu | ✅ funkcia `delete-account` beží; appka čaká na potvrdenie servera |
| D2 | Odhlásenie | ✅ len tento iPhone |
| D3 | Zmazanie pri Apple účte | ⚠️ odvolanie Apple tokenu doplniť spolu s Apple prihlásením |

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

## Vzhľad podľa §1A (nesedí)
1. Prihlasovacia obrazovka: čierne pozadie so zlatou žiarou a ťažká karta so zlatým rámom = starý dizajn. Má byť zamat + sklenená karta.
2. Výber Tanečník / Tréner je systémový segmentový ovládač. Má byť rad kapsúl s presúvajúcou sa výplňou.
3. Prepínanie Prihlásenie / Registrácia je odkaz dole. Lepšie: kapsuly hore.
4. Polia: tmavé so zlatým rámom. Majú byť sklenené so zlatou čiarou pri písaní (ako editory v Pláne).
5. Okná (kód, obnova, nové heslo): staré textové tlačidlá „Zavrieť / Preskočiť“, pevné veľkosti písma, nejednotné „Zatvoriť“ vs. „Zavrieť“.
6. Zaškrtávacie políčko veku: obyčajný štvorček. Lepšie animovaný prepínač.
7. Mikrointerakcie: chýba zatrasenie pri chybe a jasné potvrdenie úspechu.
