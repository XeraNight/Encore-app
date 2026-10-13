import Link from 'next/link'
import Image from 'next/image'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Zmazanie účtu & Žiadosť o výmaz dát (GDPR) | Encore',
  description: 'Postup zmazania účtu a žiadosť o úplný výmaz osobných údajov z aplikácie Encore v súlade s Apple Guideline 5.1.1(v) a GDPR.',
}

export default function DeleteAccountPage() {
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
            <Link href="/privacy" className="hover:text-[#D4AF37] transition">
              Súkromie
            </Link>
            <span className="text-zinc-700">•</span>
            <Link href="/support" className="hover:text-[#D4AF37] transition">
              Podpora
            </Link>
          </div>
        </div>

        <article className="space-y-10 text-zinc-300 leading-relaxed text-sm sm:text-base">
          <div>
            <span className="text-xs font-semibold tracking-widest uppercase text-[#E11D48] block mb-2 font-mono">
              Apple Guideline 5.1.1(v) & GDPR Právo na výmaz
            </span>
            <h1 className="text-3xl sm:text-4xl font-serif font-bold text-white tracking-tight">
              Správa a trvalé zmazanie účtu Encore
            </h1>
            <p className="text-xs text-zinc-500 mt-2">
              Vaše právo na okamžité a nezvratné vymazanie všetkých osobných a tréningových údajov.
            </p>
          </div>

          {/* Section 1: In-App Deletion Instructions */}
          <section className="space-y-4">
            <h2 className="text-lg font-semibold text-white">
              Metóda 1: Okamžité zmazanie priamo v aplikácii (Odporúčané)
            </h2>
            <p>
              Ak máte nainštalovanú aplikáciu Encore na svojom iPhone, účet a všetky Vaše dáta zmažete bez čakania za 3 sekundy:
            </p>

            <div className="bg-[#121118] border border-[#D4AF37]/25 rounded-2xl p-6 space-y-4">
              <ol className="list-decimal pl-5 space-y-3 text-zinc-300">
                <li>
                  Otvorte aplikáciu <strong>Encore</strong> na Vašom iPhone.
                </li>
                <li>
                  V pravom hornom rohu kliknite na ikonu svojho <strong>Profilu</strong>.
                </li>
                <li>
                  Prejdite nadol do sekcie <strong>Údržba a Dáta</strong>.
                </li>
                <li>
                  Ťuknite na červené tlačidlo <span className="text-[#E11D48] font-bold">„Zmazať účet a osobné dáta“</span>.
                </li>
                <li>
                  Potvrďte deštruktívny bezpečnostný dialóg.
                </li>
              </ol>

              <div className="pt-2 border-t border-zinc-800 text-xs text-zinc-400">
                ⚡ <strong>Výsledok:</strong> Vaša relácia sa okamžite ukončí, vymažú sa prihlasovacie tokeny z Keychainu a v Supabase databáze sa spustí kaskádové mazanie, ktoré okamžite odstráni Vaše choreografie, poznámky a profil.
              </div>
            </div>
          </section>

          {/* Section 2: What is deleted */}
          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">Aké údaje sa pri zmazaní účtu odstránia?</h2>
            <ul className="list-disc pl-5 space-y-2 text-zinc-300">
              <li>Prihlasovacie konto v Supabase Auth (e-mail, bcrypt heslo, Apple / Google prepojenie).</li>
              <li>Profil tanečníka (meno, prezývka, klub, avatar).</li>
              <li>Všetky choreografie a uzly z 2D parketu (routines, canvas nodes).</li>
              <li>Tréningové poznámky a hlasové nahrávky.</li>
              <li>Priradené licenčné preukazy Apple Wallet.</li>
            </ul>
            <p className="text-xs text-zinc-500">
              * Upozornenie: Ak máte aktívne predplatné Encore Plus alebo Studio cez Apple StoreKit, zmazanie účtu v aplikácii automaticky neruší predplatné v Apple ID (to vyžaduje Apple pravidlá). Predplatné zrušíte v <em>Nastavenia → Apple ID → Predplatné</em>.
            </p>
          </section>

          {/* Section 3: Web-based Deletion Request */}
          <section className="space-y-4">
            <h2 className="text-lg font-semibold text-white">
              Metóda 2: Nemáte prístup k zariadeniu? Žiadosť o výmaz cez web
            </h2>
            <p>
              Ak ste stratili iPhone, odinštalovali aplikáciu alebo nemôžete vykonať zmazanie v aplikácii, môžete podať priamu žiadosť o manuálne zmazanie:
            </p>

            <div className="bg-[#121118] border border-zinc-800 rounded-2xl p-6 space-y-4">
              <p className="text-sm text-zinc-300">
                Zašlite e-mail z adresy, na ktorú bol Váš účet Encore zaregistrovaný, na:
              </p>
              <div className="p-4 rounded-xl bg-black/40 border border-[#D4AF37]/30 text-center">
                <a
                  href="mailto:encore.support.sk@gmail.com?subject=Ziadost%20o%20zmazanie%20uctu%20Encore"
                  className="text-base sm:text-lg font-mono font-bold text-[#FFE088] hover:underline"
                >
                  encore.support.sk@gmail.com
                </a>
                <p className="text-xs text-zinc-500 mt-1">
                  Predmet: Žiadosť o zmazanie účtu Encore
                </p>
              </div>
              <p className="text-xs text-zinc-400">
                Vaša žiadosť bude overená a spracovaná do 48 hodín v súlade s článkom 17 GDPR (Právo na vymazanie / právo na zabudnutie). O úspešnom výmaze budete informovaní potvrdzujúcim e-mailom.
              </p>
            </div>
          </section>

          {/* Section 4: Return links */}
          <div className="pt-6 border-t border-zinc-900 flex flex-wrap gap-4">
            <Link
              href="/"
              className="text-xs font-semibold text-[#D4AF37] hover:underline"
            >
              ← Späť na hlavnú stránku
            </Link>
            <span className="text-zinc-700">•</span>
            <Link
              href="/privacy"
              className="text-xs font-semibold text-zinc-400 hover:text-white"
            >
              Zásady ochrany osobných údajov
            </Link>
            <span className="text-zinc-700">•</span>
            <Link
              href="/support"
              className="text-xs font-semibold text-zinc-400 hover:text-white"
            >
              Zákaznícka podpora
            </Link>
          </div>
        </article>

        <footer className="mt-16 pt-8 border-t border-zinc-900 text-center text-xs text-zinc-600">
          © {new Date().getFullYear()} Encore Studio. Všetky práva vyhradené.
        </footer>
      </div>
    </main>
  )
}
