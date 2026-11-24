'use client'

import { useEffect, useRef, useState } from 'react'
import PhoneFrame from './PhoneFrame'
import { IconCalendar, IconCheck, IconFloor, IconMic, IconTrophy } from './Icons'

export interface SplitFeatureItem {
  id: string
  step: string
  eyebrow: string
  iconName: 'mic' | 'floor' | 'calendar' | 'trophy'
  title: string
  text: string
  points: string[]
  screen?: string
  video?: string
  screenLabel: string
  note?: string
}

function FeatureIcon({ name, className }: { name: SplitFeatureItem['iconName']; className?: string }) {
  switch (name) {
    case 'mic':
      return <IconMic className={className} />
    case 'floor':
      return <IconFloor className={className} />
    case 'calendar':
      return <IconCalendar className={className} />
    case 'trophy':
      return <IconTrophy className={className} />
  }
}

/**
 * Framed two-tone sticky feature showcase on warm champagne cream (#F6E9CE):
 * - Left column holds a rounded Encore crimson velvet monolith (sticky) so there are ZERO
 *   jagged half-width L-seams at the top or bottom of the section!
 * - Only the active chapter's <PhoneVideo> decodes/plays (active={isActive}), cutting GPU video load by 75%.
 */
export default function FeatureSplitShowcase({ features }: { features: SplitFeatureItem[] }) {
  const [activeIndex, setActiveIndex] = useState(0)
  const chapterRefs = useRef<(HTMLElement | null)[]>([])

  useEffect(() => {
    const nodes = chapterRefs.current.filter((n): n is HTMLElement => n !== null)
    if (nodes.length === 0) return

    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue
          const idx = Number((entry.target as HTMLElement).dataset.index)
          if (!Number.isNaN(idx)) setActiveIndex(idx)
        }
      },
      { rootMargin: '-36% 0px -36% 0px', threshold: 0.01 },
    )

    nodes.forEach((node) => observer.observe(node))
    return () => observer.disconnect()
  }, [features.length])

  const jumpTo = (index: number) => {
    setActiveIndex(index)
    chapterRefs.current[index]?.scrollIntoView({ behavior: 'smooth', block: 'center' })
  }

  return (
    <section
      id="funkcie"
      aria-label="Hlavné funkcie Encore"
      className="relative bg-[#F6E9CE] text-[#23090C]"
    >
      {/* Desktop Framed Two-Tone Sticky Split (clean full-width cream canvas -> clean horizontal exit to dark velvet) */}
      <div className="mx-auto hidden max-w-6xl gap-12 px-6 py-16 lg:grid lg:grid-cols-[0.95fr_1.05fr] xl:gap-16">
        {/* Left Sticky Stage: Framed Rounded Crimson Velvet Monolith */}
        <div className="relative">
          <div className="sticky top-24 flex h-[calc(100dvh-7.5rem)] max-h-[760px] flex-col items-center justify-center gap-5 rounded-[28px] border border-[#FFE088]/20 bg-[radial-gradient(85%_65%_at_50%_30%,#6E0819_0%,#42040E_55%,#1E0207_100%)] px-8 py-6 shadow-[0_32px_80px_-28px_rgba(35,9,12,0.5)]">
            {/* Viewport-height-fitted iPhone: ALWAYS fits 100% inside the velvet card with clean breathing room */}
            <div className="relative w-[min(238px,calc((100dvh-16rem)*0.45))]">
              <div className="aspect-[1179/2556] w-full" aria-hidden="true" />
              {features.map((feature, index) => {
                const isActive = index === activeIndex
                return (
                  <div
                    key={feature.id}
                    aria-hidden={!isActive}
                    className={`absolute inset-0 transition-all duration-400 ease-out motion-reduce:transition-none ${
                      isActive
                        ? 'z-10 translate-y-0 scale-100 opacity-100'
                        : 'pointer-events-none z-0 translate-y-2 scale-[0.97] opacity-0'
                    }`}
                  >
                    <PhoneFrame
                      src={feature.screen}
                      video={feature.video}
                      active={isActive}
                      alt={feature.screenLabel}
                    />
                  </div>
                )
              })}
            </div>

            {/* Interactive Chapter Switcher Pills */}
            <div className="flex items-center gap-2" role="tablist" aria-label="Prepínač obrazoviek apky">
              {features.map((feature, index) => {
                const isActive = index === activeIndex
                return (
                  <button
                    key={feature.id}
                    type="button"
                    role="tab"
                    aria-selected={isActive}
                    onClick={() => jumpTo(index)}
                    className={`min-h-9 rounded-full px-3.5 font-rounded text-xs font-black tracking-wider transition ${
                      isActive
                        ? 'bg-[#FFE088] text-[#1C0408] shadow-sm'
                        : 'border border-white/20 bg-white/[0.06] text-white/75 hover:border-[#FFE088]/50 hover:text-white'
                    }`}
                  >
                    {feature.step}
                  </button>
                )
              })}
            </div>
          </div>
        </div>

        {/* Right Editorial Column: Warm Champagne Cream Chapters */}
        <div>
          {features.map((feature, index) => {
            const isActive = index === activeIndex
            return (
              <article
                key={feature.id}
                id={feature.id}
                data-index={index}
                ref={(el) => {
                  chapterRefs.current[index] = el
                }}
                className={`flex min-h-[64dvh] flex-col justify-center py-12 transition-opacity duration-300 ${
                  index < features.length - 1 ? 'border-b border-[#23090C]/15' : ''
                } ${isActive ? 'opacity-100' : 'opacity-55 hover:opacity-85'}`}
              >
                <p className="flex items-center gap-2 font-rounded text-xs font-black uppercase tracking-[0.16em] text-[#7A0A1B]">
                  <FeatureIcon name={feature.iconName} className="h-4 w-4" />
                  <span>{feature.step} · {feature.eyebrow}</span>
                </p>
                <h2 className="font-rounded mt-3.5 text-3xl font-black leading-[1.1] tracking-tight text-[#23090C] xl:text-[2.15rem]">
                  {feature.title}
                </h2>
                <p className="mt-4 text-base leading-relaxed text-[#23090C]/80 xl:text-[17px]">{feature.text}</p>
                <ul className="mt-6 space-y-2.5 border-t border-[#23090C]/12 pt-5">
                  {feature.points.map((point) => (
                    <li key={point} className="flex gap-3 text-[15px] leading-relaxed text-[#23090C]/85">
                      <IconCheck className="mt-1 h-4 w-4 flex-none text-[#7A0A1B]" />
                      <span>{point}</span>
                    </li>
                  ))}
                </ul>
                {feature.note && <p className="mt-5 text-xs text-[#23090C]/60">{feature.note}</p>}
              </article>
            )
          })}
        </div>
      </div>

      {/* Mobile Stacked Two-Tone Cards (< lg) */}
      <div className="space-y-7 px-5 py-16 lg:hidden">
        {features.map((feature) => (
          <article
            key={feature.id}
            id={`${feature.id}-mobile`}
            className="overflow-hidden rounded-[22px] border border-[#23090C]/12 bg-[#FBF2DF] shadow-md"
          >
            <div className="flex justify-center bg-[radial-gradient(85%_65%_at_50%_30%,#6E0819_0%,#3D040D_60%,#1E0207_100%)] px-8 py-8">
              <div className="w-[min(220px,58vw)]">
                <PhoneFrame src={feature.screen} video={feature.video} alt={feature.screenLabel} />
              </div>
            </div>
            <div className="p-6">
              <p className="flex items-center gap-2 font-rounded text-[11px] font-black uppercase tracking-[0.15em] text-[#7A0A1B]">
                <FeatureIcon name={feature.iconName} className="h-4 w-4" />
                <span>{feature.step} · {feature.eyebrow}</span>
              </p>
              <h2 className="font-rounded mt-3 text-2xl font-black leading-tight text-[#23090C]">
                {feature.title}
              </h2>
              <p className="mt-3 text-[15px] leading-relaxed text-[#23090C]/80">{feature.text}</p>
              <ul className="mt-5 space-y-2.5 border-t border-[#23090C]/12 pt-4">
                {feature.points.map((point) => (
                  <li key={point} className="flex gap-2.5 text-sm leading-relaxed text-[#23090C]/85">
                    <IconCheck className="mt-0.5 h-4 w-4 flex-none text-[#7A0A1B]" />
                    <span>{point}</span>
                  </li>
                ))}
              </ul>
              {feature.note && <p className="mt-4 text-xs text-[#23090C]/60">{feature.note}</p>}
            </div>
          </article>
        ))}
      </div>
    </section>
  )
}
