'use client'

import { useEffect, useRef, useState, type CSSProperties } from 'react'

interface SignalPill {
  id: string
  text: string
  priority?: boolean
  cx: number
  cy: number
  rot: number
}

const SIGNALS: SignalPill[] = [
  { id: 'elbow', text: 'Ľavý lakeť vyššie v držaní', priority: true, cx: 280, cy: -102, rot: 8 },
  { id: 'rise', text: 'Rise až na druhej dobe', priority: true, cx: 345, cy: -20, rot: -10 },
  { id: 'step1', text: 'Dlhší krok na prvej dobe', priority: true, cx: 235, cy: 64, rot: 6 },
  { id: 'zasvih', text: 'Zášvih po krátkej stene', cx: 370, cy: -80, rot: -7 },
  { id: 'shoulder', text: 'Nezalamovať pravé rameno', cx: 195, cy: -58, rot: 11 },
  { id: 'rumba', text: 'Rumba Walk cez celé chodidlo', cx: 320, cy: 32, rot: 9 },
  { id: 'head', text: 'Hlavu viac vľavo v Reverse Turn', cx: 260, cy: 4, rot: -6 },
  { id: 'lock', text: 'Lock Step bližšie k sebe', cx: 160, cy: 36, rot: -11 },
  { id: 'feather', text: 'Feather Step plynulý švih', cx: 360, cy: -4, rot: 10 },
  { id: 'running', text: 'Ramená dole v Running Finish', cx: 295, cy: 88, rot: -8 },
]

const PRIORITIES = [
  'Ľavý lakeť vyššie v držaní',
  'Rise až na druhej dobe',
  'Dlhší krok na prvej dobe',
]

function easeOutCubic(t: number): number {
  const clamped = Math.max(0, Math.min(1, t))
  return 1 - Math.pow(1 - clamped, 3)
}

/**
 * Scroll-driven "Chaos -> Order" narrative:
 * Drives all transforms directly through a single CSS custom property (--p) via rAF
 * so scrolling triggers ZERO React re-renders (silky 120fps on ProMotion displays).
 */
