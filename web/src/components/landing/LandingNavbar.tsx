import Image from 'next/image'
import Link from 'next/link'
import AppStoreButton from './AppStoreButton'

const LINKS = [
  { href: '#funkcie', label: 'Funkcie' },
  { href: '#pre-koho', label: 'Pre koho' },
  { href: '#cennik', label: 'Cenník' },
  { href: '#otazky', label: 'Otázky' },
]

/** Always a frosted bar, so nothing underneath ever collides with the links. */
export default function LandingNavbar() {
  return (
    <header className="fixed inset-x-0 top-0 z-50 border-b border-white/10 bg-[#12020699] backdrop-blur-xl backdrop-saturate-150">
      <nav className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6" aria-label="Hlavná navigácia">
        <Link href="/" className="flex h-11 items-center gap-2.5" aria-label="Encore, úvod">
          <Image src="/logo_mark.svg" alt="" width={28} height={28} priority />
          <span className="font-rounded text-[15px] font-black tracking-[0.2em] text-white">ENCORE</span>
        </Link>
        <ul className="hidden items-center gap-8 text-sm text-white/70 md:flex">
          {LINKS.map((link) => (
            <li key={link.href}>
              <a href={link.href} className="transition hover:text-white">
                {link.label}
              </a>
            </li>
          ))}
        </ul>
        <AppStoreButton size="small" />
      </nav>
    </header>
  )
}
