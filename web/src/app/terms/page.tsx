import Link from 'next/link'
import type { Metadata } from 'next'
import LandingNavbar from '@/components/landing/LandingNavbar'
import LandingFooter from '@/components/landing/LandingFooter'

export const metadata: Metadata = {
  title: 'Podmienky používania',
  description: 'Zmluvné podmienky používania, licenčná zmluva EULA a právne vyhlásenia aplikácie Encore.',
}

export default function TermsPage() {
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
              PRÁVNE INFORMÁCIE & LICENČNÁ ZMLUVA
            </p>
            <h1 className="font-rounded mt-3 text-3xl font-black tracking-tight text-white sm:text-4xl">
              Podmienky používania & Licenčná zmluva (EULA)
            </h1>
            <p className="mt-2 text-xs text-white/60">
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
              Encore ponúka bezplatnú verziu (Free) a voliteľné prémiové balíky s automatickým obnovovaním (<strong>Encore Plus</strong> a <strong>Encore Premium</strong>):
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
                <strong>Zvukový obsah:</strong> Metronóm generuje zvuk matematickou PCM syntézou priamo v RAM pamäti zariadenia.
              </li>
            </ul>
          </section>

          {/* Section 5: Age restriction */}
          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">5. Vekové obmedzenie a ochrana mladistvých (GDPR)</h2>
            <p>
              Aplikácia Encore je určená pre tanečníkov všetkých vekových kategórií vrátane juniorov a mládeže. Používatelia mladší ako 16 rokov môžu aplikáciu používať a zakladať si účet výhradne so súhlasom svojho zákonného zástupcu (rodiča) v súlade s článkom 8 nariadenia GDPR a zákonom č. 18/2018 Z. z. o ochrane osobných údajov.
            </p>
          </section>

          {/* Section 6: Disclaimers */}
          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">6. Zrieknutie sa zodpovednosti (Disclaimers)</h2>
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

          {/* Section 7: Contact */}
          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">7. Kontaktné údaje a právna podpora</h2>
            <p>
              V prípade akýchkoľvek právnych otázok alebo nahlásenia porušenia podmienok nás kontaktujte na:{' '}
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
      </main>

      <LandingFooter />
    </div>
  )
}