export default function ChaosToOrderSection() {
  const trackRef = useRef<HTMLDivElement>(null)
  const orderedRef = useRef(false)
  const [isOrdered, setIsOrdered] = useState(false)
  const [reducedMotion, setReducedMotion] = useState(false)
  const [mobileOrdered, setMobileOrdered] = useState(false)
  const [doneItems, setDoneItems] = useState<number[]>([])

  useEffect(() => {
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)')
    const syncMotion = () => {
      setReducedMotion(mq.matches)
      if (mq.matches) {
        trackRef.current?.style.setProperty('--p', '1')
        trackRef.current?.style.setProperty('--cp', '1')
        orderedRef.current = true
        setIsOrdered(true)
        setMobileOrdered(true)
      }
    }
    syncMotion()
    mq.addEventListener('change', syncMotion)
    return () => mq.removeEventListener('change', syncMotion)
  }, [])

  useEffect(() => {
    if (reducedMotion) return
    let rafId = 0

    const update = () => {
      rafId = 0
      const el = trackRef.current
      if (!el) return
      const rect = el.getBoundingClientRect()
      const scrollable = Math.max(1, el.offsetHeight - window.innerHeight)
      const raw = Math.max(0, Math.min(1, -rect.top / scrollable))
      const eased = easeOutCubic(raw)
      const card = easeOutCubic((raw - 0.16) / 0.66)

      // Update CSS variables directly on DOM — zero React re-renders during scroll!
      el.style.setProperty('--p', eased.toFixed(4))
      el.style.setProperty('--cp', card.toFixed(4))

      const nowOrdered = eased > 0.56
      if (nowOrdered !== orderedRef.current) {
        orderedRef.current = nowOrdered
        setIsOrdered(nowOrdered)
      }
    }

    const onScroll = () => {
      if (!rafId) rafId = requestAnimationFrame(update)
    }

    update()
    window.addEventListener('scroll', onScroll, { passive: true })
    window.addEventListener('resize', onScroll, { passive: true })
    return () => {
      if (rafId) cancelAnimationFrame(rafId)
      window.removeEventListener('scroll', onScroll)
      window.removeEventListener('resize', onScroll)
    }
  }, [reducedMotion])

  const toggleDone = (index: number) => {
    setDoneItems((prev) => (prev.includes(index) ? prev.filter((i) => i !== index) : [...prev, index]))
  }

  return (
    <section
      aria-labelledby="chaos-nadpis"
      className="relative border-t border-[#23090C]/10 bg-[#F6E9CE] text-[#23090C]"
    >
      {/* Desktop Sticky Scrollytelling Track */}
      <div
        ref={trackRef}
        style={{ ['--p' as string]: reducedMotion ? 1 : 0, ['--cp' as string]: reducedMotion ? 1 : 0 }}
        className="relative hidden lg:block lg:h-[185vh]"
      >
        <div className="sticky top-16 flex h-[calc(100dvh-4rem)] items-center overflow-x-clip">
          <div className="mx-auto grid w-full max-w-6xl grid-cols-[1.12fr_0.88fr] items-center gap-10 px-6 py-8">
            {/* Left Column: Copy + GPU-driven Signal Pills */}
            <div className="relative z-10">
              <p className="font-rounded text-xs font-black uppercase tracking-[0.18em] text-[#7A0A1B]">
                Z CHAOSU PO LEKCII DO PORIADKU
              </p>
              <h2
                id="chaos-nadpis"
                className="font-rounded mt-3 max-w-xl text-4xl font-black leading-[1.04] tracking-tight text-[#23090C] xl:text-5xl"
              >
                Dvadsať pokynov za hodinu.{' '}
                <span className="text-[#7A0A1B]">Tri priority na ďalší tréning.</span>
              </h2>
              <p className="mt-4 max-w-lg text-base leading-relaxed text-[#23090C]/75 xl:text-[17px]">
                Po lekcii máš hlavu plnú opráv z parketu, správ v chate a videí v galérii. Encore šum odloží bokom a na
                Domove ti nechá len to, čo má zmeniť tvoj najbližší tréning.
              </p>

              {/* Transforming Signal Pills (pure CSS var GPU transform) */}
              <div className="relative mt-7 flex flex-wrap gap-2">
                {SIGNALS.map((pill) => {
                  const highlight = Boolean(pill.priority && isOrdered)
                  const pillStyle: CSSProperties = {
                    ['--cx' as string]: `${pill.cx}px`,
                    ['--cy' as string]: `${pill.cy}px`,
                    ['--rot' as string]: `${pill.rot}deg`,
                    transform:
                      'translate3d(calc(var(--cx) * (1 - var(--p))), calc(var(--cy) * (1 - var(--p))), 0) rotate(calc(var(--rot) * (1 - var(--p))))',
                    opacity: pill.priority ? 1 : 'calc(0.68 + (1 - var(--p)) * 0.32)',
                  }
                  return (
                    <span
                      key={pill.id}
                      style={pillStyle}
                      className={`inline-flex items-center rounded-full border px-3.5 py-1.5 font-rounded text-[13px] font-bold whitespace-nowrap transition-colors duration-300 ${
                        highlight
                          ? 'border-[#5C0614] bg-[#5C0614] text-[#FFE8A3] shadow-[0_8px_20px_-6px_rgba(92,6,20,0.45)]'
                          : 'border-[#23090C]/25 bg-[#FBF2DF] text-[#23090C] shadow-[0_4px_14px_-6px_rgba(35,9,12,0.18)]'
                      }`}
                    >
                      {pill.text}
                    </span>
                  )
                })}
              </div>

              <div className="mt-6 flex items-center gap-3 text-xs font-bold uppercase tracking-[0.14em] text-[#23090C]/55">
                <span className="h-1.5 w-24 overflow-hidden rounded-full bg-[#23090C]/12">
                  <span
                    className="block h-full origin-left rounded-full bg-[#7A0A1B]"
                    style={{ transform: 'scaleX(max(0.08, var(--p)))' }}
                  />
                </span>
                <span>{isOrdered ? 'Upratané do 3 priorít' : 'Scrolluj nadol'}</span>
              </div>
            </div>

            {/* Right Column: Distilled §1A Crimson Priority Card (pure CSS var GPU transform) */}
            <div
              className="relative z-20"
              style={{
                opacity: 'var(--cp)',
                transform:
                  'translate3d(0, calc((1 - var(--cp)) * 34px), 0) scale(calc(0.95 + var(--cp) * 0.05))',
                pointerEvents: isOrdered || reducedMotion ? 'auto' : 'none',
              }}
            >
              <div className="rounded-[24px] border border-[#FFE088]/25 bg-[radial-gradient(90%_75%_at_20%_10%,#7C0B1E_0%,#470410_58%,#250208_100%)] p-7 text-white shadow-[0_32px_70px_-24px_rgba(35,9,12,0.5)] xl:p-8">
                <div className="flex items-center justify-between font-rounded text-[11px] font-black uppercase tracking-[0.16em] text-[#FFE088]/85">
                  <span>PO LEKCII · WALTZ</span>
                  <span>TOP 3 PRIORITY</span>
                </div>

                <h3 className="font-rounded mt-3.5 text-2xl font-black leading-[1.12] tracking-tight text-[#FFF3CF] xl:text-3xl">
                  Držanie, zdvih a prvý krok.
                </h3>

                <ul className="mt-5 space-y-3 border-t border-white/15 pt-5">
                  {PRIORITIES.map((item, idx) => {
                    const isDone = doneItems.includes(idx)
                    return (
                      <li key={item}>
                        <button
                          type="button"
                          onClick={() => toggleDone(idx)}
                          aria-pressed={isDone}
                          className="flex w-full items-center gap-3.5 rounded-xl px-2 py-1.5 text-left transition hover:bg-white/[0.06]"
                        >
                          <span
                            className={`flex h-7 w-7 flex-none items-center justify-center rounded-full border font-rounded text-xs font-black transition ${
                              isDone
                                ? 'border-[#FFE088] bg-[#FFE088] text-[#1C0408]'
                                : 'border-[#FFE088]/65 text-[#FFE088]'
                            }`}
                          >
                            {isDone ? '✓' : idx + 1}
                          </span>
                          <span
                            className={`text-[15px] font-medium transition ${
                              isDone ? 'text-white/45 line-through' : 'text-white/95'
                            }`}
                          >
                            {item}
                          </span>
                        </button>
                      </li>
                    )
                  })}
                </ul>

                <div className="mt-6 flex flex-wrap items-center gap-2 border-t border-white/15 pt-5">
                  <button
                    type="button"
                    onClick={() => setDoneItems(doneItems.length === 3 ? [] : [0, 1, 2])}
                    className="rounded-full bg-[#FFE088] px-4 py-2 font-rounded text-xs font-black text-[#1C0408] transition hover:brightness-105 active:scale-95"
                  >
                    {doneItems.length === 3 ? 'Vrátiť späť' : 'Všetko zvládnuté'}
                  </button>
                  <a
                    href="#funkcie"
                    className="rounded-full border border-white/25 px-4 py-2 font-rounded text-xs font-bold text-white/85 transition hover:border-[#FFE088]/60 hover:text-white"
                  >
                    Pozrieť v apke
                  </a>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Mobile Compact Interactive Version (< lg) */}
      <div className="mx-auto max-w-2xl px-5 py-20 lg:hidden">
        <p className="font-rounded text-xs font-black uppercase tracking-[0.16em] text-[#7A0A1B]">
          Z CHAOSU PO LEKCII DO PORIADKU
        </p>
        <h2 className="font-rounded mt-3 text-3xl font-black leading-[1.08] tracking-tight text-[#23090C] sm:text-4xl">
          Dvadsať pokynov za hodinu.{' '}
          <span className="text-[#7A0A1B]">Tri priority na ďalší tréning.</span>
        </h2>
        <p className="mt-4 text-base leading-relaxed text-[#23090C]/75">
          Encore odloží šum bokom a na Domove ti nechá len tri korekcie, na ktorých naozaj záleží.
        </p>

        <div className="mt-6 inline-flex rounded-full border border-[#23090C]/15 bg-[#EFE0BD] p-1">
          <button
            type="button"
            onClick={() => setMobileOrdered(false)}
            className={`min-h-10 rounded-full px-4 font-rounded text-xs font-black transition ${
              !mobileOrdered ? 'bg-[#5C0614] text-[#FFE8A3]' : 'text-[#23090C]/70'
            }`}
          >
            Hlava po lekcii
          </button>
          <button
            type="button"
            onClick={() => setMobileOrdered(true)}
            className={`min-h-10 rounded-full px-4 font-rounded text-xs font-black transition ${
              mobileOrdered ? 'bg-[#5C0614] text-[#FFE8A3]' : 'text-[#23090C]/70'
            }`}
          >
            V Encore
          </button>
        </div>

        {!mobileOrdered ? (
          <div className="mt-6 flex flex-wrap gap-2">
            {SIGNALS.slice(0, 8).map((pill, i) => (
              <span
                key={pill.id}
                style={{ transform: reducedMotion ? 'none' : `rotate(${(i % 2 === 0 ? 1 : -1) * ((i % 3) + 1.5)}deg)` }}
                className="inline-flex rounded-full border border-[#23090C]/25 bg-[#FBF2DF] px-3.5 py-1.5 font-rounded text-xs font-bold text-[#23090C]"
              >
                {pill.text}
              </span>
            ))}
          </div>
        ) : (
          <div className="mt-6 rounded-[20px] border border-[#FFE088]/25 bg-[radial-gradient(90%_75%_at_20%_10%,#7C0B1E_0%,#470410_58%,#250208_100%)] p-6 text-white shadow-xl">
            <p className="font-rounded text-[11px] font-black uppercase tracking-[0.16em] text-[#FFE088]">
              TOP 3 PRIORITY · WALTZ
            </p>
            <ul className="mt-4 space-y-3">
              {PRIORITIES.map((item, idx) => (
                <li key={item} className="flex items-center gap-3 text-sm font-medium text-white/95">
                  <span className="flex h-6 w-6 flex-none items-center justify-center rounded-full border border-[#FFE088]/70 font-rounded text-xs font-black text-[#FFE088]">
                    {idx + 1}
                  </span>
                  <span>{item}</span>
                </li>
              ))}
            </ul>
          </div>
        )}
      </div>
    </section>
  )
}
