'use client'

import { useRef, useState, type MouseEvent } from 'react'
import Image from 'next/image'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import AppStoreButton from './AppStoreButton'

const LINKS = [
  { href: '/#funkcie', label: 'Funkcie' },
  { href: '/#pre-koho', label: 'Pre koho' },
  { href: '/#cennik', label: 'Cenník' },
  { href: '/#otazky', label: 'Otázky' },
  { href: '/support', label: 'Podpora' },
]

/**
 * Always a frosted bar so nothing underneath ever collides with links.
 * Mobile uses the native top-layer Popover API (with a clean manual fallback for older browsers).
 */
export default function LandingNavbar() {
  const pathname = usePathname()
  const popoverRef = useRef<HTMLDivElement>(null)
  const [fallbackOpen, setFallbackOpen] = useState(false)

  const toggleMenu = () => {
    if (typeof HTMLElement !== 'undefined' && Object.hasOwn(HTMLElement.prototype, 'popover')) return
    setFallbackOpen((prev) => !prev)
  }

  const closeMenu = () => {
    setFallbackOpen(false)
    const el = popoverRef.current as (HTMLDivElement & { hidePopover?: () => void }) | null
    if (el && typeof el.hidePopover === 'function') {
      try {
        el.hidePopover()
      } catch {
        // Already closed
      }
    }
  }

  const handleLogoClick = (event: MouseEvent<HTMLAnchorElement>) => {
    closeMenu()
    if (pathname === '/') {
      event.preventDefault()
      if (window.location.hash) {
        window.history.replaceState(null, '', '/')
      }
      window.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }

  return (
    <header className="fixed inset-x-0 top-0 z-50 border-b border-white/10 bg-[#120206b8] backdrop-blur-xl backdrop-saturate-150">
      <nav className="mx-auto flex h-16 max-w-6xl items-center justify-between gap-3 px-4 sm:px-6" aria-label="Hlavná navigácia">
        <Link
          href="/"
          onClick={handleLogoClick}
          className="group flex h-12 items-center gap-2.5 rounded-xl pr-1.5 transition"
          aria-label="Encore – späť na začiatok úvodnej stránky"
        >
          <Image
            src="/encore_mark.png"
            alt=""
            width={404}
            height={644}
            priority
            className="h-9 w-auto flex-none transition duration-200 group-hover:scale-[1.06] group-hover:drop-shadow-[0_0_12px_rgba(255,224,136,0.45)] sm:h-10"
          />
          <span className="font-rounded text-[18px] font-black tracking-[0.22em] text-[#FFF8E7] transition group-hover:text-[#FFE088] sm:text-[19px]">
            ENCORE
          </span>
        </Link>

        <ul className="hidden items-center gap-7 text-sm text-white/75 md:flex">
          {LINKS.map((link) => (
            <li key={link.href}>
              <Link href={link.href} className="transition hover:text-[#FFE088]">
                {link.label}
              </Link>
            </li>
          ))}
        </ul>

        <div className="flex items-center gap-2">
          <AppStoreButton size="small" />
          <button
            type="button"
            popoverTarget="mobile-nav-menu"
            popoverTargetAction="toggle"
            onClick={toggleMenu}
            aria-label="Otvoriť navigáciu"
            aria-controls="mobile-nav-menu"
            className="inline-flex h-10 w-10 items-center justify-center rounded-xl border border-white/15 bg-white/[0.07] text-white/90 transition hover:border-[#FFE088]/40 hover:text-[#FFE088] active:scale-95 md:hidden"
          >
            <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" aria-hidden="true">
              <path d="M4 7h16M4 12h16M4 17h16" />
            </svg>
          </button>
        </div>
      </nav>

      {/* Native top-layer Popover menu for mobile */}
      <div
        id="mobile-nav-menu"
        ref={popoverRef}
        popover="auto"
        className={`mobile-nav-popover md:hidden ${fallbackOpen ? 'block opacity-100' : ''}`}
      >
        <div className="flex items-center justify-between border-b border-white/10 pb-3">
          <span className="font-rounded text-xs font-black uppercase tracking-[0.18em] text-[#FFE088]">
            NAVIGÁCIA
          </span>
          <button
            type="button"
            popoverTarget="mobile-nav-menu"
            popoverTargetAction="hide"
            onClick={closeMenu}
            aria-label="Zavrieť navigáciu"
            className="inline-flex h-9 w-9 items-center justify-center rounded-lg border border-white/10 bg-white/[0.06] text-white/80 hover:text-white"
          >
            <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" aria-hidden="true">
              <path d="M6 6l12 12M18 6 6 18" />
            </svg>
          </button>
        </div>
        <ul className="mt-2 flex flex-col gap-1">
          {LINKS.map((link) => (
            <li key={link.href}>
              <Link
                href={link.href}
                onClick={closeMenu}
                className="flex min-h-11 items-center justify-between rounded-xl px-3 font-rounded text-base font-bold text-white/90 transition hover:bg-white/[0.08] hover:text-[#FFE088]"
              >
                <span>{link.label}</span>
                <span aria-hidden="true" className="text-white/40">→</span>
              </Link>
            </li>
          ))}
        </ul>
      </div>
    </header>
  )
}
