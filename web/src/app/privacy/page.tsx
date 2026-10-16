import Link from 'next/link'
import Image from 'next/image'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Zásady ochrany osobných údajov',
  description: 'Zásady ochrany osobných údajov a pravidlá spracúvania dát pre aplikáciu Encore – Dance Routine Studio.',
}

export default function PrivacyPolicyPage() {
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
            <Link href="/terms" className="hover:text-[#D4AF37] transition">
              Podmienky
            </Link>
            <span className="text-zinc-700">•</span>
            <Link href="/delete-account" className="hover:text-[#E11D48] transition">
              Zmazanie účtu
            </Link>
            <span className="text-zinc-700">•</span>
            <Link href="/support" className="hover:text-[#D4AF37] transition">
              Podpora
            </Link>
          </div>
        </div>

        <article className="space-y-10 text-zinc-300 leading-relaxed text-sm sm:text-base">
          <div>
            <span className="text-xs font-semibold tracking-widest uppercase text-[#D4AF37] block mb-2 font-mono">
              Právne informácie & Ochrana súkromia (GDPR)
            </span>
            <h1 className="text-3xl sm:text-4xl font-serif font-bold text-white tracking-tight">
              Zásady ochrany osobných údajov (Privacy Policy)
            </h1>
            <p className="text-xs text-zinc-500 mt-2">
              Účinné od 15. októbra 2026 • Verzia 1.1 (iOS / Web)
            </p>
          </div>

          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">1. Prevádzkovateľ a správca osobných údajov</h2>
            <p>
              Prevádzkovateľom mobilnej aplikácie <strong>Encore</strong> a pridruženej webovej platformy je Jakub Kalina (ďalej len „<strong>prevádzkovateľ</strong>“). Vaše súkromie rešpektujeme a chránime v súlade s Nariadením Európskeho parlamentu a Rady (EÚ) 2016/679 (GDPR) a zákonom č. 18/2018 Z. z. o ochrane osobných údajov.
            </p>
            <p>
              Kontaktný e-mail pre uplatnenie práv dotknutých osôb: <a href="mailto:support@encore-sk.com" className="text-[#D4AF37] underline hover:opacity-80">support@encore-sk.com</a>.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">2. Aké osobné údaje spracúvame</h2>
            <ul className="list-disc pl-5 space-y-2 text-zinc-300">
              <li>
                <strong>Údaje účtu:</strong> Meno / tanečná prezývka a e-mailová adresa (získané priamou registráciou alebo prostredníctvom Apple Sign-In či Google Sign-In) slúžiace výlučne na autentifikáciu a synchronizáciu.
              </li>
              <li>
                <strong>Tanečné zostavy a choreografie:</strong> Názvy tancov, figúr, uzlové pozície na 2D canvase, počítanie taktov, prechody a technické poznámky ukladané za účelom tréningového plánovania.
              </li>
              <li>
                <strong>Tréningové videá a analýza držania tela:</strong> Záznamy tanca slúžia na orientačnú biomechanickú analýzu tanečného rámu. Aplikácia <em>nevykonáva</em> biometrickú identifikáciu osoby (rozpoznávanie tváre ani odtlačkov). Videá sú uložené primárne na zariadení používateľa.
              </li>
              <li>
                <strong>Mikrofón a hlasový prepis:</strong> Hlasové nahrávky slúžia na okamžitý lokálny prepis pokynov trénera cez systémový Apple Speech Recognition do textu poznámky figúry.
              </li>
              <li>
                <strong>Verejné súťažné výsledky (SZTŠ / ksis.eu):</strong> Zobrazenie bodov a finálových umiestnení z verejného systému ksis.eu na základe oprávneného záujmu (čl. 6 ods. 1 písm. f) GDPR) pre osobný prehľad tanečníka.
              </li>
            </ul>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">3. Úložisko dát a bezpečnostné záruky</h2>
            <p>
              Vaše dáta sú bezpečne ukladané na cloudovej infraštruktúre platformy <strong>Supabase</strong> so servermi umiestnenými v Európskej únii (Írsko). Komunikácia je šifrovaná pomocou protokolu TLS/HTTPS. Prístup k databáze je chránený striktnými politikami Row Level Security (RLS), takže k Vašim privátnym choreografiám má prístup výlučne overený vlastník.
            </p>
            <p>
              Na iPhone sú dáta izolované systémovým mechanizmom Apple Sandbox. Heslo neukladáme; prihlásenie drží zabezpečená relácia v systémovej Kľúčenke (Keychain), voliteľne odomykaná cez Face ID.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">4. Zdieľanie s tretími stranami a sledovanie (Tracking)</h2>
            <p>
              Aplikácia Encore <strong>nepredáva, neprenajíma ani neposkytuje</strong> žiadne osobné údaje reklamným brokerom, dátovým sprostredkovateľom ani tretím stranám.
            </p>
            <p>
              Aplikácia neobsahuje žiadne reklamné SDK (AdMob, Facebook Pixel) a nepoužíva reklamný identifikátor IDFA na sledovanie naprieč inými aplikáciami.
            </p>
            <p>Na prevádzku služby využívame týchto spracovateľov. Každý dostane len údaje, ktoré na svoju úlohu potrebuje:</p>
            <ul className="list-disc pl-5 space-y-2">
              <li><strong>Supabase</strong> (Írsko, EÚ): účty, databáza, súbory a prihlasovanie.</li>
              <li><strong>Cloudflare</strong> (dátové centrá v Európe): doména a preposielanie e-mailov na adresu podpory.</li>
              <li><strong>Resend</strong> (Írsko, EÚ): odosielanie e-mailov s overovacím kódom a obnovou hesla.</li>
              <li><strong>Apple</strong> a <strong>Google</strong>: prihlásenie cez Apple alebo Google, ak ho zvolíte; platby predplatného spracúva výhradne Apple (App Store).</li>
              <li><strong>Vercel</strong>: prevádzka tejto webovej stránky a anonymná štatistika návštevnosti bez cookies.</li>
              <li><strong>PostHog</strong> (EÚ): súhrnná analytika používania webovej stránky bez cookies a bez profilovania návštevníkov.</li>
              <li><strong>Formspree</strong>: doručenie správy z kontaktného formulára na stránke Podpora.</li>
            </ul>
            <p>
              Výsledky zo súťaží: keď v aplikácii otvoríte stránku systému KSIS, aplikácia z nej prečíta a uloží len údaje Vášho prepojeného páru (triedu, body, finále, umiestnenia a krížiky porotcov). Mená ostatných párov sa neukladajú. Jediným oficiálnym zdrojom výsledkov je Slovenský zväz tanečného športu.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">5. Právo na zmazanie účtu a zabudnutie (GDPR & Apple 5.1.1(v))</h2>
            <p>
              V súlade s nariadením GDPR a smernicou Apple App Store Review Guideline 5.1.1(v) máte plné právo kedykoľvek požiadať o trvalé zmazanie svojho účtu a všetkých asociovaných dát:
            </p>
            <div className="bg-[#121118] border border-[#D4AF37]/20 rounded-xl p-5 my-3 space-y-2">
              <h3 className="text-white font-medium">Ako zmazať účet priamo v aplikácii:</h3>
              <p className="text-zinc-400 text-sm">
                V Encore otvorte <strong>Profil</strong> → prejdite do sekcie <strong>Údržba a Dáta</strong> → zvoľte <strong>Zmazať účet a osobné dáta</strong>. Týmto krokom sa okamžite a trvalo vymažú Vaše prihlasovacie údaje, choreografie a profil z databázy.
              </p>
              <div className="pt-2">
                <Link
                  href="/delete-account"
                  className="text-xs font-semibold text-[#D4AF37] hover:underline"
                >
                  Zobraziť podrobný návod na zmazanie účtu alebo poslať webovú žiadosť →
                </Link>
              </div>
            </div>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">6. Kontakt pre otázky ochrany osobných údajov</h2>
            <p>
              V prípade akýchkoľvek otázok ohľadom Vašich údajov nás kontaktujte na:{' '}
              <a href="mailto:support@encore-sk.com" className="text-[#D4AF37] underline hover:opacity-80">
                support@encore-sk.com
              </a>{' '}
              alebo navštívte našu stránku{' '}
              <Link href="/support" className="text-[#D4AF37] underline hover:opacity-80">
                zákazníckej podpory
              </Link>.
            </p>
          </section>
        </article>

        <footer className="mt-16 pt-8 border-t border-zinc-900 text-center text-xs text-zinc-600">
          © {new Date().getFullYear()} Encore Studio. Všetky práva vyhradené.
        </footer>
      </div>
    </main>
  )
}
