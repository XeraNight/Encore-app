# KSIS: upozornenia z telefónu (plán, 22. 10. 2026)

## Ako to je dnes
- **Funguje:**
  - KSIS otvoríš v appke (zabudovaný prehliadač) a appka prečíta tvoj pár, výsledky aj krížiky rozhodcov.
  - Na stránke prihlášok appka napíše „Ste prihlásení: …“ a jedným ťuknutím pridá súťaž do Kalendára aj s pripomienkami.
- **Zo servera to nejde:** Cloudflare pred KSIS púšťa len prehliadače, servery v dátovom centre zastaví
  (`KSIS_SAMPLES_NEEDED.md` §1). Funkcia `ksis-sync` preto nikdy nebola nasadená.
  - Ranný a živý cron, ktoré ju volali naprázdno, sú od 22. 10. vypnuté.
  - Tabuľky `ksis_live_watches`, `user_notifications` a `ksis_page_cache` ostávajú na fázu 2.

## Fáza 1: upozornenia z telefónu
Telefón číta KSIS ako človek v prehliadači (skrytá webová stránka, tvoja IP adresa). Stránky rozoberá
server funkciou `ksis-page` (akcia `read`), teda tými istými otestovanými čítačkami, aké už používame.
Uloží sa len tvoj pár.

**a) Prihlásenie na súťaž a zrušenie**
- Kedy: pri otvorení appky najviac raz za 12 hodín (a raz denne na pozadí, ak to iOS dovolí).
- Čo sa číta: kalendár súťaží (1 stránka) a zoznamy prihlášok súťaží v najbližších 14 dňoch pre vekovú
  kategóriu tvojho páru (zvyčajne 1 až 3 stránky).
- Porovná sa s posledným stavom a pošle miestne upozornenie: „Ste prihlásení na … (sobota)“ alebo
  „… bola zrušená“ či „už nie ste prihlásení“. Súťaž sa zároveň ponúkne do Kalendára.
- **Najviac 4 stránky za 12 hodín na používateľa.**

**b) Postup na súťaži, len keď chceš**
- Na Súťažnom dni ťukneš **Sledovať naživo**. Kým máš appku otvorenú, každé 3 minúty sa načíta stránka
  výsledkov tvojej súťaže.
- Upozornenie príde pri novom kole, postupe a finále.
- Sledovanie samo skončí po finále, po vypadnutí alebo po 10 hodinách. Keď KSIS zablokuje, zastaví sa
  a appka to povie.
- **Najviac 20 stránok za hodinu, a len počas zapnutého sledovania.**
- iOS nedovolí telefónu kontrolovať každé 3 minúty na pozadí, preto fázu b) treba mať otvorenú appku.

**Prečo nás KSIS nezablokuje:** každý telefón číta len pár stránok svojho páru zo svojej IP adresy, ako keď ich
otvorí človek. Nič neopakujeme naslepo; po bloku čakáme.

### Čo od teba potrebujem (vzorky stránok, návod v `KSIS_SAMPLES_NEEDED.md` §5)
1. **Kalendár súťaží** `menu.php?akcia=KS`. Bez neho telefón nevie, aké súťaže budú.
2. **Zrušená súťaž**, ako ju ukazuje KSIS (v kalendári alebo na stránke podujatia). Inak zrušenie neviem
   spoľahlivo rozpoznať.
3. **Výsledky počas súťaže** (`sutaz.php`), 2 až 3 uloženia s odstupom asi hodiny. Treba overiť, či KSIS
   zverejňuje postup priebežne.

Bez týchto vzoriek by som formát stránok hádal, a pri súťažiach nič nevymýšľame.

## Fáza 2: zo servera (keď SZTŠ povolí náš server alebo dá export dát)
- Server prečíta každú súťaž raz pre všetkých (zdieľaná cache), takže počet požiadaviek nezávisí od
  počtu používateľov.
- Upozornenia aj na zamknutej obrazovke (push cez APNs) a Live Activity aktualizovaná pushom.
- E-mail pre SZTŠ: `KSIS_SZTS_EMAIL.md`.

## Podmienky
Dnes je veta „Encore sama na KSIS nechodí ani nič neobnovuje na pozadí“ pravdivá. Pri spustení fázy 1 ju
treba zmeniť na: „Encore číta z tvojho iPhonu verejné stránky KSIS tvojho páru: pri otvorení appky
najviac raz za 12 hodín a počas súťaže, ktorú sám sleduješ naživo.“
