import type { Metadata } from 'next'
import Link from 'next/link'
import LandingNavbar from '@/components/landing/LandingNavbar'
import HeroStageLighting from '@/components/landing/HeroStageLighting'
import InteractivePhoneMockup from '@/components/landing/InteractivePhoneMockup'
import ProductStoryShowcase from '@/components/landing/ProductStoryShowcase'
import PricingSection from '@/components/landing/PricingSection'
import DownloadCTA from '@/components/landing/DownloadCTA'
import LandingFooter from '@/components/landing/LandingFooter'
import FloatingDownloadBar from '@/components/landing/FloatingDownloadBar'

export const metadata: Metadata = {
  title: 'Encore — Umenie tanca. Dokonalosť tréningu.',
  description: 'Prémiový digitálny asistent pre tanečné páry, trénerov a tanečníkov. 2D choreografický parket, video duel a tréningové poznámky priamo v sále.',
  keywords: [
    'Encore',
    'spoločenské tance',
    'štandardné tance',
    'latinskoamerické tance',
    'tanečný metronóm',
    'choreografia',
    'tanečný tréning',
    'SZTŠ',
    'ksis.eu',
    'ballroom dance',
    'dance studio app',
  ],
  openGraph: {
    title: 'Encore — Dance Routine Studio',
    description: 'Choreografický 2D parket, video analýza, metronóm a súťažné body SZTŠ pre tanečné páry a trénerov.',
    type: 'website',
    url: 'https://www.encore-sk.com',
    images: [
      {
        url: 'https://www.encore-sk.com/encore_stage_bg.jpg',
        width: 1200,
        height: 630,
        alt: 'Encore Dance Routine Studio',
      },
    ],
  },
}

