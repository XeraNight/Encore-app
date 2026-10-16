# Tab Kalendár (predtým Plán): audit situácií

> 15. 10. 2026. Prejdené: `DancePlannerView`, `PlannerTodayView`, `PlannerCalendarView`, `PlannerRoutineView`,
> `PlannerSessionViews`, `PlannerCompetitionsView`, `PlannerEditorComponents`, `PlannerModels`,
> `PlannerServices`, `DebriefSheet`, `MonthCalendarCard`, `LocalDataGuard`, pridanie súťaže z KSIS.
> Overené čítaním kódu, posun času aj skriptom a testom.

✅ funguje · ❌ chyba · ⚠️ slabé miesto · 🔧 už opravené

## A. Čas a dátum
| # | Situácia | Stav |
|---|---|---|
| S1 | Tréning v nedeľu 25. 10. 2026 o 18:00 (posun času) | 🔧 ukazoval 17:00, pripomienka o hodinu skôr, séria v Apple Kalendári vytvorená v ten deň posunutá navždy. Opravené + test. |
| S2 | Samotréning na 25. 10. o 17:00 | 🔧 uložil sa ako 16:00 (to isté ako S1). |
| S3 | Tréning cez polnoc (22:30–0:30) | ✅ čas aj pripomienka po skončení idú na ďalší deň. |
| S4 | Appka ostane otvorená cez polnoc | ⚠️ Dnes ukazuje včerajšie tréningy a dátum, kým na niečo neťukneš. |
| S5 | Tréning zapísaný spätne (včera bez plánu) | ✅ cez Pridať v kalendári, aj s reflexiou. |
| S6 | Uzávierka prihlášok neskôr ako súťaž | ⚠️ dá sa uložiť. |
| S7 | Súťaž z KSIS bez dátumu | ⚠️ potichu sa uloží na dnes. |
| S8 | Súťaž v zahraničí, iné časové pásmo (Blackpool) | ⚠️ dni sa rátajú od polnoci na Slovensku, v Londýne sa môžu posunúť o deň. Zatiaľ nechať. |

## B. Týždenný režim
| # | Situácia | Stav |
|---|---|---|
| S9 | Včera som zabudol ťuknúť Idem alebo zapísať reflexiu | ❌ včerajší tréning v kalendári **zmizne**. Minulé dni ukazujú týždenný tréning len vtedy, keď si pri ňom niečo zapísal, takže reflexiu nemáš kam zapísať. |
| S10 | Ťuknem na notifikáciu „Tréning skončil“ | ❌ appka sa otvorí tam, kde bola, nie na reflexii. Sľub „za 20 sekúnd“ neplatí. |
| S11 | Štatistika Tento týždeň | ❌ dnešný neoznačený tréning sa po skončení ráta ako odtrénovaný, no zajtra vypadne z odtrénovaných aj z plánu. Čísla cez noc klesnú. |
| S12 | Zmením deň tréningu (utorok → streda) | ❌ staré utorky aj s reflexiami zmiznú z kalendára. |
| S13 | Zmažem týždenný tréning | ❌ text hovorí „Zapísané reflexie ostanú“, no v kalendári ich už nevidno. Ostanú len v Poznámkach a v Posledných reflexiách. |
| S14 | Letná pauza: vypnem tréning prepínačom | ⚠️ v appke zmizne, ale Apple Kalendár ďalej pripomína. |
| S15 | Upravím čas tréningu, ktorý je v Apple Kalendári | ⚠️ séria sa vytvorí nanovo a dni, ktoré som zrušil (Nejdem), sa v Apple Kalendári znova objavia. Pravdepodobne zmizne aj minulá história série. |
| S16 | Nejdem → Vrátiť | ✅ zmizne z Apple Kalendára a vráti sa ako samostatná udalosť. |
| S17 | Dva tréningy v rovnaký čas | ✅ dovolí (napr. dve sály), bez upozornenia. |
| S18 | „Dnes máš voľno – Najbližší tréning“ | ⚠️ ignoruje samotréningy a lekcie a ukáže aj tréning, ktorý som už zrušil. |
| S19 | Podržanie → Zmazať (tréning aj súťaž) | ⚠️ zmaže bez potvrdenia, nedá sa vrátiť. |
| S20 | Hromadné mazanie | ✅ s potvrdením, aj z Apple Kalendára. |

