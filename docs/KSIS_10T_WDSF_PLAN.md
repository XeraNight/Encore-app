# Desaťtance (10T) a WDSF v appke: plán

Stav z 16. 11. 2026. Návrh, ktorý čaká na tvoje rozhodnutia (sekcia 6). Čítanie a ukladanie je v kóde hotové, ale **nenasadené** (server commit `925eae4`, appka `0929fe9`).

## 1. Čo to je v KSIS

| | Čo KSIS ukazuje | KSIS číslo súťaže | Body | Krížiky |
|---|---|---|---|---|
| **10T**: „MSR Dospelí 10T“ | Majstrovstvá SR v desiatich tancoch (5 štandardných + 5 latinských), nie pohár | áno (11517) | nie, pole „Body“ je prázdne | **áno, overené 17. 11. na skutočnej stránke:** 10 tancov, 12 rozhodcov a 5 tieňových; v semifinále krížiky všetkých desiatich tancov, vo finále skóre za každý tanec |
| **WDSF so slovenským číslom**: „WDSF Rising Stars ST“ (Košice GP) | bežná súťaž v KSIS | áno | nie | **áno, overené 17. 11. (11197):** semifinále krížiky, vo finále umiestnenia rozhodcov |
| **WDSF bez čísla**: Budapešť, Košice 2026 | na stránke páru len dátum, názov podujatia („Kosice,Slovakia“), kategória („Adult Latin“), počet párov a umiestnenie | **nie** | nie | nie, stránka neexistuje |

Niektoré slovenské WDSF súťaže (Košice 2025) sa na stránke páru ukazujú dvakrát (raz s číslom, raz bez) a ukladáme tú s číslom. Zahraničné a novšie slovenské (Košice 2026) majú len záznam bez čísla.

## 2. Čo je už v kóde (nenasadené)

- Server ukladá 10T s disciplínou „10T“ (databáza ju už povoľuje) a WDSF bez čísla so záporným `sutaz_id` vyrobeným z dátumu, podujatia a kategórie; miesto je názov podujatia, takže ide na mapu (Košice) alebo do „Mimo mapy“ (zahraničie). Duplicity so slovenskými WDSF sa preskočia (rovnaký dátum, disciplína, počet párov a miesto). Riadky bez čísla sledujú stránku: čo tam už nie je, zmizne.
- Appka: názov „Desaťtance“, chip „10T“ v Moje výsledky, zlatá bodka v kalendári, pri WDSF bez čísla sa nikdy nepýta KSIS na krížiky a miesto, v detaile je karta „Súťaž WDSF“ a skryté odkazy do KSIS.

## 3. Kde v appke a čo je ešte treba

| Obrazovka | 10T | WDSF | Stav |
|---|---|---|---|
| **Profil › Súťaže** (prehľad, dlaždice ŠTANDARD a LATINA) | riadok **DESAŤTANCE** pod dlaždicami (nie tretia dlaždica, tri by boli na telefóne tesné), len keď aspoň jedna existuje; otvorí tú istú obrazovku štatistík bez triedy a pohára | bez dlaždice, WDSF je len v zozname | 10T **hotové 17. 11.** |
| **Moje výsledky** (zoznam, kalendár, mapa, filter) | chip „10T“, skryté „+0 b“ (riadok aj súhrn) | chip **„WDSF“**; riadok s odznakom WDSF; názov „WDSF · Košice“ namiesto „Kosice,Slovakia“; skryté „+0 b“ | 10T **hotové**, WDSF **treba** |
| **Štatistiky disciplíny** (ŠTT a LAT: graf, tance, rozhodcovia, miesta) | tá istá obrazovka s „10T“: bez triedy, bodov a pohára; v „Krížiky podľa tancov“ všetkých desať tancov; kolo so skóre nepridá krížiky | v zozname áno, **do grafu umiestnení a „najlepšieho miesta“ nie** (iná úroveň: „33. z 35“ vs „3. z 13“) | 10T **hotové**, WDSF **treba** |
| **Detail výsledku** | karta krížikov ako inde; bez bodov (dlaždica „body“ skrytá) | karta „Súťaž WDSF“, bez bodov a odkazov | 10T **hotové**, WDSF karta hotová, bodovú dlaždicu skryť **treba** |
| **Kalendár Plánovača** (bodky, deň so súťažou) | zlatá bodka | farba podľa ŠTT/LAT | hotové |
| **Mapa** | podľa miesta | Košice pod pinom, zahraničie v „Mimo mapy“ | hotové |
| **Spojenia** (výsledky priateľa) | rovnako ako vlastné | rovnako | po úpravách vyššie |
| **Aktualizácia z KSIS** | číta stránku hodnotenia | nepýta nič | hotové |
| **Web** (Antigravity) | disciplína „10T“ | riadky so záporným `sutaz_id` nemajú KSIS stránku, skryť odkazy | **treba povedať** |

## 4. Čo sa kde počíta

