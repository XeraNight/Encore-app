'use client'

import { useState } from 'react'
import { PLANS, type Billing } from '@/lib/site'
import AppStoreButton from './AppStoreButton'
import { IconCheck } from './Icons'

export default function PricingSection() {
  const [billing, setBilling] = useState<Billing>('annual')

  return (
    <section id="cennik" className="mx-auto max-w-6xl px-4 py-24 sm:px-6 sm:py-32">
      <div className="mx-auto max-w-2xl text-center">
        <p className="font-rounded text-xs font-black uppercase tracking-[0.2em] text-[#FFE088]">Cenník</p>
        <h2 className="font-serif mt-4 text-4xl font-bold tracking-tight text-white sm:text-5xl">Začni zadarmo. Pridaj, keď budeš chcieť.</h2>
        <p className="mt-4 text-lg text-white/70">
          Free ti ostane navždy. Plus a Premium si kúpiš priamo v aplikácii cez App Store a zrušíš kedykoľvek.
        </p>
      </div>

      <div className="mt-10 flex justify-center">
        <div className="inline-flex rounded-full border border-white/10 bg-white/5 p-1" role="tablist" aria-label="Spôsob platby">
          {(['monthly', 'annual'] as Billing[]).map((option) => {
            const active = billing === option
            return (
              <button
                key={option}
                role="tab"
                aria-selected={active}
                onClick={() => setBilling(option)}
                className={`min-h-11 rounded-full px-5 py-2 text-sm font-semibold transition ${
                  active ? 'bg-[#FFE088] text-black' : 'text-white/70 hover:text-white'
                }`}
              >
                {option === 'monthly' ? 'Mesačne' : 'Ročne'}
              </button>
            )
          })}
        </div>
      </div>

      <div className="mt-10 grid gap-5 lg:grid-cols-3">
        {PLANS.map((plan) => (
          <article
            key={plan.name}
            className={`relative flex flex-col rounded-3xl border p-7 ${
              plan.highlighted ? 'border-[#FFE088]/50 bg-[#FFE088]/[0.06]' : 'border-white/10 bg-white/[0.04]'
            }`}
          >
            {plan.highlighted && (
              <span className="absolute -top-3 left-7 rounded-full bg-[#FFE088] px-3 py-1 font-rounded text-[11px] font-black uppercase tracking-wider text-black">
                Najčastejšia voľba
              </span>
            )}
            <h3 className="text-xl font-semibold text-white">{plan.name}</h3>
            <p className="mt-1 text-sm text-white/65">{plan.tagline}</p>
            <p className="mt-6 flex items-baseline gap-2">
              <span className="text-4xl font-bold tracking-tight text-white">{plan.price[billing]}</span>
              {plan.name !== 'Free' && <span className="text-sm text-white/60">{billing === 'monthly' ? 'mesačne' : 'ročne'}</span>}
            </p>
            <p className="mt-1 h-5 text-sm text-[#FFE088]">{billing === 'annual' ? plan.annualSaving ?? '' : ''}</p>
            <ul className="mt-6 space-y-3 text-sm text-white/80">
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
        <p className="max-w-xl text-xs leading-relaxed text-white/55">
          Ceny sú v eurách vrátane DPH pre Slovensko. Predplatné sa obnovuje automaticky, kým ho nezrušíš aspoň 24 hodín
          pred koncom obdobia v Nastaveniach iPhonu. Platia <a href="/terms" className="underline hover:text-white">Podmienky používania</a>{' '}
          a <a href="/privacy" className="underline hover:text-white">Zásady ochrany súkromia</a>.
        </p>
      </div>
    </section>
  )
}
