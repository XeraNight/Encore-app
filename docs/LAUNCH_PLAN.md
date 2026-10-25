> **8. 10. 2026:** kontrolný zoznam pred spustením je `docs/V1_LAUNCH_CHECKLIST.md`, hodinky `docs/WATCHOS_V1_1_PLAN.md`, videá `docs/VIDEO_STORAGE_AND_SHARING.md`. Plán „Studio“ sa volá Premium.

# Encore: plán do launchu (stav k 5. 10. 2026)

Rozhodnutia: poznámky a videá zostávajú v telefóne; logo sa na Home rozdelí na mužskú a ženskú časť; knižnica figúr sa filtruje podľa výkonnostnej triedy; Kamera sa presúva z doku na Home.

## 0. Pravidlá a hotové veci
- Hotové: CLAUDE.md, .claude/settings.json, odstránenie aury loga, heslo sa neukladá, owner check iba z overeného e-mailu, SQL hardening (supabase/migrations/20261005_hardening_function_grants.sql, treba spustiť v SQL editore).
- Pozastavené do Developer účtu (100 €): Sign in with Apple, StoreKit v App Store Connect, Wallet, TestFlight.

## 1. Home
1. Malé logo (cca 44 pt) + prekrytie radiálneho menu (nezaberá miesto v layoute, nič neblokuje).
2. Logo animácia: pár (muž + žena) sa pri ťuknutí/podržaní plynule rozdelí a spojí do tvaru E. Vyžaduje dve samostatné vrstvy loga (viď nižšie).
3. Pole na poznámku: čipy tanca a tagov, lišta nad klávesnicou (tagy + Uložiť).
4. Schránka pod poľom: pás posledných poznámok, počítadlo neimportovaných, plný zoznam s vyhľadávaním a filtrami (tanec, tag, stav).
5. Model: InstantNote += tags, danceName, isPinned, linkedFigureId, linkedRoutineId, importedAt (SwiftData, s predvolenými hodnotami = ľahká migrácia).
6. Import k figúre: pripíše text s dátumom, poznámku označí ako importovanú (nemaže).
7. Animácie + haptika: let karty do schránky, pulz mikrofónu podľa hlasitosti, plynulý prepínač režimov, `.sensoryFeedback`, rešpekt k „Znížiť pohyb“.
8. Karta „Naposledy upravované“ s miniatúrou dráhy figúr a šípkou smeru.
9. Upratať: zmazať mŕtvy kód v ContentView, vytiahnuť DanceDetail/EditDance/Compare do vlastných súborov.

## 2. Kamera
- Zrušiť falošnú záložku z doku; spúšťať z Home (tlačidlo pri poli) a z figúry/zostavy s predvybraným cieľom.
- Opraviť stratu nahrávky pri chybe (DanceCameraManager.swift:200-206), prepojiť záznam so zostavou/figúrou, jedno okno namiesto sheet + cover, fotka, uložiť zvuk k hlasovej poznámke, doplniť slovenčinu.

## 3. Dock
Domov / Canvas / Knižnica / Profil. Kalendár pribudne ako 5. záložka, keď bude hotový (chat až po launchu).

## 4. Knižnica figúr s triedami
- FigureLibraryItem += level (výkonnostná trieda) s hodnotami podľa oficiálneho sylabu SZTŠ. Triedy a pravidlá sa NEODHADUJÚ: dodáš zdroj/tabuľku, alebo ich vyplníš ty v CSV.
- Zdroj dát: jeden seed súbor (CSV/JSON) v appke, ktorý dopĺňaš ty; import pri aktualizácii appky.
- UI: filter triedy + tanec + hľadanie, odznak triedy na karte.

## 5. Ukladanie dát a náklady
- Videá a fotky zostávajú v telefóne. Do Supabase ide len text, štruktúra zostáv a metadáta.
- Zdieľanie klipu s partnerom: len Plus/Studio, max 720p HEVC, do cca 30 s, automatická expirácia. Bucket už má limit 100 MB na súbor.
- Neskôr záloha vlastných videí cez iCloud (CloudKit): úložisko platí používateľ, nie ty.

