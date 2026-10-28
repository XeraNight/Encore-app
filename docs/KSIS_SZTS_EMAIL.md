# E-mail pre SZTŠ: súhlas s používaním verejných údajov KSIS (návrh 28. 10. 2026)

**Komu:** `szts@szts.sk`, všeobecný kontakt SZTŠ z výročnej správy 2024. Pred odoslaním ho over na szts.sk.
Kto spravuje KSIS, som verejne nenašiel, preto e-mail prosí o preposlanie.

**Prečo teraz:** Plus má rozbor sezóny z výsledkov KSIS, takže appka na ich obsahu zarába. Pravidlo App Review
5.2.2 chce na obsah tretej strany povolenie a v App Store Connect (Content Rights) potvrdzuješ, že ho máš.
Stačí krátka písomná odpoveď.

**Doplň:** telefón (ak chceš).

---

**Predmet:** Encore: súhlas s používaním verejných výsledkov z KSIS

Dobrý deň,

volám sa Jakub Kalina, tancujem za TK Ellegance Košice (Dospelí D) a popri škole robím aplikáciu Encore
pre iPhone. Je to tréningový denník pre tanečníkov a páry (zostavy na parkete, poznámky z lekcií, plán
tréningov) a čoskoro bude v App Store.

V aplikácii si tanečník môže otvoriť verejné stránky KSIS a uložiť si z nich svoje súťažné údaje. Chcem vás
poprosiť o súhlas s takýmto používaním a povedať vám presne, ako funguje:

- Stránky KSIS si otvára sám používateľ priamo v aplikácii. Aplikácia na KSIS sama nechodí a nič hromadne
  nesťahuje.
- Z otvorenej stránky si uloží len údaje o sebe: osobné číslo, meno, klub a triedy, svoje páry a pri svojich
  súťažiach triedu, body, finále, umiestnenia a krížiky porotcov. Mená ostatných tanečníkov sa neukladajú.
- Údaje vidí len samotný tanečník. Ostatným ich ukáže, iba ak to sám zapne.
- Aplikácia nie je oficiálna aplikácia SZTŠ a pri výsledkoch uvádza, že jediným oficiálnym zdrojom je SZTŠ.
  Názov ani logo zväzu nepoužívame.
- Prehľad výsledkov je zadarmo. Rozbor vlastnej sezóny (v ktorom tanci má pár najmenej krížikov, vývoj počas
  sezóny) je súčasťou plateného predplatného Encore Plus.
- Údaje nepredávame ani ďalej nezverejňujeme. Servery máme v EÚ.

Stačí mi krátka odpoveď, či s tým súhlasíte. Ak máte nejaké podmienky, napríklad ako má byť uvedený zdroj,
rád sa im prispôsobím. Aplikáciu vám tiež rád ukážem.

Ak KSIS spravuje niekto iný, budem vďačný za preposlanie.

Ďakujem,
Jakub Kalina
jakubkalina05@gmail.com
[telefón]

---

## Poznámky (do e-mailu nepatria)

- **Neposielaj** číslo preukazu ani heslá.
- **Ak odpovedia áno:** odpoveď si odlož. Pri Content Rights potom pokojne potvrdíš, že práva máš, a keby sa
  Apple pýtal, pošleš ju v odpovedi kontrolórovi.
- **Ak odpovedia nie alebo s podmienkami:** povedz mi, čo napísali. Rozbor sezóny vieme presunúť do Free alebo
  KSIS skryť, kým sa nedohodneme.
- **Neskôr, po ich súhlase:** druhý e-mail o automatike (serverové sledovanie, postup z kola v deň súťaže).
  KSIS chráni Cloudflare a náš server nepustí, preto vtedy poprosíme o pravidlo v Cloudflare s kľúčom od nich
  alebo o export. Najviac jedna požiadavka za sekundu, každá stránka raz pre všetkých, podpísané menom appky.
  Kľúč by išiel do Supabase → Edge Functions → Secrets ako `KSIS_ACCESS_KEY`, nikdy nie do kódu.
- **Voliteľne do druhého e-mailu:** pri skúšaní 9. 10. sme pri súťaži 12094 (Košice GP 2026, Dospelí D ŠTT)
  videli v záložke Skating inak 4. a 5. miesto než vo výsledkovej listine a chýbal porotca D. Pred spomenutím
  over, či to ešte platí.
- **Zdroje kontaktu:**
  - [Výročná správa SZTŠ 2024](https://szts.sk/wp-content/uploads/2025/06/2024_SZTS_vyrocna-sprava-oprava-final.pdf)
  - [Stanovy SZTŠ 2024](https://szts.sk/wp-content/uploads/2024/06/Stanovy-SZTS-2024.pdf)
