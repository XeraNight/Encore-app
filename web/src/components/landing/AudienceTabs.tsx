'use client'

import { useState, type KeyboardEvent } from 'react'
import Image from 'next/image'
import { IconCheck } from './Icons'

const AUDIENCES = [
  {
    id: 'dancer',
    label: 'Tanečník',
    eyebrow: 'SAMOTRÉNING A LEKCIE',
    title: 'Vieš, na čom pracuješ. Každý týždeň.',
    image: '/images/hero_ballroom_floor.jpg',
    imageAlt: 'Tanečné topánky a iPhone na parkete počas tréningu',
    points: [
      'Rýchly zápis po lekcii (Text, Hlas, Kamera) rovno k vybranému tancu v Denníku.',
      'Top 3 priority od trénera máš na Domove a pred súťažným kolom, kým ich nezvládneš.',
      'Kalendár tréningov, samotréningov a súťaží s rýchlym tlačidlom Nejdem.',
    ],
  },
  {
    id: 'couple',
    label: 'Pár',
    eyebrow: 'TANEČNÝ PÁR A KSIS',
    title: 'Tanečný pár. Každý vo svojom mobile.',
    image: '/images/training_couple.jpg',
    imageAlt: 'Tanečný pár na parkete pozerá zostavu v iPhone',
    points: [
      'Kópiu svojej zostavy na 2D parkete pošleš partnerovi cez QR kód za sekundu.',
      'Spojenie si môžeš označiť ako Pár (partner to potvrdí vo svojom Encore).',
      'Výsledky páru, body a krížiky porotcov z KSIS uložené jedným ťuknutím do histórie.',
    ],
  },
]

/** Tanečník and Pár: roles, not plans. Coach tools come in a later version. */
export default function AudienceTabs() {
  const [active, setActive] = useState(AUDIENCES[0].id)
  const audience = AUDIENCES.find((item) => item.id === active) ?? AUDIENCES[0]

  const onTabKeyDown = (event: KeyboardEvent<HTMLButtonElement>, index: number) => {
    if (event.key !== 'ArrowRight' && event.key !== 'ArrowLeft') return
    event.preventDefault()
    const nextIndex = (index + (event.key === 'ArrowRight' ? 1 : -1) + AUDIENCES.length) % AUDIENCES.length
    const next = AUDIENCES[nextIndex]
    setActive(next.id)
    document.getElementById(`audience-tab-${next.id}`)?.focus()
  }

  return (
    <section id="pre-koho" aria-labelledby="pre-koho-nadpis" className="mx-auto max-w-6xl px-5 py-24 sm:px-6 sm:py-28">
      <div className="mx-auto max-w-2xl text-center">
        <p className="font-rounded text-xs font-black uppercase tracking-[0.16em] text-[#FFE088]">PRE KOHO JE ENCORE</p>
        <h2 id="pre-koho-nadpis" className="font-rounded mt-3 text-3xl font-black tracking-tight text-white sm:text-5xl">
          Pre každého na parkete.
        </h2>
      </div>

      <div className="mt-10 flex justify-center">
        <div
          className="inline-flex rounded-full border border-white/10 bg-white/[0.07] p-1"
          role="tablist"
          aria-label="Pre koho"
        >
          {AUDIENCES.map((item, index) => {
            const isActive = item.id === active
            return (
              <button
                key={item.id}
                id={`audience-tab-${item.id}`}
                type="button"
                role="tab"
                tabIndex={isActive ? 0 : -1}
                aria-selected={isActive}
                aria-controls="audience-panel"
                onClick={() => setActive(item.id)}
                onKeyDown={(e) => onTabKeyDown(e, index)}
                className={`min-h-11 rounded-full px-6 py-2 font-rounded text-sm font-bold transition active:scale-[0.97] ${
                  isActive ? 'bg-[#FFE088] text-[#080808] shadow-sm' : 'text-white/75 hover:text-white'
                }`}
              >
                {item.label}
              </button>
            )
          })}
        </div>
      </div>

      <div
        id="audience-panel"
        role="tabpanel"
        aria-labelledby={`audience-tab-${audience.id}`}
        className="group mx-auto mt-10 grid max-w-5xl items-center gap-8 overflow-hidden rounded-[20px] border border-white/10 bg-white/[0.07] p-6 transition hover:border-white/20 sm:p-9 lg:grid-cols-[1.15fr_0.85fr]"
      >
        <div>
          <p className="font-rounded text-xs font-black uppercase tracking-[0.14em] text-[#FFE088]">{audience.eyebrow}</p>
          <h3 key={audience.id} className="font-rounded mt-2 text-2xl font-black tracking-tight text-white sm:text-3xl">
            {audience.title}
          </h3>
          <ul className="mt-6 space-y-4">
            {audience.points.map((point) => (
              <li key={point} className="flex gap-3 text-[15px] leading-relaxed text-white/85">
                <IconCheck className="mt-1 h-5 w-5 flex-none text-[#FFE088]" />
                <span>{point}</span>
              </li>
            ))}
          </ul>
        </div>
        <div className="relative aspect-[4/3] w-full overflow-hidden rounded-[16px] border border-white/10 bg-[#140206]">
          <Image
            key={audience.image}
            src={audience.image}
            alt={audience.imageAlt}
            fill
            sizes="(min-width: 1024px) 380px, 90vw"
            className="object-cover"
          />
          <div
            aria-hidden="true"
            className="pointer-events-none absolute inset-0 bg-gradient-to-t from-[#140206]/70 via-transparent to-transparent"
          />
        </div>
      </div>
    </section>
  )
}
