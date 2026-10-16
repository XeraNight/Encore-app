import Image from 'next/image'
import Link from 'next/link'
import { OPERATOR, SUPPORT_EMAIL } from '@/lib/site'

const LINKS = [
  { href: '/support', label: 'Podpora' },
  { href: '/privacy', label: 'Ochrana súkromia' },
  { href: '/terms', label: 'Podmienky používania' },
  { href: '/delete-account', label: 'Zmazanie účtu' },
]

export default function LandingFooter() {
  return (
    <footer className="border-t border-white/10">
      <div className="mx-auto flex max-w-6xl flex-col gap-10 px-4 py-14 sm:px-6 md:flex-row md:justify-between">
        <div className="max-w-sm">
          <div className="flex items-center gap-2.5">
            <Image src="/logo_mark.svg" alt="" width={26} height={26} />
            <span className="font-rounded text-sm font-black tracking-[0.2em] text-white">ENCORE</span>
          </div>
          <p className="mt-4 text-sm leading-relaxed text-white/60">
            Tréningový denník pre tanečníkov a páry štandardných a latinskoamerických tancov.
          </p>
          <a href={`mailto:${SUPPORT_EMAIL}`} className="mt-4 inline-block text-sm text-white/80 underline-offset-4 hover:underline">
            {SUPPORT_EMAIL}
          </a>
        </div>
        <nav aria-label="Právne a podpora">
          <ul className="grid grid-cols-2 gap-x-10 gap-y-3 text-sm text-white/70">
            {LINKS.map((link) => (
              <li key={link.href}>
                <Link href={link.href} className="hover:text-white">
                  {link.label}
                </Link>
              </li>
            ))}
          </ul>
        </nav>
      </div>
      <div className="mx-auto max-w-6xl border-t border-white/10 px-4 py-8 text-xs leading-relaxed text-white/50 sm:px-6">
        <p>
          Encore nie je oficiálna aplikácia Slovenského zväzu tanečného športu. Výsledky si používatelia ukladajú z
          verejného systému KSIS; jediným oficiálnym zdrojom výsledkov a bodov je SZTŠ.
        </p>
        <p className="mt-3">
          © 2026 Encore · Prevádzkovateľ: {OPERATOR} · Apple, iPhone a App Store sú ochranné známky spoločnosti Apple Inc.
        </p>
      </div>
    </footer>
  )
}
