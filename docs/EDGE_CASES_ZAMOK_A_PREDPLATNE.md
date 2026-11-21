# Zámok Face ID a predplatné: scenáre a stav kódu

Stav z 21. 11. 2026: audit kódu a databázy, zámok skúšaný v simulátore, potom opravy (commity d47bd88, 02f09de, bb9d6a1, 41a3af9) a testy. Slúži aj ako kontrolný zoznam na telefóne.

Značky: **[test]** automatický test existuje · **[kód]** overené čítaním kódu, bez testu · **[CHYBA]** kód to dnes robí zle (oprava je v návrhu) · **[iPhone]** dá sa overiť len na telefóne (TestFlight, sandbox) · **[plán]** test sa dopíše pri oprave.

Základ pred zmenami: 264 testov prešlo, 0 zlyhalo. Po zmenách: 283 po oprave zámku, plus testy predplatného (SubscriptionRefreshTests 11, PaywallActionTests 5).

**[opravené]** znamená opravené a pokryté testom alebo overené kódom; riadky s **[iPhone]** treba ešte skúsiť na skutočnom telefóne (hlavne A5: Face ID výzva, tlačidlo bokom, prebudiť).

## A. Zámok Face ID

| # | Scenár | Má sa stať | Stav |
|---|---|---|---|
| A1 | Studený štart, Face ID zapnuté, relácia existuje | zámok pred sieťou, Face ID sa spýta hneď | [kód] [iPhone] |
| A2 | Studený štart, Face ID vypnuté | bez zámku | [kód] |
| A3 | V pozadí menej ako 5 minút | bez zámku | [kód] |
| A4 | V pozadí viac ako 5 minút | zámok a výzva | **[opravené]** [test] `AppLockStateTests` (cesta cez `newPhase == .active`, `leftForBackground`) [iPhone] |
| A5 | Obrazovka sa vypne počas výzvy | systém výzvu zruší (−4), po návrate sa Face ID spýta samo | **[opravené]** [test] `theScreenSwitchedOffWhileTheSheetWaitsAsksAgainOnWaking`: po prebudení sa Face ID spýta samo [iPhone] |
| A6 | Zrušiť v okne Face ID | zostane zamknuté, tlačidlo funguje, samo sa nič neopakuje | [kód] [iPhone] |
| A7 | Rýchle dvojité ťuknutie na tlačidlo | jedna výzva, druhé ťuknutie začne novú | **[opravené]** [test] každé ťuknutie je nová otázka, čakajúcu zruší (`aTapWhileASheetWaitsDismissesItAndOnlyTheNewAnswerCounts`) |
| A8 | Čakajúca výzva sa nevráti | tlačidlo ju zruší a spustí novú | **[opravené]** [test] `OwnerCheck` drží kontext a volá `invalidate()` |
| A9 | Appka ide do pozadia počas výzvy | výzva sa zruší, po návrate nová | **[opravené]** [test] `appDidEnterBackground` zruší čakajúcu výzvu a nová je dlžná po návrate |
| A10 | iPhone nemá kód | odomkne sa bez overenia (zdokumentované rozhodnutie) | [kód], [plán] |
| A11 | Overenie zlyhá z iného dôvodu (`canEvaluatePolicy` nie, `notInteractive`, −1000) | zostane zamknuté, riadok s kódom chyby | **[opravené]** [test] `errorsAreSortedIntoWhatTheLockDoesNext`: otvorí len `passcodeNotSet`, inak ostane zamknuté a zámok ukáže kód chyby |
| A12 | Pomalá sieť, odomknuté skôr ako odpovie server | nezamkne sa druhýkrát | **[opravené]** [test] `theSlowNetworkCheckDoesNotLockAUserWhoAlreadyUnlocked` |
| A13 | Odhlásiť sa zo zámku | zámok zmizne, prihlasovacia obrazovka | [kód] |
| A14 | Zapnutie Face ID v Nastaveniach | najprv overenie, zámok hneď nenaskočí | [kód] [iPhone] |
| A15 | Zmazanie účtu: zrušené overenie | nič sa nezmaže | [kód], [plán] |
| A16 | Názov a ikona biometrie | načítané raz, nie v tele pohľadu | **[opravené]** [kód] typ biometrie sa číta raz mimo hlavného vlákna (`refreshBiometryType`), pohľady čítajú uloženú hodnotu |
| A17 | Face ID okno systému robí scénu `.inactive` | po zatvorení okna sa výzva sama neopakuje (inak donekonečna) | **[opravené]** [test] `aCancelledQuestionIsNotAskedAgainUntilEncoreHasBeenAway`: automaticky len po návrate z pozadia |
| A18 | VoiceOver a veľké písmo na zámku | tlačidlo čitateľné, riadok s chybou prečítaný | [iPhone] |

