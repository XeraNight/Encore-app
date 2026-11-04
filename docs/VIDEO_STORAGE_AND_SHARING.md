# Videá v Encore: kde sú, ako sa zdieľajú a koľko to stojí

Stav k 8. 10. 2026. Tento dokument vysvetľuje celé riešenie videí od začiatku do konca, aby sa dalo
pochopiť aj po mesiacoch bez čítania kódu.

## 1. Jedna veta

**Originál videa je vždy vo Fotkách používateľa. Keď video zdieľa s partnerom alebo trénerom, appka
urobí zmenšenú 720p kópiu a nahrá ju do Cloudflare R2. Supabase iba rozhoduje, kto ju smie vidieť.**

```
 iPhone tanečníka                         Supabase (mozog)                 Cloudflare R2 (sklad)
 ─────────────────                        ────────────────                 ─────────────────────
 Fotky / album Encore  ── originál ostáva tu, nikam nejde
        │
        │ „Zdieľať s partnerom a trénerom“
        ▼
 720p kópia (~10 MB / 30 s)
        │ 1. upload  ───────────────────►  media-share: si prihlásený?
        │                                  figúra je tvoja? máš miesto?
        │ ◄──────── odkaz na nahranie (15 min) ─┘
        │ 2. nahrá priamo ─────────────────────────────────────────────►  encore-media/<ty>/<id>.mp4
        │ 3. confirm ────────────────────►  overí veľkosť v R2, zapíše
        │                                   figúre video_path = "r2:…"
        ▼
 iPhone partnera / trénera
        │ 4. download ───────────────────►  media-share: ste prepojení?
        │ ◄──────── odkaz na stiahnutie (1 h) ──┘
        │ 5. stiahne raz ◄──────────────────────────────────────────────  (stiahnutie je zadarmo)
        ▼
 Caches/SharedVideos (prehráva odtiaľ; voliteľne „Uložiť do mojich Fotiek“)
```

## 2. Čo kde je

| Čo | Kde | Prečo |
|---|---|---|
| Text: zostavy, figúry, poznámky, poznámky trénera, profil | Supabase (Postgres) + kópia v iPhone (SwiftData) | Malé, potrebné pre partnera, realtime a obnovu |
| Poznámky z Domova, Plán | zatiaľ len v iPhone | Krok 3: presun do Supabase |
| Originály videí (vlastné, tréner, idol) | Fotky používateľa, album „Encore“; v appke iba odkaz `photos:<id>` | 0 € pre nás, zálohuje ich iCloud používateľa, žiadna duplicita |
| Zdieľané kópie videí | Cloudflare R2, bucket `encore-media`, odkaz `r2:<vlastník>/<id>.mp4` | Žiadne poplatky za stiahnutie |
| Stiahnuté zdieľané kópie u partnera | iPhone partnera, `Library/Caches/SharedVideos` | Stiahne sa raz; iOS ich môže pri nedostatku miesta zmazať, potom sa stiahnu znova |
| Hlasové nahrávky | iPhone (Documents), v iCloud zálohe iPhonu | Fotky neukladajú zvuk; ~1 MB/min |
| Staré videá figúr (pred touto zmenou) | súbor v appke | Ostávajú, kým ich používateľ nenahradí |

**Dôležité pravidlo:** v databáze na figúre (`canvas_nodes.video_path`) smie byť iba zdieľaná kópia
`r2:…` alebo nič. Odkaz do Fotiek funguje len na jednom iPhone, preto ho databáza odmietne
(kontrola `canvas_nodes_video_path_shared_only`) a appka ho tam ani neposiela
(`SharedVideoStore.serverValue`). V appke má figúra dve polia:

- `videoPath`: originál na tomto iPhone, nikdy sa nesynchronizuje,
- `sharedVideoPath`: zdieľaná kópia, zrkadlo servera.

Figúra ukazuje najprv vlastný originál, inak zdieľanú kópiu (`displayVideoPath`).

## 3. Čo sa deje pri jednotlivých akciách

