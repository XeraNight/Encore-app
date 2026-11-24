import Link from 'next/link'
import type { Metadata } from 'next'
import LandingNavbar from '@/components/landing/LandingNavbar'
import LandingFooter from '@/components/landing/LandingFooter'

export const metadata: Metadata = {
  title: 'Zmazanie účtu',
  description: 'Postup zmazania účtu a žiadosť o úplný výmaz osobných údajov z aplikácie Encore v súlade s Apple Guideline 5.1.1(v) a GDPR.',
}

export default function DeleteAccountPage() {
  return (
    <div className="relative min-h-screen overflow-x-clip bg-[#140206] text-[#F5F5F5]">
      <div
        aria-hidden="true"
        className="pointer-events-none fixed inset-0 bg-[radial-gradient(75%_55%_at_50%_18%,rgba(154,13,31,0.42),rgba(120,5,20,0.2)_52%,transparent_80%),radial-gradient(50%_40%_at_82%_14%,rgba(212,175,55,0.08),transparent_70%)]"
      />

      <LandingNavbar />

      <main className="relative mx-auto max-w-3xl px-5 pb-24 pt-28 sm:px-6 sm:pt-36">
        <article className="space-y-10 text-sm leading-relaxed text-white/80 sm:text-base">
          <div>
            <p className="font-rounded text-xs font-black uppercase tracking-[0.16em] text-[#FFE088]">
              APPLE GUIDELINE 5.1.1(V) & GDPR PRÁVO NA VÝMAZ
            </p>
            <h1 className="font-rounded mt-3 text-3xl font-black tracking-tight text-white sm:text-4xl">
              Správa a trvalé zmazanie účtu Encore
            </h1>
            <p className="mt-3 text-sm text-white/65">
              Tvoje právo na okamžité a nezvratné vymazanie všetkých osobných a tréningových údajov.
            </p>
          </div>

          <section className="space-y-4">
            <h2 className="font-rounded text-xl font-bold text-white">
              1. Okamžité zmazanie priamo v aplikácii (Odporúčané)
            </h2>
            <p>
              Ak máš aplikáciu Encore nainštalovanú na svojom iPhone, účet aj všetky dáta zmažeš okamžite:
            </p>

            <div className="space-y-4 rounded-[20px] border border-[#FFE088]/25 bg-white/[0.07] p-6 backdrop-blur-md">
              <ol className="list-decimal space-y-3 pl-5 text-white/85">
                <li>Otvor aplikáciu <strong>Encore</strong> na svojom iPhone.</li>
                <li>V spodnej lište ťukni na záložku <strong>Profil</strong>.</li>
                <li>Otvor <strong>Nastavenia</strong>.</li>
                <li>Prejdi nadol a ťukni na červené tlačidlo <strong className="text-red-300">„Zmazať účet a osobné dáta“</strong>.</li>
                <li>Potvrď bezpečnostný dialóg.</li>
              </ol>

              <p className="border-t border-white/10 pt-3 text-xs text-white/65">
                Relácia sa okamžite ukončí, prihlasovacie tokeny z Kľúčenky sa odstránia a na serveri Supabase sa trvalo vymažú tvoje zostavy, poznámky, výsledky a profil.
              </p>
            </div>
          </section>

          <section className="space-y-3">
            <h2 className="font-rounded text-xl font-bold text-white">Aké údaje sa pri zmazaní odstránia?</h2>
            <ul className="list-disc space-y-2 pl-5 text-white/80">
              <li>Prihlasovacie konto v Supabase Auth (e-mail, heslo, Apple / Google prepojenie).</li>
              <li>Profil tanečníka (meno, klub, rok narodenia, ID tanečníka).</li>
              <li>Všetky zostavy a figúry z 2D parketu (routines, canvas nodes).</li>
              <li>Zálohy Denníka, Plánu, Top 3 priorít, hlasových poznámok a výsledkov z KSIS.</li>
              <li>Spojenia, pozývacie tokeny a priradené registrácie Apple Peňaženky.</li>
            </ul>
            <p className="text-xs text-white/60">
              * Ak máš aktívne predplatné Encore Plus alebo Premium cez Apple App Store, zmazanie účtu v aplikácii podľa pravidiel Apple automaticky neruší fakturáciu v Apple ID. Predplatné zrušíš v <em>Nastavenia iPhonu → Apple ID → Predplatné</em>.
            </p>
          </section>

          <section className="space-y-4">
            <h2 className="font-rounded text-xl font-bold text-white">
              2. Nemáš prístup k telefónu? Žiadosť cez e-mail
            </h2>
            <p>
              Ak si aplikáciu odinštaloval alebo nemáš prístup k iPhonu, pošli nám žiadosť z e-mailu, na ktorom bol účet zaregistrovaný:
            </p>

            <div className="space-y-4 rounded-[20px] border border-white/10 bg-white/[0.07] p-6 backdrop-blur-md">
              <div className="rounded-2xl border border-[#FFE088]/30 bg-black/30 p-4 text-center">
                <a
                  href="mailto:support@encore-sk.com?subject=Ziadost%20o%20zmazanie%20uctu%20Encore"
                  className="font-mono text-base font-bold text-[#FFE088] hover:underline sm:text-lg"
                >
                  support@encore-sk.com
                </a>
                <p className="mt-1 text-xs text-white/60">Predmet: Žiadosť o zmazanie účtu Encore</p>
              </div>
              <p className="text-xs text-white/70">
                Žiadosť overíme a spracujeme do 48 hodín v súlade s článkom 17 GDPR. O dokončení výmazu ťa budeme informovať potvrdzujúcim e-mailom.
              </p>
            </div>
          </section>

          <div className="flex flex-wrap gap-4 border-t border-white/10 pt-6 text-xs font-semibold">
            <Link href="/" className="text-[#FFE088] hover:underline">
              ← Späť na hlavnú stránku
            </Link>
            <span className="text-white/30">•</span>
            <Link href="/privacy" className="text-white/70 hover:text-white">
              Zásady ochrany osobných údajov
            </Link>
            <span className="text-white/30">•</span>
            <Link href="/support" className="text-white/70 hover:text-white">
              Podpora
            </Link>
          </div>
        </article>
      </main>

      <LandingFooter />
    </div>
  )
}
