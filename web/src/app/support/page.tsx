import Link from 'next/link'
import type { Metadata } from 'next'
import LandingNavbar from '@/components/landing/LandingNavbar'
import LandingFooter from '@/components/landing/LandingFooter'
import { ContactForm } from '@/components/ContactForm'

export const metadata: Metadata = {
  title: 'Podpora',
  description: 'Technická podpora, pomoc a odpovede na časté otázky k aplikácii Encore.',
}

const SUPPORT_FAQ = [
  {
    q: 'Ako funguje zálohovanie a zdieľanie zostáv?',
    a: 'Keď si prihlásený do svojho účtu, tvoje vlastné zostavy, poznámky a knižnica figúr sa bezpečne zálohujú v cloude (Supabase EÚ) a máš ich aj na novom iPhone. Partnerovi pošleš kópiu zostavy cez QR kód za sekundu.',
  },
  {
    q: 'Funguje Encore aj v tanečnej sále bez signálu?',
    a: 'Áno. Encore funguje v offline-first režime. Všetky zostavy, poznámky, plán aj metronóm máš priamo v iPhone a fungujú bez internetu.',
  },
  {
    q: 'Ako si pridám svoju tanečnú kartu do Apple Peňaženky?',
    a: 'V aplikácii otvor Profil → Členská karta a ťukni na „Pridať do Apple Peňaženky“. Karta slúži na rýchle spojenie s tanečníkmi v Encore cez QR kód a nie je oficiálnym preukazom SZTŠ.',
  },
  {
    q: 'Ako zmažem účet alebo zruším predplatné?',
    a: 'Účet zmažeš priamo v aplikácii v Profil → Nastavenia → Zmazať účet a osobné dáta (alebo podľa postupu na stránke Zmazanie účtu). Predplatné zrušíš v Nastaveniach iPhonu → Apple ID → Predplatné.',
  },
]

export default function SupportPage() {
  return (
    <div className="relative min-h-screen overflow-x-clip bg-[#140206] text-[#F5F5F5]">
      <div
        aria-hidden="true"
        className="pointer-events-none fixed inset-0 bg-[radial-gradient(75%_55%_at_50%_18%,rgba(154,13,31,0.42),rgba(120,5,20,0.2)_52%,transparent_80%),radial-gradient(50%_40%_at_82%_14%,rgba(212,175,55,0.08),transparent_70%)]"
      />

      <LandingNavbar />

      <main className="relative mx-auto max-w-3xl px-5 pb-24 pt-28 sm:px-6 sm:pt-36">
        <div className="space-y-12">
          <div>
            <p className="font-rounded text-xs font-black uppercase tracking-[0.16em] text-[#FFE088]">
              PODPORA A POMOC
            </p>
            <h1 className="font-rounded mt-3 text-3xl font-black tracking-tight text-white sm:text-5xl">
              Podpora aplikácie Encore
            </h1>
            <p className="mt-4 text-base leading-relaxed text-white/75">
              Máš otázku k zostavám, zálohovaniu, KSIS výsledkom alebo nápad na vylepšenie? Napíš nám priamo sem.
            </p>
          </div>

          {/* Quick Contact Cards (§1A glass) */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div className="flex flex-col justify-between rounded-[20px] border border-white/10 bg-white/[0.07] p-6 backdrop-blur-md">
              <div>
                <p className="font-rounded text-[11px] font-black uppercase tracking-[0.14em] text-[#FFE088]">
                  PRIAMY E-MAIL
                </p>
                <h2 className="font-rounded mt-2 text-lg font-bold text-white">E-mailová podpora</h2>
                <p className="mt-1 text-sm text-white/70">Odpovedáme spravidla do 24 až 48 hodín.</p>
              </div>
              <a
                href="mailto:support@encore-sk.com"
                className="mt-5 inline-flex items-center font-rounded text-sm font-bold text-[#FFE088] hover:underline"
              >
                support@encore-sk.com →
              </a>
            </div>

            <div className="flex flex-col justify-between rounded-[20px] border border-white/10 bg-white/[0.07] p-6 backdrop-blur-md">
              <div>
                <p className="font-rounded text-[11px] font-black uppercase tracking-[0.14em] text-[#FFE088]">
                  SPRÁVA ÚČTU & GDPR
                </p>
                <h2 className="font-rounded mt-2 text-lg font-bold text-white">Zmazanie účtu</h2>
                <p className="mt-1 text-sm text-white/70">Postup okamžitého výmazu v apke alebo webovej žiadosti.</p>
              </div>
              <Link
                href="/delete-account"
                className="mt-5 inline-flex items-center font-rounded text-sm font-bold text-[#FFE088] hover:underline"
              >
                Otvoriť návod na zmazanie účtu →
              </Link>
            </div>
          </div>

          {/* Contact Form Card (§1A glass) */}
          <section
            aria-labelledby="kontakt-nadpis"
            className="rounded-[20px] border border-[#FFE088]/25 bg-white/[0.07] p-6 backdrop-blur-md sm:p-8"
          >
            <p className="font-rounded text-xs font-black uppercase tracking-[0.16em] text-[#FFE088]">
              KONTAKTNÝ FORMULÁR
            </p>
            <h2 id="kontakt-nadpis" className="font-rounded mt-2 text-2xl font-black text-white">
              Napíš nám správu
            </h2>
            <p className="mt-1 mb-6 text-sm text-white/75">
              Ak hlásiš chybu, pomôže nám model iPhonu a krátky popis toho, čo si práve robil.
            </p>
            <ContactForm />
          </section>

          {/* Support FAQ (native smooth CSS accordion) */}
          <section aria-labelledby="support-faq-nadpis" className="space-y-4">
            <h2 id="support-faq-nadpis" className="font-rounded text-2xl font-black text-white">
              Časté otázky k podpore
            </h2>
            <div className="encore-faq space-y-3">
              {SUPPORT_FAQ.map((item) => (
                <details
                  key={item.q}
                  className="group rounded-[20px] border border-white/10 bg-white/[0.07] px-6 py-4 backdrop-blur-md transition hover:border-white/20"
                >
                  <summary className="flex min-h-11 cursor-pointer list-none items-center justify-between gap-4 font-rounded text-base font-bold text-white [&::-webkit-details-marker]:hidden">
                    <span>{item.q}</span>
                    <span
                      aria-hidden="true"
                      className="flex h-8 w-8 flex-none items-center justify-center rounded-full border border-[#FFE088]/35 bg-[#FFE088]/10 font-rounded text-base font-bold text-[#FFE088] transition-transform duration-200 group-open:rotate-45 motion-reduce:transition-none"
                    >
                      +
                    </span>
                  </summary>
                  <p className="mt-3 border-t border-white/10 pt-3 pr-8 text-sm leading-relaxed text-white/75">
                    {item.a}
                  </p>
                </details>
              ))}
            </div>
          </section>
        </div>
      </main>

      <LandingFooter />
    </div>
  )
}