## C. Samotréning a lekcia
| # | Situácia | Stav |
|---|---|---|
| S21 | Zmažem samotréning, ktorý má reflexiu | ❌ ako S13, reflexia v kalendári zmizne. |
| S22 | Presuniem samotréning s reflexiou na iný deň | ⚠️ reflexia ostane pod pôvodným dátumom. |
| S23 | Cieľ z Top 3 → Splnené, neskôr zmením na Čiastočne | ⚠️ priorita ostane odškrtnutá. |
| S24 | Dvakrát rýchlo ťuknem na Uložiť | ⚠️ môžu vzniknúť dva rovnaké tréningy alebo súťaže. |
| S25 | Editor zatvorím potiahnutím dole | ⚠️ zmeny sa stratia bez otázky. |
| S26 | Samotréning bez cieľa | ✅ cieľ sa dá doplniť neskôr aj v reflexii. |

## D. Súťaže
| # | Situácia | Stav |
|---|---|---|
| S27 | Prepnem súťaž na Neidem | ⚠️ udalosť v Apple Kalendári ostane (pri tréningu ju Nejdem maže). |
| S28 | Upravím súťaž pridanú z KSIS | ⚠️ presné kategórie („Dospelí D ŠTT“) sa prepíšu na „Štandard“. |
| S29 | Text „Zoznam turnajov z KSIS … pribudnú neskôr“ | ⚠️ pridanie z KSIS už existuje a Apple nemá rád „čoskoro“ v appke. Zmazať. |
| S30 | Po pár sezónach | ⚠️ zoznam Minulé rastie donekonečna. |
| S31 | Odtancovaná súťaž s výsledkom z KSIS | ✅ namiesto Idem ukáže umiestnenie. |
| S32 | Tá istá súťaž z KSIS pridaná dvakrát | ✅ nájde ju podľa názvu a dňa, nevznikne duplikát. |

## E. Reflexia
| # | Situácia | Stav |
|---|---|---|
| S33 | Napíšem pár viet, potom diktujem | ❌ diktát **prepíše** napísané (pri úprave aj starú reflexiu). |
| S34 | Diktovanie bez povolenia mikrofónu | ⚠️ nič sa nestane, žiadna hláška. |
| S35 | Potiahnem reflexiu dole alebo Zrušiť | ⚠️ napísaný text sa stratí bez otázky. |
| S36 | Reflexia včerajšieho tréningu | ⚠️ nadpis „Čo kľúčové ste **dnes** vylepšili?“. |
| S37 | Vymažem text reflexie | ⚠️ poznámka v Poznámkach ostane so starým textom. |
| S38 | Top 3 bez Plus | ✅ zámok a paywall. |

## F. Pripomienky a povolenia
| # | Situácia | Stav |
|---|---|---|
| S39 | Notifikácie som zamietol | ⚠️ Plán nič nepovie, pripomienky potichu nechodia. |
| S40 | Prístup ku kalendáru som zamietol | ⚠️ prepínač „V Apple Kalendári“ sa potichu nevykoná. |
| S41 | Appku 14 dní neotvorím | ⚠️ pripomienky sa plánujú 14 dní dopredu, potom prestanú. Zatiaľ nechať. |
| S42 | Reflexiu zapíšem ešte pred koncom tréningu | ⚠️ „Tréning skončil“ aj tak príde. |
| S43 | Notifikácia po lekcii | ⚠️ „Lekcia skončil“ (zlý rod). |

## G. Účet a dáta
| # | Situácia | Stav |
|---|---|---|
| S44 | Na iPhone sa prihlási iný účet | 🔧 samotréningy a lekcie predošlého človeka ostávali a chodili jeho pripomienky. Opravené. |
| S45 | Nový iPhone alebo preinštalovanie | ⚠️ Plán nie je v cloude, prenesie sa len zálohou iPhonu. Vedome (osobné dáta). |
| S46 | Export mojich dát | ✅ obsahuje režim, tréningy, súťaže aj Top 3. |

## H. Vzhľad (§1A)
| # | Situácia | Stav |
|---|---|---|
| S47 | Väčšie písmo v iPhone | ⚠️ 43 pevných veľkostí písma (Dnes, Režim, Súťaže, Reflexia, prepínač sekcií). |
| S48 | Dva štýly kariet | ⚠️ staré `plannerCard` vedľa §1A `homeCard`. |
| S49 | Názov „Plán“ | ⚠️ koliduje s plánmi predplatného (Free, Plus, Premium) a vnútri je ešte sekcia Kalendár. |

## Návrh: premenovať na Kalendár
Tab **Kalendár**, nadpis KALENDÁR, sekcie **Dnes · Mesiac · Režim**. Texty „Zmizne z Plánu“ → „Zmizne z Encore aj z Apple Kalendára“,
„Pridať do Plánu“ (KSIS) → „Pridať do kalendára“, „v Pláne“ (Top 3) → „v Kalendári“.

