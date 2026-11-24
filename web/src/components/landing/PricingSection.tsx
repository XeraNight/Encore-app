'use client'

import { useState, type KeyboardEvent } from 'react'
import { PLANS, type Billing } from '@/lib/site'
import AppStoreButton from './AppStoreButton'
import { IconCheck } from './Icons'

const BILLING_OPTIONS: Billing[] = ['monthly', 'annual']

export default function PricingSection() {
  const [billing, setBilling] = useState<Billing>('annual')

  const onTabKeyDown = (event: KeyboardEvent<HTMLButtonElement>, index: number) => {
    if (event.key !== 'ArrowRight' && event.key !== 'ArrowLeft') return
    event.preventDefault()
    const nextIndex = (index + (event.key === 'ArrowRight' ? 1 : -1) + BILLING_OPTIONS.length) % BILLING_OPTIONS.length
    const next = BILLING_OPTIONS[nextIndex]
    setBilling(next)
    document.getElementById(`billing-tab-${next}`)?.focus()
  }

  return (
    <section id="cennik" aria-labelledby="cennik-nadpis" className="mx-auto max-w-6xl px-5 py-24 sm:px-6 sm:py-28">
      <div className="mx-auto max-w-2xl text-center">
        <p className="font-rounded text-xs font-black uppercase tracking-[0.16em] text-[#FFE088]">ČLENSTVO A CENNÍK</p>
        <h2 id="cennik-nadpis" className="font-rounded mt-3 text-3xl font-black tracking-tight text-white sm:text-5xl">
          Viac času na tanec. Začni zadarmo.
        </h2>
        <p className="mt-4 text-lg text-white/75">
          Free ti ostane navždy: poznámky, parket a výsledky z KSIS. Plus a Premium si aktivuješ v aplikácii cez App Store a zrušíš kedykoľvek.
        </p>
      </div>

      <div className="mt-10 flex justify-center">
        <div
          className="inline-flex rounded-[16px] border border-white/10 bg-white/[0.07] p-1"
          role="tablist"
          aria-label="Spôsob platby"
        >
          {BILLING_OPTIONS.map((option, index) => {
            const active = billing === option
            return (
              <button
                key={option}
                id={`billing-tab-${option}`}
                type="button"
                role="tab"
                tabIndex={active ? 0 : -1}
                aria-selected={active}
                onClick={() => setBilling(option)}
                onKeyDown={(e) => onTabKeyDown(e, index)}
                className={`min-h-11 rounded-[12px] px-5 py-2 font-rounded text-sm font-bold transition active:scale-[0.97] ${
                  active ? 'bg-[#FFE088] text-[#080808] shadow-sm' : 'text-white/75 hover:text-white'
                }`}
              >
                {option === 'monthly' ? 'Mesačne' : 'Ročne · ušetríš 30 %'}
              </button>
            )
          })}
        </div>
      </div>

      <div className="mt-10 grid gap-5 lg:grid-cols-3">
        {PLANS.map((plan) => (
          <article
            key={plan.name}
            className={`group relative flex flex-col rounded-[20px] border p-7 transition ${
              plan.highlighted
                ? 'border-[#FFE088]/50 bg-[#FFE088]/[0.09] hover:border-[#FFE088]/75'
                : 'border-white/10 bg-white/[0.07] hover:border-white/20'
            }`}
          >
            {plan.highlighted && (
              <span className="absolute -top-3 left-7 rounded-full bg-[#FFE088] px-3.5 py-1 font-rounded text-[11px] font-black uppercase tracking-wider text-[#080808]">
                Najčastejšia voľba
              </span>
            )}
            <h3 className="font-rounded text-xl font-bold text-white">{plan.name}</h3>
            <p className="mt-1 text-sm text-white/75">{plan.tagline}</p>
            <p className="mt-6 flex items-baseline gap-2">
              <span className="font-rounded text-4xl font-black tracking-tight text-white tabular-nums">
                {plan.price[billing]}
              </span>
              {plan.name !== 'Free' && (
                <span className="text-sm text-white/70">{billing === 'monthly' ? 'mesačne' : 'ročne'}</span>
              )}
            </p>
            <p className="mt-1 h-5 font-rounded text-xs font-bold uppercase tracking-wider text-[#FFE088]">
              {billing === 'annual' ? plan.annualSaving ?? '' : ''}
            </p>
            <ul className="mt-6 space-y-3 border-t border-white/10 pt-5 text-sm text-white/85">
              {plan.features.map((feature) => (
                <li key={feature} className="flex gap-3">
                  <IconCheck className="mt-0.5 h-4 w-4 flex-none text-[#FFE088]" />
                  <span>{feature}</span>
                </li>
              ))}
            </ul>
          </article>
        ))}
      </div>

      <div className="mt-10 flex flex-col items-center gap-4 text-center">
        <AppStoreButton />
        <p className="max-w-xl text-xs leading-relaxed text-white/65">
          Ceny sú v eurách vrátane DPH pre Slovensko. Predplatné sa obnovuje automaticky, kým ho nezrušíš aspoň 24 hodín
          pred koncom obdobia v Nastaveniach iPhonu. Platia{' '}
          <a href="/terms" className="underline hover:text-white">
            Podmienky používania
          </a>{' '}
          a{' '}
          <a href="/privacy" className="underline hover:text-white">
            Zásady ochrany súkromia
          </a>
          .
        </p>
      </div>
    </section>
  )
}