## B. Predplatné: nákup

| # | Scenár | Má sa stať | Stav |
|---|---|---|---|
| B1 | Kúpa Plus mesačne a ročne | plán Plus | [iPhone] |
| B2 | Kúpa Premium mesačne a ročne | plán Premium | [iPhone] |
| B3 | Upgrade Plus na Premium | hneď Premium | [iPhone] |
| B4 | Nižší plán kúpený pri vyššom | platí od obnovenia, appka to povie | [kód] Apple to rieši sám (zmena platí od obnovenia); vysvetľujúca správa v appke sa zámerne nepridáva |
| B5 | Z mesačného na ročné (rovnaký plán) | paywall to ponúkne | **[opravené]** [test] `PaywallActionTests`: rozhoduje produkt, mesačný môže prejsť na ročný |
| B6 | Zrušené okno nákupu | bez správy a bez zmeny | [kód] |
| B7 | Ask to Buy | správa „čaká na schválenie", po schválení Plus cez `Transaction.updates` | **[opravené]** [kód] `PurchaseOutcome.pending` ukáže správu „Nákup čaká na schválenie“; plán príde cez `Transaction.updates` [iPhone] |
| B8 | Platba alebo sieť zlyhá | správa s dôvodom | [kód] |
| B9 | Dvojité ťuknutie na kúpu | jeden nákup | **[opravené]** [kód] `purchase` ignoruje druhé ťuknutie, kým beží prvé; tlačidlo je počas nákupu aj vypnuté |
| B10 | Nákup bez siete | chyba z App Store | [iPhone] |

## C. Predplatné: životný cyklus

| # | Scenár | Má sa stať | Stav |
|---|---|---|---|
| C1 | Automatické obnovenie | plán zostane | [iPhone] |
| C2 | Vypnuté automatické obnovenie | platí do konca obdobia | [iPhone] |
| C3 | Predplatné skončí, kým appka beží alebo je v pozadí | po návrate Free | **[opravené]** [kód] obnova plánu beží po každom skutočnom návrate z pozadia (najviac raz za 10 minút) a `Product.SubscriptionInfo.Status.updates` hlási aj koniec predplatného [iPhone] |
| C4 | Vrátenie peňazí | Free | [kód] (`revocationDate`), [iPhone] |
| C5 | Problém s platbou (billing retry) bez a s odkladom | Free, resp. zostane | [iPhone] |
| C6 | „Obnoviť nákupy" na novom iPhone | Plus, zreteľná odozva | **[opravené]** [kód] `RestoreOutcome.restored` ukáže „Nákupy sa obnovili. Máš plán …“, počas čakania je spinner |
| C7 | „Obnoviť nákupy" bez nákupu | „Nenašli sme žiadne predplatné" | **[opravené]** [kód] `RestoreOutcome.nothingToRestore` ukáže „V tomto Apple ID sme nenašli žiadne predplatné“ |
| C8 | Preinštalovanie | plán späť zo StoreKit | [iPhone] |

## D. Účty, server a darované plány