| Čo | 10T | WDSF |
|---|---|---|
| Počet súťaží (jedna kategória = jedna súťaž, ako doteraz) | áno | áno |
| „Na pódiu“ (1. až 3. miesto) | áno | áno |
| Body a trieda (ŠTT, LAT) | nie, KSIS body nedáva | nie |
| Graf umiestnení, priemery, „najlepšie miesto“ | vlastný blok | **nie**, ukáže sa len v zozname (návrh, rozhodnutie 1) |
| Krížiky po tancoch | vlastný blok (10 tancov) | ako ostatné, ak KSIS krížiky má |
| Slovenský pohár | nie | nie |
| Mapa, kalendár, počet miest | áno | áno |

## 5. Údaje a server

- WDSF bez čísla dostane záporné číslo, preto sa v appke nikdy nepýta v KSIS (`hasKSISPage`). Alternatíva (samostatná tabuľka `wdsf_results`) je čistejšia, ale pridá migráciu, druhé sťahovanie a spájanie v každej obrazovke. Pre pár desiatok riadkov na človeka sa nevyplatí, vrátime sa k nej, ak WDSF narastie.
- Kategórie WDSF iné než „Standard“ a „Latin“ (napr. desaťtance WDSF) sa preskakujú, kým ich neuvidíme na reálnej stránke.
- Poradie nasadenia: **appka aj server naraz**. Starší build by pýtal v KSIS stránky s vymysleným číslom a desaťtance by ukázal ako Štandard. Preto nový build najprv priateľom, potom server.
- Zmazanie WDSF výsledku v appke ho zmaže na serveri, ale ďalšia aktualizácia ho prečíta znova (rovnako ako iné výsledky).

## 6. Rozhodnutia pre teba (s odporúčaním)

1. **Mieša sa WDSF do grafov umiestnení a „najlepšieho miesta“?** Odporúčam **nie**: „6. zo 16“ na WDSF a „2. z 12“ na národnej súťaži sa nedajú porovnať. V súhrne (počet, pódium) a v zoznamoch sú všetky.
2. **Desaťtance ako vlastná dlaždica a blok?** Odporúčam **áno**, len keď existuje aspoň jedna súťaž. Ročne ide o jednu súťaž, takže ju nemiešať do ŠTT. **Rozhodnuté 17. 11.: áno, postavené** (riadok pod dlaždicami; 10T sa číta z histórie páru pri Aktualizovať, bez ďalších volaní).
3. **Názov WDSF súťaže bez čísla:** odporúčam „WDSF · Košice“ (mesto pred čiarkou, so slovenskou podobou, ak ho poznáme). Zahraničné ako „WDSF · Budapest“.
4. **Počítať v „súťaží“ aj ďalej každú kategóriu zvlášť?** Odporúčam **áno** (12 podujatí so ŠTT a LAT = 24). Neskôr môžeme ukázať „24 súťaží z 12 podujatí“.

## 7. Poradie práce

1. **Skutočné stránky: hotové 17. 11.** Jakub uložil tri stránky (10T výsledky a hodnotenie, WDSF Rising Stars ST). Čítajú sa **bez akejkoľvek zmeny** čítačiek; anonymizované fixtúry a testy sú v `fixtures/ksis/` (`results_10t_11517.html`, `marks_10t_11517.html`, `marks_wdsf_11197.html`) a v `ksis-pages.test.ts`.
2. **Pravidlá počítania** (malé): vlastnosť `isWDSF` (bez KSIS čísla, alebo kategória začína „WDSF“), vynechanie z grafu umiestnení a „najlepšieho miesta“, skrytie „+0 b“. Testy.
3. **Obrazovky** (stredné): dlaždica Desaťtance, štatistiky bez triedy a pohára, chip WDSF, názov „WDSF · mesto“.
4. **Nasadenie**: nový build, priateľom, potom server (`ksis-page`), oznam pre Antigravity.
5. **Pozorovanie**: po prvej aktualizácii pozrieť logy (`layout`), či sa 10T a WDSF čítajú bez chýb.

## 8. Okrajové prípady

- KSIS neskôr WDSF riadku pridelí číslo: starý riadok so záporným číslom zmizne (sleduje stránku) a príde nový s číslom.
- Názov podujatia sa v KSIS prepíše: starý riadok zmizne, nový sa uloží.
- Dve WDSF kategórie v ten istý deň s rovnakým miestom a počtom párov: ak jedna má slovenské číslo, druhá sa preskočí ako duplicita (veľmi nepravdepodobné).
- Stránka páru bez riadkov: existujúce WDSF riadky sa nechajú, kým stránka neukáže aspoň jeden riadok.
- 10T s iným názvom („MSR Juniori 10T“, „Dospelí 10T“): poznáme podľa posledného slova „10T“.
- Spoločné miesto („10. – 11.“): berie sa prvé číslo, text sa zobrazí celý.
- Zmazaný pár: zmizne aj s WDSF a 10T.

## 9. Čo nebudeme robiť

- Žiadne body, triedy ani postupy z WDSF a 10T: KSIS ich nedáva a pravidlá nevymýšľame.
- Žiadne svetové rebríčky WDSF ani porovnávanie s inými pármi.
- Žiadne čítanie z worlddancesport.org: appka číta len KSIS.
