import Link from 'next/link'
import Image from 'next/image'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Podmienky používania (Terms of Service & EULA) | Encore',
  description: 'Zmluvné podmienky používania, licenčná zmluva EULA a právne vyhlásenia aplikácie Encore.',
}

export default function TermsPage() {
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
            <span className="text-xs font-semibold tracking-widest uppercase text-[#D4AF37] block mb-2">
              Právne informácie & Licenčná zmluva
            </span>
            <h1 className="text-3xl sm:text-4xl font-serif font-bold text-white tracking-tight">
              Podmienky používania & Licenčná zmluva (EULA)
            </h1>
            <p className="text-xs text-zinc-500 mt-2">
              Posledná aktualizácia: 1. októbra 2026 • Verzia 1.0 (iOS / Web)
            </p>
          </div>

          {/* Section 1 */}
          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">1. Všeobecné ustanovenia a akceptácia</h2>
            <p>
              Tieto Podmienky používania a Licenčná zmluva s koncovým používateľom (ďalej len „<strong>Podmienky</strong>“ alebo „<strong>EULA</strong>“) upravujú prístup a používanie mobilnej aplikácie <strong>Encore</strong> a pridruženej webovej platformy. Stiahnutím, inštaláciou alebo používaním aplikácie vyjadrujete svoj neodvolateľný súhlas s týmito Podmienkami.
            </p>
            <p>
              Aplikácia podlieha štandardným licenčným podmienkam spoločnosti Apple Inc. (Standard Apple EULA) v spojení s týmito doplňujúcimi pravidlami prevádzkovateľa.
            </p>
          </section>

          {/* Section 2: Subscriptions & In-App Purchases */}
          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">2. Predplatné a In-App platby (Apple StoreKit)</h2>
            <p>
              Encore ponúka bezplatnú verziu (Free) a voliteľné prémiové balíky s automatickým obnovovaním (<strong>Encore Plus</strong> a <strong>Encore Studio</strong>):
            </p>
            <ul className="list-disc pl-5 space-y-2 text-zinc-300">
              <li>
                <strong>Fakturácia:</strong> Platba sa zúčtuje na Váš účet Apple ID pri potvrdení nákupu.
              </li>
              <li>
                <strong>Automatické obnovovanie:</strong> Predplatné sa automaticky obnovuje za rovnakú cenu a na rovnaké obdobie, pokiaľ ho nezrušíte najmenej 24 hodín pred uplynutím aktuálneho predplatného obdobia.
              </li>
              <li>
                <strong>Správa a zrušenie:</strong> Používateľ môže predplatné kedykoľvek spravovať alebo zrušiť v systémových nastaveniach iPhonu (<em>Nastavenia → Vaše Apple ID → Predplatné</em>).
              </li>
              <li>
                <strong>Vrátenie peňazí:</strong> Všetky platby a prípadné žiadosti o refundáciu podliehajú pravidlám spoločnosti Apple a vybavujú sa priamo cez portál <code>reportaproblem.apple.com</code>.
              </li>
            </ul>
          </section>

          {/* Section 3: Community & UGC */}
          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">3. Pravidlá komunity a nulová tolerancia nevhodného obsahu (UGC)</h2>
            <p>
              V súlade so smernicou Apple App Store Review Guideline 1.2 uplatňuje Encore politiku <strong>striktnej nulovej tolerancie</strong> voči akémukoľvek nevhodnému, hanlivému, urážlivému, erotickému alebo protiprávnemu obsahu.
            </p>
            <ul className="list-disc pl-5 space-y-2 text-zinc-300">
              <li>
                Zdieľanie choreografií, video nahrávok a správ medzi tanečníkmi je vyhradené výlučne na športové a vzdelávacie účely.
              </li>
              <li>
                Každý používateľ má právo zablokovať nevhodného používateľa alebo nahlásiť závadný obsah priamo v aplikácii alebo prostredníctvom e-mailu podpory.
              </li>
              <li>
                Nahlásené podnety prevádzkovateľ prešetrí do 24 hodín a účty porušujúce pravidlá budú bezodkladne trvalo zablokované.
              </li>
            </ul>
          </section>

          {/* Section 4: Content Ownership & Copyright */}
          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">4. Duševné vlastníctvo a autorské práva</h2>
            <ul className="list-disc pl-5 space-y-2 text-zinc-300">
              <li>
                <strong>Vaše choreografie a videá:</strong> Používateľ si ponecháva 100% autorské práva a výlučné vlastníctvo k svojim choreografiám, videozáznamom a poznámkam. Prevádzkovateľovi udeľuje iba nevyhnutnú technickú licenciu na zabezpečenie synchronizácie a ukladania.
              </li>
              <li>
                <strong>Názvy tanečných figúr:</strong> Štandardizované tanečné termíny (napr. <em>Natural Spin Turn</em>, <em>Open Hip Twist</em>) vychádzajú z verejných medzinárodných sylabov (WDSF, ISTD) a ich použitie je voľné.
              </li>
              <li>
                <strong>Zvukový obsah:</strong> Metronóm generuje zvuk matematickou PCM syntézou priamo v RAM pamäti zariadenia. Funkcia Speed Trainer prehráva výhradne lokálne zvukové súbory, ktoré si používateľ sám legálne vlastní a vloží do aplikácie.
              </li>
            </ul>
          </section>

          {/* Section 5: Disclaimers */}
          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">5. Zrieknutie sa zodpovednosti (Disclaimers)</h2>
            <div className="bg-[#121118] border border-[#D4AF37]/25 rounded-xl p-5 my-3 space-y-3">
              <p className="text-white font-medium text-xs uppercase tracking-wider text-[#D4AF37]">
                Zdravotné vyhlásenie:
              </p>
              <p className="text-zinc-300 text-sm">
                Aplikácia Encore poskytuje asistenčné tréningové nástroje. Nenahrádza certifikovaného trénera, fyzioterapeuta ani lekára. Športovú aktivitu vykonávate na vlastné riziko. Prevádzkovateľ nenesie zodpovednosť za úrazy či zdravotné komplikácie vzniknuté pri tréningu.
              </p>

              <p className="text-white font-medium text-xs uppercase tracking-wider text-[#D4AF37] pt-2">
                Vyhlásenie k súťažným bodom (SZTŠ / ksis.eu):
              </p>
              <p className="text-zinc-300 text-sm">
                Súťažné dáta a body importované z verejného systému ksis.eu majú informatívny charakter. Jediným oficiálnym a záväzným zdrojom súťažných výsledkov je Slovenský zväz tanečného športu (SZTŠ).
              </p>
            </div>
          </section>

          {/* Section 6: Contact */}
          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">6. Kontaktné údaje a právna podpora</h2>
            <p>
              V prípade akýchkoľvek právnych otázok alebo nahlásenia porušenia podmienok nás kontaktujte na:{' '}
              <a href="mailto:encore.support.sk@gmail.com" className="text-[#D4AF37] underline hover:opacity-80">
                encore.support.sk@gmail.com
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