export default function HomePage() {
  return (
    <div className="min-h-screen bg-[#140206] text-[#F5F5F5] selection:bg-[#D4AF37]/30 selection:text-white font-sans relative overflow-x-hidden">
      
      {/* ── Theatrical Red Velvet Stage & Golden Spotlight ── */}
      <HeroStageLighting />

      {/* ── Navigation ─────────────────────────────────────────────────── */}
      <LandingNavbar />

      <main>
        {/* ── HERO SECTION ────────────────────────────────────────────── */}
        <section className="pt-32 pb-16 md:pt-40 md:pb-24 relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex flex-col items-center text-center">
          
          {/* Section Brand Tag (Brand Guidelines §1A HomeSectionHeader standard) */}
          <div className="flex items-center gap-2 mb-6">
            <span className="text-xs font-sans font-black tracking-[0.2em] uppercase text-[#FFE088]">
              APLIKÁCIA PRE SÚŤAŽNÝ TANEČNÝ ŠPORT
            </span>
          </div>

          {/* Main Display Headline */}
          <h1 className="text-4xl sm:text-6xl md:text-7xl lg:text-8xl font-serif font-black tracking-tight max-w-5xl leading-[1.08] mb-6">
            Umenie tanca.{' '}
            <span className="bg-gradient-to-r from-[#FFF2CC] via-[#FFE088] to-[#D4AF37] bg-clip-text text-transparent block sm:inline">
              Dokonalosť tréningu.
            </span>
          </h1>

          {/* Concise, Professional Subtitle */}
          <p className="text-base sm:text-lg md:text-xl text-zinc-300 max-w-2xl leading-relaxed mb-10">
            2D choreografický parket, porovnanie videí a tréningové poznámky priamo v sále. Navrhnuté pre tanečné páry, trénerov a kluby.
          </p>

          {/* Hero Store Action Buttons */}
          <div className="flex flex-wrap items-center justify-center gap-4 mb-12">
            
            {/* App Store Button (iOS) */}
            <Link
              href="/download/ios"
              className="btn-discord-pill group px-7 py-4 bg-white text-black font-bold text-sm flex items-center gap-3.5 shadow-[0_10px_30px_rgba(255,255,255,0.15)] hover:bg-zinc-100 hover:shadow-[0_15px_35px_rgba(255,255,255,0.25)] active:scale-[0.97] transition-all"
            >
              <svg className="w-7 h-7 fill-current group-hover:scale-105 transition-transform" viewBox="0 0 24 24">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.61-.75 1.04-1.8 1.01-2.87-.96.04-2.09.64-2.74 1.4-.57.65-1.06 1.73-.93 2.76 1.07.08 2.06-.54 2.66-1.29z" />
              </svg>
              <div className="text-left">
                <span className="text-[10px] block text-zinc-600 font-medium -mb-1">Stiahnuť pre iPhone & iPad</span>
                <span className="text-base font-black flex items-center gap-1">
                  App Store
                  <span className="text-xs group-hover:translate-x-1 transition-transform inline-block">→</span>
                </span>
              </div>
            </Link>

            {/* Google Play Button (Android) */}
            <Link
              href="/download/android"
              className="btn-discord-pill group px-7 py-4 bg-[#20050B] border border-[#FFE088]/30 text-white font-bold text-sm flex items-center gap-3.5 shadow-2xl hover:border-[#FFE088]/70 hover:shadow-[0_10px_30px_rgba(212,175,55,0.2)] active:scale-[0.97] transition-all backdrop-blur-md"
            >
              <svg className="w-6 h-6 fill-current text-[#FFE088] group-hover:scale-105 transition-transform" viewBox="0 0 24 24">
                <path d="M3.609 1.814L13.793 12 3.61 22.186c-.352-.361-.568-.89-.568-1.503V3.317c0-.613.216-1.142.567-1.503zm11.24 11.24l2.127 2.127-11.458 6.55 9.331-8.677zm0-2.108L5.518 2.27l11.459 6.549-2.128 2.127zm1.488 1.054l3.189 1.822c.947.541.947 1.427 0 1.968l-3.189 1.822-2.316-2.316 2.316-2.296z" />
              </svg>
              <div className="text-left">
                <span className="text-[10px] block text-zinc-400 font-medium -mb-1">Objaviť pre Android tablety & mobily</span>
                <span className="text-base font-black flex items-center gap-1">
                  Google Play
                  <span className="text-xs text-[#FFE088] group-hover:translate-x-1 transition-transform inline-block">→</span>
                </span>
              </div>
            </Link>

          </div>

          {/* Social Proof Strip */}
          <div className="flex flex-wrap items-center justify-center gap-6 sm:gap-10 text-xs text-zinc-400 border-t border-white/10 pt-8 mb-14">
            <div className="flex items-center gap-2">
              <span className="text-[#FFE088] font-bold">★★★★★</span>
              <span>Navrhnuté s trénermi SZTŠ</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-[#FFE088]">●</span>
              <span>100% Offline-First v sále</span>
            </div>
            <div className="flex items-center gap-2">
              <svg className="w-3.5 h-3.5 text-[#FFE088]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                <path d="M7 11V7a5 5 0 0 1 10 0v4" />
              </svg>
              <span>Privátne & Bezpečné (EÚ Servery)</span>
            </div>
          </div>

          {/* ── Centerpiece Interactive Phone Showcase ── */}
          <div className="w-full">
            <InteractivePhoneMockup />
          </div>

        </section>

        {/* ── PRODUCT STORY SHOWCASE (Acts I to IV: 2D Canvas, 1-Tap Studio, Video Duel, KSIS) ── */}
        <ProductStoryShowcase />

        {/* ── PRICING SECTION ─────────────────────────────────────────── */}
        <PricingSection />

        {/* ── DOWNLOAD CTA & QR CODE ──────────────────────────────────── */}
        <DownloadCTA />

      </main>

      {/* ── FOOTER & LEGAL ────────────────────────────────────────────── */}
      <FloatingDownloadBar />
      <LandingFooter />

    </div>
  )
}