| Akcia | Čo sa stane |
|---|---|
| Natočenie videa na Domove alebo na plátne | Video sa presunie do Fotiek (album Encore). Bez prístupu k Fotkám ostane v appke ako predtým. |
| Zdieľať s partnerom a trénerom | Zostava sa najprv odošle na server (server overuje vlastníctvo figúry), potom 720p kópia → R2 → `sharedVideoPath = r2:…`. Odznak „Zdieľané · 12 MB z 1 GB“. |
| Natočiť znova (zdieľaná figúra) | Nová verzia sa zdieľa sama; stará kópia v R2 sa zmaže pri potvrdení novej. |
| Zrušiť zdieľanie | Kópia sa zmaže z R2 aj z databázy, partnerova appka zmaže svoju uloženú kópiu pri ďalšej synchronizácii. |
| Odstrániť video | Najprv sa zruší zdieľanie (ak zlyhá, nič sa nezmaže), potom odkaz z figúry. Vo Fotkách video ostáva. |
| Partner: Uložiť do mojich Fotiek | Kópia sa uloží do jeho albumu Encore. Je jeho, aj keď vlastník zdieľanie zruší (ako vo WhatsAppe). |
| Zmazanie figúry alebo zostavy | Kópia v R2 ostane bez figúry a zmaže sa automaticky pri ďalšom zdieľaní vlastníka. |
| Zmazanie účtu | `delete-account` zmaže všetky kópie vlastníka z R2, potom účet. |
| Zmazanie videa vo Fotkách | Figúra ukáže „Video bolo zmazané z Fotiek“. |

## 4. Limity a ceny

**Limit zdieľaných videí na plán** (vynucuje server, `shared_video_quota_bytes`; text v appke je
`SubscriptionTier.sharedVideoStorage` a musí sedieť):

| Plán | Miesto | Približne |
|---|---|---|
| Free | 1 GB | ~100 klipov po 30 s |
| Plus | 10 GB | ~1 000 klipov |
| Premium | 50 GB | ~5 000 klipov |
| Majiteľ | 50 GB | |

Jeden súbor najviac 100 MB (asi 5 minút videa v 720p).

**Ceny Cloudflare R2** (október 2026, over si na developers.cloudflare.com/r2/pricing):

- úložisko: 10 GB mesačne zadarmo, potom 0,015 $/GB,
- stiahnutie (egress): **vždy zadarmo**,
- zápisy: 1 milión mesačne zadarmo; čítania: 10 miliónov zadarmo.

**Príklady:** 1 000 klipov spolu ≈ 10 GB = 0 $. 10 000 klipov ≈ 100 GB ≈ 1,35 $/mesiac.
Najhorší prípad pre 1 000 používateľov Free, ktorí naplnia celý limit: 1 TB ≈ 15 $/mesiac.

**Čo naozaj šetrí:** rušenie zdieľania starých videí (uvoľní miesto). Ukladanie do Fotiek u partnera
samo o sebe cenu neznižuje, lebo stiahnutie je zadarmo. Pomôže, keď po ňom vlastník zdieľanie zruší.
Toto vysvetľuje používateľom obrazovka **Nastavenia → Pomoc a právne → Ako fungujú videá** a texty
pri zdieľaní.

**Hlavný náklad nie je úložisko, ale Supabase:** Free 0 $, Pro 25 $/mesiac (so zapnutým limitom
výdavkov). Pro je potrebný, keď prídu platiaci používatelia alebo databáza prekročí ~400 MB.

## 5. Bezpečnosť

- Bucket je **súkromný**. „Public Development URL“ a „Custom Domains“ musia ostať vypnuté.
- Appka **nikdy nemá kľúče od R2**. Kľúče sú len v Supabase Secrets a používa ich iba serverová funkcia.
- Odkazy sú podpísané a krátke: nahranie 15 minút, stiahnutie 1 hodina.
- Veľkosť je súčasťou podpisu nahrávania: väčší súbor, než bol nahlásený, R2 odmietne (otestované, 403).
  Server navyše pri potvrdení zmeria skutočnú veľkosť.
- Vidieť smie: vlastník, prijatý partner (oboma smermi), tréner vlastníka (`coach_student`, kde
  vlastník je žiak). Rovnaké pravidlo ako predtým v Supabase Storage. Funkcia `can_view_shared_video`.
- Zablokovaný účet nesmie nahrávať ani sťahovať.
- Tabuľku `shared_videos` zapisuje iba server; používateľ vidí len svoje riadky. Funkcie limitu a
  práv môže volať iba server (service role).
- Kľúče objektov majú pevný tvar `<uuid>/<uuid>.mp4`, nič iné databáza neprijme.

## 6. Nastavenie (už urobené) a čo robiť pri zmene

**Cloudflare:** účet jakubkalina05@gmail.com, Account ID `81bb3f07d9be1901eb0c2671689a7130`,
R2 bucket `encore-media`, poloha Eastern Europe (EEUR), trieda Standard.
API token: Object Read & Write iba pre `encore-media`.

**Supabase → Edge Functions → Secrets:** `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`,
`R2_SECRET_ACCESS_KEY`, `R2_BUCKET`.

