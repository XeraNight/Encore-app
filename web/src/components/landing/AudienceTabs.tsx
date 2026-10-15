'use client'

import { useState } from 'react'
import { IconCheck } from './Icons'

const AUDIENCES = [
  {
    id: 'dancer',
    label: 'Tanečník',
    title: 'Vieš, na čom pracuješ. Každý týždeň.',
    points: [
      'Top 3 korekcie od trénera máš na Domove, kým ich nezvládneš.',
      'Samotréning s cieľom a krátka reflexia po každom tréningu.',
      'Týždeň v číslach: hodiny, samotréning a tanec, ktorý si riešil najviac.',
    ],
  },
  {
    id: 'couple',
    label: 'Pár',
    title: 'Jedna zostava. Obaja ju tancujete rovnako.',
    points: [
      'Spoločné zostavy a figúry, ktoré sa obom zosynchronizujú.',
      'Videá z tréningu zdieľané len medzi vami a trénerom.',
      'Výsledky páru z KSIS v denníku aj kalendári.',
    ],
  },
  {
    id: 'coach',
    label: 'Tréner',
    title: 'Poznámky priamo do zostáv tvojich párov.',
    points: [
      'Zverenci ti zdieľajú zostavy, ty do nich píšeš korekcie.',
      'Hosťujúci tréner dostane kľúč k jednej zostave, bez účtu navyše.',
      'S Premium vidíš pri každom páre, čo ste robili na poslednej lekcii.',
    ],
  },
]

/** Tanečník, Pár, Tréner: roles, not plans (a coach can use Free too). */
export default function AudienceTabs() {
  const [active, setActive] = useState(AUDIENCES[0].id)
  const audience = AUDIENCES.find((item) => item.id === active) ?? AUDIENCES[0]

  return (
    <section id="pre-koho" className="mx-auto max-w-6xl px-4 py-24 sm:px-6 sm:py-32">
      <div className="mx-auto max-w-2xl text-center">
        <p className="font-rounded text-xs font-black uppercase tracking-[0.2em] text-[#FFE088]">Pre koho</p>
        <h2 className="font-serif mt-4 text-4xl font-bold tracking-tight text-white sm:text-5xl">Pre každého na parkete.</h2>
      </div>

      <div className="mt-10 flex justify-center">
        <div className="inline-flex rounded-full border border-white/10 bg-white/5 p-1" role="tablist" aria-label="Pre koho">
          {AUDIENCES.map((item) => {
            const isActive = item.id === active
            return (
              <button
                key={item.id}
                role="tab"
                aria-selected={isActive}
                aria-controls="audience-panel"
                onClick={() => setActive(item.id)}
                className={`min-h-11 rounded-full px-5 py-2 text-sm font-semibold transition ${
                  isActive ? 'bg-[#FFE088] text-black' : 'text-white/70 hover:text-white'
                }`}
              >
                {item.label}
              </button>
            )
          })}
        </div>
      </div>

      <div id="audience-panel" role="tabpanel" className="mx-auto mt-10 max-w-3xl rounded-3xl border border-white/10 bg-white/[0.04] p-8 sm:p-10">
        <h3 key={audience.id} className="text-2xl font-semibold tracking-tight text-white">
          {audience.title}
        </h3>
        <ul className="mt-6 space-y-4">
          {audience.points.map((point) => (
            <li key={point} className="flex gap-3 text-white/80">
              <IconCheck className="mt-1 h-5 w-5 flex-none text-[#FFE088]" />
              <span>{point}</span>
            </li>
          ))}
        </ul>
      </div>
    </section>
  )
}