## 6. Zamykanie funkcií (Free / Plus / Studio)
- Vynútiť limit zostáv na tanec na všetkých cestách (QR import, sťahovanie z cloudu, kategória).
- Zamknúť Trénerské štúdio, Roster, Posture, Video Duel; rozhodnúť o canShareWithPartner.
- Debug prepínač „Zobraziť ako: Free / Plus / Studio“ pre majiteľa.
- Ceny v OwnerAdminConsole brať z modelu, nie natvrdo.

## 7. Profil
Rozdeliť ProfileView (2 014 riadkov) na sekcie v samostatných súboroch; Súťažný denník a Trénerské štúdio presunúť do „Nástrojov“.

## 8. Funkcie sľúbené v paywalle (staviame pred launchom)
- Plus: Apple Kalendár (EventKit, bez Developer účtu), Top 3 priority po lekcii, 7-dňový kľúč pre externého trénera.
- Tréner: poznámka „Čo sme robili naposledy“, Zero-Delete (aj na úrovni RLS, SQL najprv ukázať), hodnotenie figúr 1-5 s dátumom.
- KSIS živé sledovanie: ZÁMERNE po launchu (čaká na reálne HTML vzorky, docs/KSIS_PHASE2_NOTES.md).

## Poradie
1 Home → 2 Kamera + dock → 4 Knižnica → 6 Zamykanie → 7 Profil → 8 Plus/Tréner → právne veci (Pinterest obrázky, privacy URL) → Developer účet → TestFlight.

## 9. Záložka „Plán“ (kalendár) namiesto Kamery v doku
Zdroj nápadu: návrh z Antigravity, upravený po kontrole. Dock: Domov / Canvas / Plán / Profil. Kamera ostáva na Home (už tam je).

### Úpravy oproti pôvodnému návrhu
- Deň v týždni ukladať ako ISO (1 = pondelok … 7 = nedeľa) a pri práci s `Calendar` prepočítať (Calendar používa 1 = nedeľa). Čas začiatku ako minúty od polnoci (Int), nie text „18:00“.
- Notifikácie: opakujúci týždenný trigger nevie preskočiť deň, keď si „Dnes vynechávam“. Plánovať kĺzavo najbližších ~14 dní a obnoviť pri otvorení appky (limit iOS je 64 čakajúcich).
- Stav účasti ako výber (naplánované / idem / vynechávam / absolvované), nie len Bool. Hodnotenie energie voliteľné (nie predvolene 5).
- Reflexia sa uloží ako `InstantNote` (tag #Reflexia + tanec), takže ide rovnakou schránkou a importom k figúram. `TrainingLogEntry` ju len odkazuje.
- Zoznam súťaží z KSIS: dnešné funkcie importujú výsledky párov, nie kalendár všetkých turnajov. Zoznam turnajov a uzávierky prihlášok by si vyžiadal nový zdroj dát a podľa docs/KSIS_PHASE2_NOTES.md nesmieme nič odhadovať. Do launchu: súťaže zadávané ručne (názov, mesto, dátum, kategórie, uzávierka); import z KSIS až po odpovedi SZTŠ.
- Live Activity sa nedá spustiť sama v čase tréningu bez push notifikácie (vyžaduje Developer účet). Preto: lokálna notifikácia + widget; Live Activity len keď ju používateľ spustí v appke.
- Widget [Idem / Neidem]: použiť App Intents (AppIntent.swift vo widgete už existuje) a malý JSON snapshot v App Group; NEpresúvať SwiftData úložisko do App Group (riziko straty dát).
- Partner dostane „Idem“ cez Supabase: nová tabuľka s RLS (SQL najprv ukázať) a push vyžaduje Developer účet. Do vtedy len pri otvorenej appke.

### Fázy
1. Lokálne MVP: modely (TrainingCadence, TrainingLogEntry, PlannedCompetition), `DancePlannerView` s časťami Dnes / Režim / Súťaže, rýchle Idem/Vynechávam, lokálna notifikácia po tréningu cez existujúci NotificationManager, debrief sheet (hlas + tanec + pocit), export súťaže a týždenného režimu do Apple Kalendára (EventKit).
2. Mimo appky: interaktívny widget Idem/Neidem + odpočet do súťaže, App Intents pre Siri a tlačidlo Akcia.
3. Partner synchronizácia a push (po Developer účte).
