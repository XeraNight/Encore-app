import Link from 'next/link'
import Image from 'next/image'
import type { Metadata } from 'next'
import { ContactForm } from '@/components/ContactForm'

export const metadata: Metadata = {
  title: 'Zákaznícka podpora & Pomoc | Encore',
  description: 'Technická podpora, pomoc a často kladené otázky pre aplikáciu Encore Dance Studio.',
}

export default function SupportPage() {
  return (
    <main className="min-h-screen bg-[#050505] text-[#F5F5F5] px-6 py-16 sm:py-24 font-sans selection:bg-[#D4AF37]/30">
      {/* Ambient theatrical stage lighting */}
      <div className="fixed top-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] bg-[radial-gradient(ellipse_75%_50%_at_50%_0%,rgba(212,175,55,0.08),transparent_70%)] pointer-events-none" />

      <div className="max-w-3xl mx-auto relative z-10">
        {/* Header navigation */}
        <div className="flex items-center justify-between mb-12 border-b border-[#D4AF37]/15 pb-6">
          <Link
            href="/"
            className="flex items-center gap-3 text-gold-400 font-serif tracking-wider hover:opacity-80 transition"
          >
            <div className="relative w-8 h-8">
              <Image
                src="/logo_mark.svg"
                alt="Encore Ribbon Logo"
                fill
                className="object-contain"
              />
            </div>
            <span className="text-xl font-bold bg-gradient-to-r from-[#F5D77F] via-[#D4AF37] to-[#AA7C11] bg-clip-text text-transparent">
              ENCORE
            </span>
          </Link>

          <div className="flex items-center gap-4 text-xs font-semibold uppercase tracking-widest text-zinc-400">
            <Link
              href="/privacy"
              className="hover:text-[#D4AF37] transition"
            >
              Súkromie
            </Link>
            <span className="text-zinc-700">•</span>
            <Link
              href="/terms"
              className="hover:text-[#D4AF37] transition"
            >
              Podmienky
            </Link>
          </div>
        </div>

        <div className="space-y-12 text-zinc-300">
          <div>
            <span className="text-xs font-semibold tracking-widest uppercase text-[#D4AF37] block mb-2 font-mono">
              Centrum pomoci & Riešenie problémov
            </span>
            <h1 className="text-3xl sm:text-4xl font-serif font-bold text-white tracking-tight">
              Podpora aplikácie Encore
            </h1>
            <p className="text-sm text-zinc-400 mt-2">
              Sme tu, aby sme Vám pomohli s akoukoľvek otázkou ohľadom zostáv, synchronizácie, účtu alebo spätnej väzby pre tím vývoja.
            </p>
          </div>

          {/* Quick Contact Card */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="p-5 rounded-2xl bg-[#121118] border border-[#D4AF37]/20 flex flex-col justify-between">
              <div>
                <span className="text-xs text-zinc-500 uppercase tracking-wider font-mono">Priamy e-mail</span>
                <h3 className="text-base font-bold text-white mt-1">E-mailová podpora</h3>
                <p className="text-xs text-zinc-400 mt-1">Odpovedáme spravidla do 24 až 48 hodín.</p>
              </div>
              <a
                href="mailto:support@encore-sk.com"
                className="text-xs font-bold text-[#FFE088] hover:underline mt-4 inline-block"
              >
                support@encore-sk.com →
              </a>
            </div>

            <div className="p-5 rounded-2xl bg-[#121118] border border-[#D4AF37]/20 flex flex-col justify-between">
              <div>
                <span className="text-xs text-zinc-500 uppercase tracking-wider font-mono">Správa účtu</span>
                <h3 className="text-base font-bold text-white mt-1">Zmazanie účtu & GDPR</h3>
                <p className="text-xs text-zinc-400 mt-1">Postup zmazania účtu alebo odoslanie žiadosti o výmaz dát.</p>
              </div>
              <Link
                href="/delete-account"
                className="text-xs font-bold text-[#E11D48] hover:underline mt-4 inline-block"
              >
                Otvoriť správu zmazania účtu →
              </Link>
            </div>
          </div>

          {/* Contact Form */}
          <div className="bg-gradient-to-br from-[#16151E] to-[#0D0C13] border border-[#D4AF37]/25 rounded-2xl p-6 sm:p-8 shadow-2xl relative overflow-hidden">
            <div className="absolute top-0 right-0 w-32 h-32 bg-[#D4AF37]/10 rounded-full blur-2xl pointer-events-none" />
            <h2 className="text-xl font-serif font-semibold text-white mb-1">
              Napíšte nám správu
            </h2>
            <p className="text-sm text-zinc-400 mb-6">
              Máte nápad na funkciu, našli ste chybu alebo potrebujete pomôcť s účtom?
            </p>

            <ContactForm />
          </div>

          {/* FAQ */}
          <section className="space-y-6">
            <h2 className="text-xl font-serif font-bold text-white">
              Často kladené otázky (FAQ)
            </h2>

            <div className="space-y-4">
              <div className="bg-[#100F16] border border-zinc-800 rounded-xl p-5">
                <h3 className="text-white font-medium mb-1">
                  Ako funguje synchronizácia choreografií?
                </h3>
                <p className="text-sm text-zinc-400">
                  Akonáhle sa prihlásite do rovnakého účtu, Vaše zostavy a figúry na 2D canvase sa v reálnom čase zálohujú v cloude (Supabase EÚ). Po pripojení partnera môžete zostavu zdieľať cez QR kód alebo pozvánkový link.
                </p>
              </div>

              <div className="bg-[#100F16] border border-zinc-800 rounded-xl p-5">
                <h3 className="text-white font-medium mb-1">
                  Funguje Encore aj v tanečnej sále bez internetového pripojenia?
                </h3>
                <p className="text-sm text-zinc-400">
                  Áno! Encore funguje v offline-first režime. Všetky zostavy, metronóm a knižnicu figúr máte k dispozícii aj bez signálu priamo v pamäti iPhonu.
                </p>
              </div>

              <div className="bg-[#100F16] border border-zinc-800 rounded-xl p-5">
                <h3 className="text-white font-medium mb-1">
                  Ako si pridám svoju tanečnú kartu do Apple Wallet (Peňaženky)?
                </h3>
                <p className="text-sm text-zinc-400">
                  V aplikácii Encore v sekcii Profil ťuknite na tlačidlo „Pridať do Apple Wallet“. Vygeneruje sa oficiálny digitálny tanečný preukaz s QR kódom a klubovou príslušnosťou.
                </p>
              </div>

              <div className="bg-[#100F16] border border-zinc-800 rounded-xl p-5">
                <h3 className="text-white font-medium mb-1">
                  Ako môžem zmazať svoj účet alebo zrušiť predplatné?
                </h3>
                <p className="text-sm text-zinc-400">
                  Účet môžete zmazať priamo v aplikácii: <em>Profil → Údržba a Dáta → Zmazať účet a osobné dáta</em> alebo navštívte našu stránku{' '}
                  <Link href="/delete-account" className="text-[#D4AF37] underline">
                    Zmazanie účtu
                  </Link>. Predplatné spravujete vo Vašom Apple ID v systémových nastaveniach iPhonu.
                </p>
              </div>
            </div>
          </section>
        </div>

        <footer className="mt-16 pt-8 border-t border-zinc-900 text-center text-xs text-zinc-600">
          © {new Date().getFullYear()} Encore Studio. Všetky práva vyhradené.
        </footer>
      </div>
    </main>
  )
}