**Výmena kľúča** (ak by unikol alebo raz ročne):
1. Cloudflare → R2 → Manage API Tokens → vytvor nový token (rovnaké nastavenie).
2. V Supabase Secrets prepíš `R2_ACCESS_KEY_ID` a `R2_SECRET_ACCESS_KEY`.
3. Starý token v Cloudflare zmaž. Funkcie netreba nasadzovať znova.

**Prihlásenie wrangler na Macu:** po dokončení nastavenia ho môžeš zrušiť príkazom
`npx wrangler logout`.

## 7. Súbory

**iOS**
- `Encore/Media/PhotoLibraryVideoStore.swift`: ukladanie do Fotiek, prehrávanie a náhľady z Fotiek.
- `Encore/Media/SharedVideoStore.swift`: zdieľanie (720p kópia, nahranie, potvrdenie), stiahnutie, zrušenie,
  cache; `ShareableVideoEncoder` robí HEVC 720p ~2,5 Mbit/s.
- `Encore/Media/MediaResolver.swift`: `videoURL(path:)` vie `photos:`, `r2:` aj staré súbory.
- `Encore/Figures/FigureDetailCard.swift`: menu ⋯ (Zdieľať, Zrušiť zdieľanie, Uložiť do mojich Fotiek),
  odznak, dialógy s vysvetlením.
- `Encore/Sync/Models.swift`: `CanvasNode.videoPath`, `sharedVideoPath`, `displayVideoPath`.
- `Encore/Sync/SupabaseSyncManager.swift`: `RoutineSnapshot` (posiela iba `r2:`), `apply(row:)`,
  `replaceSharedVideoPath`, `syncRoutineNow`.
- `Encore/Profile/VideoGuideView.swift`: návod pre používateľov.
- `Encore/Camera/DanceCameraView.swift`: `savesToPhotos`.

**Server**
- `supabase/functions/media-share/index.ts`: akcie upload, confirm, download, remove.
- `supabase/functions/_shared/r2.ts`: podpisovanie odkazov, veľkosť, mazanie v R2.
- `supabase/functions/delete-account/index.ts`: maže aj kópie v R2.
- `supabase/migrations/20261008_shared_videos.sql`: tabuľka, kontrola na figúrach, limity, práva.
- `supabase/migrations/20261008_export_shared_videos.sql`: „Stiahnuť moje dáta“ uvádza aj zdieľané videá.

## 8. Kontrola a údržba

Koľko miesta kto zaberá (SQL editor):

```sql
select owner_id, count(*) as videos, pg_size_pretty(sum(size_bytes)) as used
from public.shared_videos group by owner_id order by sum(size_bytes) desc;
```

Celkové využitie a náklady: Cloudflare → R2 → `encore-media` → Metrics. Nastav si upozornenie na
výdavky (Billing → Notifications), napríklad pri 5 $.

## 9. Známe obmedzenia a ďalšie kroky

- **Overenie nákupu na serveri chýba.** Funkcia `record_app_store_transaction` verí appke, takže
  šikovný používateľ si vie nastaviť Premium a tým aj 50 GB. Oprava: serverová funkcia overí
  podpísaný doklad od Apple (po kúpe Developer účtu). Pred spustením nutné.
- Knižnica figúr, tance a trezor videí ešte používajú staré ukladanie (krok 3).
- Poznámky z Domova a Plán sú zatiaľ len v iPhone (krok 3, s odkazom, ktorý prežije nový iPhone).
- Kópiu, ktorú si partner uložil do svojich Fotiek, nevieme zmazať (rovnako ako WhatsApp).
- Automatické mazanie dlho nepozeraných kópií zatiaľ nie je; dá sa doplniť na serveri bez zmeny appky.
- Staré súbory v Supabase Storage (`encore-media`, ~4 MB) sa už nepoužívajú a dajú sa zmazať.
- Celú cestu s prihláseným používateľom (nahranie → partner prehrá) treba ešte vyskúšať na dvoch
  zariadeniach.

## 10. Čo je otestované

- Databáza (testy s vrátením zmien): limity 50 GB / 1 GB, odmietnutie odkazu do Fotiek na figúre,
  prijatie `r2:`, rozpracované video nikto nevidí, hotové vidí vlastník, cudzí nie, podvrhnutý kľúč
  odmietnutý, kontrola majiteľa.
- R2 cez nasadenú funkciu: nahranie 200, veľkosť sedí, stiahnutie 200 s rovnakým obsahom, väčší súbor
  odmietnutý 403, zmazanie.
- Bez prihlásenia obe funkcie vracajú 401.
- iOS testy: `VideoReferenceTests`, `SharedVideoPathTests`, `CanvasSyncTests`.