| # | Scenár | Má sa stať | Stav |
|---|---|---|---|
| D1 | Majiteľ appky | Premium, zdroj `appOwner` | [kód] |
| D2 | Dar Plus na 30 dní, potom koniec | Plus, po expirácii Free | [test] `aGiftCountsOnlyWhileItLasts` |
| D3 | Dar odobratý (server nemá riadok, alebo má riadok `free`) | Free | [test] `theOwnersGiftSurvivesAMissingSignalButNotAnAnswer` (bez riadku), riadok `free` [kód] |
| D4 | Server nedostupný | dar sa drží najviac 30 dní, kúpený plán nikdy zo starej odpovede | [test] tri testy v `EntitlementTests` |
| D5 | Riadok so zdrojom `storekit` na serveri | nič nedokazuje | [test] `aRowThatSaysStoreKitProvesNothing` |
| D6 | Dar a kúpa naraz | vyšší plán | [test] `theHigherOfTheTwoWins` |
| D7 | Dar a kúpa rovnakej úrovne | zdroj zostane StoreKit, „Zmeniť alebo zrušiť" ostane | **[opravené]** [kód] „Zmeniť alebo zrušiť“ sleduje `activeProductID`, takže ostane aj pod darom rovnakej úrovne (zdroj plánu ostáva dar, je to zámer) |
| D8 | Zablokovaný účet | Free a oznam | [kód] |
| D9 | Starý názov „studio" v dare | Premium | [test] `oldStudioNameStillMeansPremium` |
| D10 | Neznáma hodnota plánu zo servera | Free | [kód] |
| D11 | Formát `expires_at` (mikrosekundy a podobne) | dátum sa prečíta | overené skriptom 21. 11. (všetky formáty PostgREST) |
| D12 | Prepnutie účtu počas bežiacej kontroly plánu | výsledok starého účtu sa zahodí | **[opravené]** [test] `anAccountSwitchInTheMiddleOfACheckPublishesNothingForTheOldAccount` |
| D13 | Dve kontroly plánu sa predbehnú | platí najnovšia | **[opravené]** [test] `aSlowCheckThatANewerOneOvertookChangesNothing` |
| D14 | Klient zapisuje do `user_entitlements` | nesmie | overené v databáze: len SELECT politika; `record_app_store_transaction` a `shared_video_quota_bytes` len `service_role` |

## E. Sieť a rýchlosť

| # | Scenár | Má sa stať | Stav |
|---|---|---|---|
| E1 | Lietadlový režim pri štarte | kúpený plán hneď, dar z cache najviac 30 dní | [kód] StoreKit čita offline, dar zostáva z cache najviac 30 dní (`aGiftSurvivesAMissingAnswerFromTheServer`) [iPhone] |
| E2 | Pomalá alebo zaseknutá Wi-Fi | kúpený plán do sekundy, server ho potom len doplní | **[opravené]** [test] `aPlanBoughtInTheAppStoreShowsBeforeTheServerAnswers`: kúpený plán sa ukáže hneď, server tri otázky položí naraz |
| E3 | Server vráti chybu | berie sa ako „nedostupný", kúpenému sa nič neuberie | [test] (`resolve`) |

## F. Free limity a vzhľad

| # | Scenár | Má sa stať | Stav |
|---|---|---|---|
| F1 | Free: jedna zostava na tanec | druhá otvorí paywall | [kód] jediné miesto je `DanceDetailView`; [plán] test čistej funkcie |
| F2 | Koniec Plus s viacerými zostavami | existujúce ostanú, nové nejde | [iPhone] |
| F3 | Koniec Plus s vlastnou ikonou a témou | vráti sa základný vzhľad | [kód] (`applyFreeLookIfNeeded`), pozri D13 |

## Čo sa nedá otestovať v simulátore

`SKTestSession` (StoreKitTest) som skúšal trikrát: relácia sa vytvorí a produkty sa načítajú, ale každý simulovaný nákup padne na internej chybe (`SKInternalErrorDomain` 3, `.notEntitled`) a Ask to Buy visí. Nákup, upgrade, expirácia, vrátenie peňazí a Ask to Buy preto idú do sandboxu na iPhone (B1 až B3, B10, C1 až C5, C8), v kóde ich pokryje len čistá logika (mapovanie produktu na plán, rozhodnutie paywallu, `resolve`, poradie kontrol).
