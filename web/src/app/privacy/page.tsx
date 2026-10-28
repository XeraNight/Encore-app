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
              Posledná aktualizácia: 28. 10. 2026 • Verzia 1.2 (iOS / Web)
            </p>
          </div>

          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">1. Prevádzkovateľ a správca osobných údajov</h2>
            <p>
              Prevádzkovateľom mobilnej aplikácie <strong>Encore</strong> a pridruženej webovej platformy je Jakub Kalina (fyzická osoba, ďalej len „<strong>prevádzkovateľ</strong>“). Vaše súkromie rešpektujeme a chránime v súlade s Nariadením Európskeho parlamentu a Rady (EÚ) 2016/679 (GDPR) a zákonom č. 18/2018 Z. z. o ochrane osobných údajov.
            </p>
            <p>
              Kontaktný e-mail pre otázky a uplatnenie práv dotknutých osôb podľa GDPR:{' '}
              <a href="mailto:support@encore-sk.com" className="text-[#D4AF37] underline hover:opacity-80">
                support@encore-sk.com
              </a>.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">2. Aké osobné údaje spracúvame a prečo</h2>
            <ul className="list-disc pl-5 space-y-2 text-zinc-300">
              <li>
                <strong>Registračné údaje a účet:</strong> Meno alebo prezývka a e-mailová adresa (zadané priamo alebo cez prihlásenie Google či Apple). Slúžia výlučne na autentifikáciu a poskytovanie služby. Právny základ: plnenie zmluvy o poskytovaní služby (čl. 6 ods. 1 písm. b GDPR).
              </li>
              <li>
                <strong>Rok narodenia (len rok, nie celý dátum):</strong> Ak môže mať používateľ menej ako 16 rokov, pri registrácii súhlasí rodič (v zmysle čl. 8 GDPR a zákona č. 18/2018 Z. z., kde je na Slovensku hranica 16 rokov) a ostatní používatelia ho v aplikácii nájdu len podľa ID tanečníka alebo QR kódu, nie podľa mena. Právny základ: plnenie zmluvy a čl. 8 GDPR.
              </li>
              <li>
                <strong>Tanečné materiály a zostavy:</strong> Zostavy, choreografie, vlastné poznámky a nahrávky figúr. Vidí ich len používateľ a ľudia, s ktorými ich sám zdieľa.
              </li>
              <li>
                <strong>Záloha Denníka, Plánu a poznámok:</strong> Text zápisov z Denníka (reflexie po tréningu), Plánu (tréningy, súťaže, týždenný režim, Top 3 priority) a poznámok z Domova ukladáme na server Supabase v EÚ, aby sa vrátili na novom iPhone. Videá, hlasové poznámky a fotky ostávajú v iPhone. Vidí ich len používateľ a zmažú sa spolu s účtom.
              </li>
              <li>
                <strong>Tréningové videá a porovnanie so vzorom:</strong> Videá sú uložené vo Fotkách na zariadení používateľa. Pri porovnaní so vzorom kreslí čiary a sklon používateľ sám; aplikácia nerozpoznáva postavu ani tvár, videá nepoužíva na biometrickú identifikáciu a nevykonáva žiadnu automatickú analýzu postoja. Tréningové videá sa na servery neukladajú.
              </li>
              <li>
                <strong>Mikrofón a hlasový prepis:</strong> Hlasové nahrávky slúžia na okamžitý lokálny prepis pokynov trénera cez systémový Apple Speech Recognition do textu poznámky figúry priamo v iPhone. Samotné zvukové súbory sa na server neukladajú.
              </li>
              <li>
                <strong>Verejné súťažné dáta (SZTŠ / ksis.eu):</strong> Súťažné dáta z verejného systému KSIS (szts.ksis.eu), ktoré si používateľ uloží zo stránky KSIS otvorenej v aplikácii: kto ste v KSIS (osobné číslo z preukazu, meno, klub, triedy), Vaše páry a pri Vašich súťažiach trieda, body, finále a výsledky vrátane krížikov porotcov. Mená ostatných tanečníkov a párov sa neukladajú.
              </li>
            </ul>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">3. Doba uchovávania a zmazanie údajov</h2>
            <p>
              Vaše údaje uchovávame, kým aplikáciu používate a kým používateľ účet nezmaže. Kedykoľvek môžete v aplikácii v <strong>Profile → Nastavenia</strong> ťuknúť na <strong>„Zmazať účet a osobné dáta“</strong>. Tým sa natrvalo zmažú všetky Vaše údaje zo serverov a zruší sa prihlásenie.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">4. Vaše práva podľa GDPR</h2>
            <p>Ako dotknutá osoba máte podľa nariadenia GDPR právo na:</p>
            <ul className="list-disc pl-5 space-y-2 text-zinc-300">
              <li>
                <strong>Prístup k osobným údajom</strong> a informácie o ich spracúvaní,
              </li>
              <li>
                <strong>Opravu</strong> nesprávnych alebo neúplných údajov,
              </li>
              <li>
                <strong>Vymazanie</strong> (právo „na zabudnutie“) priamo v aplikácii,
              </li>
              <li>
                <strong>Prenosnosť</strong> a kópiu svojich údajov kedykoľvek (v aplikácii <strong>Profil → Nastavenia → Stiahnuť moje dáta</strong>),
              </li>
              <li>
                <strong>Podanie sťažnosti</strong> na dozorný orgán, ktorým je <strong>Úrad na ochranu osobných údajov SR</strong> (Hraničná 12, 820 07 Bratislava 27, statny.dozor@pdp.gov.sk).
              </li>
            </ul>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">5. Úložisko dát, bezpečnosť a spracovatelia (tretie strany)</h2>
            <p>
              Aplikácia Encore <strong>nepredáva, neprenajíma ani neposkytuje</strong> žiadne osobné údaje reklamným brokerom ani reklamným sieťam. Žiadne osobné údaje nesledujeme naprieč inými aplikáciami (App Tracking Transparency = No Tracking).
            </p>
            <p>
              Dáta sú bezpečne ukladané v databáze <strong>Supabase</strong> s platnou zmluvou o spracovaní údajov (DPA) a servermi umiestnenými v Európskej únii (Írsko). Komunikácia je šifrovaná pomocou TLS/HTTPS a prístup k databáze chránia striktné bezpečnostné politiky Row Level Security (RLS). Na iPhone sú dáta izolované v systéme Apple Sandbox a autentifikačná relácia je bezpečne uložená v systémovej Kľúčenke (Keychain).
            </p>
            <p>
              Aplikácia na servery neukladá žiadne profilové fotky používateľov ani žiadne údaje o nákupoch a platbách (predplatné a platby spracúva výhradne Apple cez StoreKit v App Store; Encore nemá prístup k platobným kartám). Zdieľanie videí je vo verzii 1 vypnuté; tréningové videá ostávajú výlučne vo Fotkách na Vašom iPhone.
            </p>
            <p>Na prevádzku služby využívame týchto zmluvných spracovateľov:</p>
            <ul className="list-disc pl-5 space-y-2">
              <li><strong>Supabase</strong> (Írsko, EÚ): používateľské účty, autentifikácia, textové zálohy a databáza so šifrovaním TLS.</li>
              <li><strong>Cloudflare</strong> (dátové centrá v EÚ): správa domény a bezpečnosť sieťovej infraštruktúry.</li>
              <li><strong>Resend</strong> (Írsko, EÚ): odosielanie e-mailov s overovacím kódom a obnovou hesla.</li>
              <li><strong>Apple</strong> a <strong>Google</strong>: prihlásenie cez Apple alebo Google, ak si ho zvolíte; platby predplatného spracúva výhradne Apple (App Store).</li>
              <li><strong>Vercel</strong>: hosting a prevádzka tejto webovej stránky a anonymná technická prevádzka.</li>
              <li><strong>PostHog</strong> (EÚ): súhrnná anonymná štatistika používania webovej stránky bez cookies a bez profilovania návštevníkov. Upozorňujeme, že PostHog sa týka výlučne tejto webstránky – mobilná aplikácia Encore žiadnu analytiku, telemetriu ani PostHog neobsahuje a nepoužíva.</li>
              <li><strong>Formspree</strong>: doručenie správy z kontaktného formulára na stránke Podpora.</li>
            </ul>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">6. Verejné športové dáta (SZTŠ / ksis.eu)</h2>
            <p>
              Keď v aplikácii otvoríte stránku KSIS, aplikácia ju pošle na náš server, ktorý z nej prečíta len údaje o Vás. Uloží: kto ste v KSIS (osobné číslo z preukazu, meno, klub a triedy, keď sa sami vyberiete v zozname členov), Vaše páry vrátane skončených a pri Vašich súťažiach triedu, body, finále, umiestnenia a krížiky porotcov. Mená ostatných členov a párov sa neukladajú. Kým Vás neoverí Encore alebo Váš overený partner či partnerka, tieto údaje vidíte len Vy. Páry ukladáte so súhlasom partnera alebo partnerky a každý pár aj s jeho výsledkami môžete kedykoľvek odstrániť. Ak ste overený a v nastaveniach zapnete ukazovanie výsledkov spojeniam, používatelia, s ktorými ste spojení, uvidia triedu, body a uložené súťaže Vašich párov (predvolene je to vypnuté). Právny základ: oprávnený záujem (čl. 6 ods. 1 písm. f GDPR), evidencia vlastnej športovej výkonnosti. Jediným oficiálnym a záväzným zdrojom výsledkov je Slovenský zväz tanečného športu (SZTŠ).
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-semibold text-white">7. Zmazanie účtu a prenosnosť dát (GDPR & Apple 5.1.1(v))</h2>
            <p>
              V súlade s nariadením GDPR a smernicou Apple App Store Review Guideline 5.1.1(v) máte plné právo kedykoľvek stiahnuť svoje dáta alebo požiadať o trvalé zmazanie svojho účtu a všetkých asociovaných dát:
            </p>
            <div className="bg-[#121118] border border-[#D4AF37]/20 rounded-xl p-5 my-3 space-y-3">
              <h3 className="text-white font-medium">Správa a vymazanie dát priamo v aplikácii:</h3>
              <ul className="text-zinc-400 text-sm space-y-1.5 list-disc pl-5">
                <li>
                  <strong>Stiahnutie dát (prenosnosť):</strong> V Encore prejdite do <strong>Profil → Nastavenia → Stiahnuť moje dáta</strong> pre okamžité stiahnutie kópie Vašich uložených údajov.
                </li>
                <li>
                  <strong>Zmazanie účtu (právo na vymazanie):</strong> V Encore prejdite do <strong>Profil → Nastavenia → Zmazať účet a osobné dáta</strong>. Týmto krokom sa okamžite a trvalo vymažú Vaše prihlasovacie údaje, textové zálohy, choreografie a profil z databázy.
                </li>
              </ul>
              <div className="pt-2 border-t border-[#D4AF37]/10">
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
            <h2 className="text-lg font-semibold text-white">8. Kontakt pre otázky ochrany osobných údajov</h2>
            <p>
              V prípade akýchkoľvek otázok, uplatnenia práv dotknutých osôb alebo pripomienok nás kontaktujte na:{' '}
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
