# 🌐 ENCORE WEB — Architektúra & Špecifikácia Realtime Webovej Verzie pre Android & Desktop

> **Dátum:** August 2026  
> **Účel:** Špecifikácia, porovnanie a plán vývoja webovej verzie pre tanečníkov s Androidom a trénerov na PC/Macu, prepojenej na rovnaký Supabase Realtime backend ako iOS aplikácia Encore.

---

## 🔍 1. Porovnanie: Školský Projekt vs. Encore iOS vs. Budúci Web

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   ARCHITEKTÚRNE POROVNANIE                                      │
├───────────────────────┬───────────────────────────────┬─────────────────────────────────────────┤
│ 🏫 Bývalý Projekt      │ 📱 Súčasný Encore (iOS)    │ 🌐 Budúci Encore Web (Android / PC)  │
│ (ballroom-note-taking)│ (Natívny Swift & SwiftData)   │ (Next.js 15, React 19, Supabase Realtime)│
├───────────────────────┼───────────────────────────────┼─────────────────────────────────────────┤
│ • Statický Next.js    │ • 100% Natívne iOS (SwiftUI)  │ • Next.js 15 (App Router) + TypeScript │
│ • Lokálny Node backend│ • SwiftData (SQLite) offline  │ • Priame napojenie na Supabase DB       │
│ • Žiadny Realtime     │ • Supabase WebSockets (50ms)  │ • Supabase Realtime WebSockets (50ms)   │
│ • Fixná mriežka       │ • Nekonečný 3000pt Canvas     │ • Nekonečný Panning/Zooming Canvas      │
│ • Bez videa           │ • Video Vault + Dual Porovnávač│ • Web Video Vault + Side-by-Side Player │
│ • Bez synchronizácie  │ • Live Activity, Dynamic Isl. │ • PWA podpora pre inštaláciu na Android │
└───────────────────────┴───────────────────────────────┴─────────────────────────────────────────┘
```

---

## 🎨 2. Vizuálny Dizajn & Inšpirácia (Ellegance + Encore)

Pre webovú verziu skombinujeme to najlepšie z dvoch svetov:

1. **Značka Ellegance (z projektu `Ellegance website`):**
   - **Farby:** Obsidian Black (`#050505`, `#0a0a0a`), Gold akcenty (`#D4AF37`, `#FFE088`), jemné sklenené panely (Glassmorphism).
   - **Typografia:** *Plus Jakarta Sans* pre nadpisy a čísla taktov, *Inter / Outfit* pre čisté čítanie na mobiloch.
2. **Ergonómia Encore (z našej iOS aplikácie):**
   - Hrubé, vysoko kontrastné ohraničenia kariet (čitateľné aj na diaľku na parkete).
   - Farebné odznaky: 🔵 **Standard Blue** pre štandardné tance, 🔴 **Latin Red / Pink** pre latinskoamerické tance.
   - Spodný plávajúci ovládací dok prispôsobený pre dotyk jedným palcom na Android telefónoch.

---

## ⚙️ 3. Dátová & Realtime Logika (Prepojenie s iOS)

Android používateľ a iOS používateľ budú **v tej istej sekunde vidieť rovnaký parket**:

```
           📱 iPhone Partner A (iOS App)
                         │ (WebSocket Broadcast)
                         ▼
        ┌──────────────────────────────────┐
        │  ☁️ SUPABASE REALTIME CLUSTER     │
        │  • PostgreSQL DB                 │
        │  • Presence Channel              │
        │  • Broadcast channel: routine_id │
        └──────────────────────────────────┘
                         ▲
                         │ (WebSocket Broadcast)
           🌐 Android Partner B (Web App)
```

### Spoločné Dátové Tabuľky (1:1 kompatibilita):
- `routines` — choreografie (id, name, dance_name, dance_category, updated_at).
- `canvas_nodes` — figúry na parkete (id, routine_id, x, y, figure_name, rhythm, notes, video_path, order_index, transition_notes).
- `figure_library_items` — globálna knižnica figúr.
- `video_media_vault` — archív tréningových videí a vzorov.

---

## 🚀 4. Kľúčové Funkcie Webovej Verzie pre Android

1. **🎯 2D Realtime Parket (Canvas):**
   - Plynulý pan a zoom s dotykovými gestami (Pinch-to-zoom na Androide).
   - Kreslenie Bezier kriviek medzi figúrami (inšpirované z `ballroom-note-taking-app/LineupEditor.js`).
   - Zobrazenie živého kurzora partnera (Partner Cursor & Presence).
2. **🗄️ Web Video Vault & Dual Player:**
   - Možnosť prehrať video figúry aj na Androide cez HTML5 Video API.
   - Side-by-Side porovnávač dvoch videí so spoločným posuvníkom času a offsetom.
3. **📲 PWA (Progressive Web App):**
   - Možnosť pridať si webovú appku priamo na domovskú plochu Androidu cez *„Pridať na plochu“* (beží na celú obrazovku bez URL lišty prehliadača).
4. **🔒 Bezpečnosť & Auth:**
   - Prihlásenie cez Google OAuth alebo e-mail + heslo cez Supabase Auth.
   - Automatická synchronizácia s účtom vytvoreným na iPhone.

---

## 📋 5. Technologický Stack pre Web:
- **Framework:** Next.js 15 (React 19, TypeScript)
- **Styling:** Tailwind CSS v4 + Shadcn UI (z Ellegance website)
- **Gestá & Drag-and-Drop:** `@dnd-kit/core` + `@use-gesture/react`
- **Realtime & Backend:** `@supabase/supabase-js` (PostgreSQL + Realtime WebSockets)
- **Canvas Rendering:** SVG Bezier Paths + HTML5 Canvas / Framer Motion