## Plán opráv (každý krok samostatne, build a testy po každom)
1. **Minulé tréningy (S9, S11–S13, S21, S22):** týždenný tréning sa ukáže aj spätne (od dňa, keď si ho pridal; nové lokálne pole `createdAt`, nič v Supabase). Zapísané dni ostanú na svojom mieste, aj keď tréning presunieš alebo zmažeš. Štatistika z rovnakých dát.
2. **Notifikácia → reflexia (S10, S42, S43):** ťuk otvorí Kalendár a reflexiu toho tréningu. Po zapísanej reflexii nepríde. Text bez rodu.
3. **Apple Kalendár (S14, S15, S27, S40):** pauza tréningu ho z kalendára zoberie a zapnutie vráti; úprava nevráti zrušené dni; Neidem pri súťaži zmaže udalosť; hláška, keď chýba prístup.
4. **Reflexia (S33–S37):** diktát sa pridá za text, chyba mikrofónu sa ukáže, pri zatvorení s textom sa opýta, nadpis podľa dňa, prázdny text zmaže poznámku.
5. **Editory (S6, S19, S23–S25, S28):** jedno uloženie, uzávierka najneskôr v deň súťaže, KSIS kategórie ostanú, potvrdenie pri mazaní podržaním, otázka pri zatvorení so zmenami.
6. **Dnes (S4, S18):** obnova o polnoci, najbližší tréning vrátane samotréningov a bez zrušených. **Notifikácie (S39):** jemná karta, keď sú vypnuté.
7. **Vzhľad a názov (S29, S30, S47–S49):** textové štýly, jeden štýl kariet, premenovanie na Kalendár, minulé súťaže len z tejto sezóny + Zobraziť všetky.

## Stav po opravách (16. 10. 2026)
**Opravené:** S1, S2, S4, S6, S7, S9–S15, S18, S19, S21–S25, S27–S30, S33–S37, S39, S40, S42–S44, S47–S49.
Tab sa volá **Kalendár** (Dnes · Mesiac · Režim). Navyše: texty len v mužskom rode („Nebol som“, „čo si sa naučil“) sú neutrálne.

**Vedome nechané:** S8 (iné časové pásmo), S41 (pripomienky 14 dní dopredu), S45 (Kalendár nie je v cloude).

**Overené:** build bez varovaní, všetky testy (nové: posun času, ktoré tréningy deň ukazuje, notifikácia → tréning),
obrazovky Dnes, Mesiac, Režim a Súťaže vyrenderované s ukážkovými dátami.
**Neoverené naživo:** Apple Kalendár (pauza, úprava, Nejdem, Neidem), ťuk na notifikáciu, zatváranie editorov.
Treba vyskúšať na iPhone, appka bez prihlásenia v simulátore nejde.

## Kritický pohľad
1. **Kalendár je len tvoj.** Tanec je párový šport, ale partner si musí tie isté tréningy zadať sám a reflexie ani Top 3
   nevidí ani on, ani tréner. Toto je najväčšia medzera tabu. Riešenie potrebuje tabuľky v Supabase s RLS pre pár.
2. **Dáta sú len v telefóne.** Zostavy sa synchronizujú, Kalendár nie. Nový iPhone bez zálohy = prázdny Kalendár.
   Pri platenej appke to ľudia budú brať ako chybu.
3. **Dnes a Mesiac sa prekrývajú.** Mesiac s vybraným dneškom ukazuje tie isté karty ako Dnes. Jednoduchšie: jeden
   Kalendár (mesiac hore, deň pod ním, Top 3 a štatistika nad ním) a Režim. Menej prepínania, menej pojmov.
4. **Idem nič nerobí.** Je to len štítok. Buď ho zmysluplniť (dá vedieť partnerovi), alebo nechať len Vynechať / Nejdem.
5. **Štatistika je optimistická.** Nepotvrdený tréning sa po skončení ráta ako odtrénovaný. Je to konzistentné, ale
   čísla môžu klamať. Poctivejšie by bolo rátať len Idem a reflexie.
6. **Veľa pojmov naraz.** Režim, samotréning, lekcia, súťaž, Idem/Nejdem, reflexia, cieľ, Top 3, pocit. Nový používateľ
   potrebuje krátke uvedenie alebo menej vecí na Dnes.
7. **Apple Kalendár je najkrehkejšia časť.** Dve rôzne žiadosti o prístup (zápis, potom plný prístup pri mazaní) a zmeny
   série sa nedajú otestovať bez zariadenia.
8. **Testovateľnosť.** Bez prihlásenia sa appka nedá pustiť, takže UI sa overuje len čítaním kódu a renderom.
   Pomohol by demo režim len pre DEBUG build s ukážkovými dátami.
9. **Rod v celej appke.** V Kalendári je opravený, inde v appke môžu byť ďalšie texty len v mužskom rode.

Hodnotenie: pred auditom asi 5/10, teraz 7,5/10. Na 9+ treba bod 1 a 2 (pár a cloud) a zjednodušiť Dnes a Mesiac.
