'use client'

import type { MouseEvent } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { OPERATOR, SUPPORT_EMAIL } from '@/lib/site'

const PRODUCT_LINKS = [
  { href: '/#funkcie', label: 'Funkcie' },
  { href: '/#pre-koho', label: 'Pre koho' },
  { href: '/#cennik', label: 'Cenník' },
  { href: '/#otazky', label: 'Otázky' },
]

const LEGAL_LINKS = [
  { href: '/support', label: 'Podpora' },
  { href: '/privacy', label: 'Ochrana súkromia' },
  { href: '/terms', label: 'Podmienky používania' },
  { href: '/delete-account', label: 'Zmazanie účtu' },
]

export default function LandingFooter() {
  const pathname = usePathname()

  const handleBackToTop = (event: MouseEvent<HTMLAnchorElement>) => {
    if (pathname === '/') {
      event.preventDefault()
      if (window.location.hash) {
        window.history.replaceState(null, '', '/')
      }
      window.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }

  return (
    <footer className="relative overflow-hidden border-t border-[#FFE088]/15 bg-[#0B0204] text-[#F6E9CE]">
      <div className="mx-auto max-w-6xl px-5 pt-16 sm:px-6 sm:pt-20">
        {/* Top Row: Editorial Tagline + Two Clean Columns */}
        <div className="flex flex-col gap-12 md:flex-row md:items-start md:justify-between">
          <div className="max-w-md">
            <p className="font-rounded text-2xl font-black leading-[1.12] tracking-tight text-[#F6E9CE] sm:text-4xl">
              Zídeš z parketu.
              <br />
              Zápis ostáva.
              <br />
              <span className="text-[#FFE088]">Zvyšok týždňa patrí tancu.</span>
            </p>
            <a
              href={`mailto:${SUPPORT_EMAIL}`}
              className="mt-6 inline-block text-sm font-medium text-[#F6E9CE]/80 underline decoration-[#FFE088]/40 underline-offset-4 transition hover:text-[#FFE088]"
            >
              {SUPPORT_EMAIL}
            </a>
          </div>

          <nav aria-label="Pätičková navigácia" className="grid grid-cols-2 gap-x-12 gap-y-3 text-sm sm:gap-x-16">
            <ul className="space-y-3">
              {PRODUCT_LINKS.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-[#F6E9CE]/80 underline decoration-[#F6E9CE]/25 underline-offset-4 transition hover:text-[#FFE088] hover:decoration-[#FFE088]"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
            <ul className="space-y-3">
              {LEGAL_LINKS.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-[#F6E9CE]/80 underline decoration-[#F6E9CE]/25 underline-offset-4 transition hover:text-[#FFE088] hover:decoration-[#FFE088]"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </nav>
        </div>

        {/* Hairline Divider + Legal Meta + Back to Top */}
        <div className="mt-14 flex flex-col gap-4 border-t border-[#FFE088]/20 pt-6 text-xs leading-relaxed text-[#F6E9CE]/55 sm:flex-row sm:items-end sm:justify-between">
          <div className="max-w-2xl space-y-2">
            <p>
              Encore nie je oficiálna aplikácia Slovenského zväzu tanečného športu. Výsledky si používatelia ukladajú z
              verejného systému KSIS; jediným oficiálnym zdrojom výsledkov a bodov je SZTŠ.
            </p>
            <p>
              © 2026 Encore · Prevádzkovateľ: {OPERATOR} · Apple, iPhone a App Store sú ochranné známky spoločnosti Apple Inc.
            </p>
          </div>
          <Link
            href="/"
            onClick={handleBackToTop}
            className="flex-none font-rounded text-xs font-bold text-[#F6E9CE]/80 underline decoration-[#FFE088]/40 underline-offset-4 transition hover:text-[#FFE088]"
          >
            Späť hore ↑
          </Link>
        </div>
      </div>

      {/* Monumental Cropped Animated Wordmark — clickable back to homepage top */}
      <div className="mt-10 overflow-hidden px-3 sm:mt-14 sm:px-6">
        <Link
          href="/"
          onClick={handleBackToTop}
          aria-label="Encore – späť na vrch úvodnej stránky"
          className="group block select-none focus-visible:outline-none"
        >
          <span className="footer-wordmark-rise block text-center font-rounded text-[clamp(4.4rem,21vw,21.5rem)] font-black leading-[0.78] tracking-[-0.035em] text-[#F6E9CE] translate-y-[22%] transition-colors duration-300 group-hover:text-[#FFE088]">
            ENCORE
          </span>
        </Link>
      </div>
    </footer>
  )
}
