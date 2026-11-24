import Link from 'next/link'
import type { Metadata } from 'next'
import LandingNavbar from '@/components/landing/LandingNavbar'
import LandingFooter from '@/components/landing/LandingFooter'

export const metadata: Metadata = {
  title: 'Zásady ochrany osobných údajov',
  description: 'Zásady ochrany osobných údajov a pravidlá spracúvania dát pre aplikáciu Encore – Dance Routine Studio.',
}

export default function PrivacyPolicyPage() {
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
              PRÁVNE INFORMÁCIE & OCHRANA SÚKROMIA (GDPR)
            </p>
            <h1 className="font-rounded mt-3 text-3xl font-black tracking-tight text-white sm:text-4xl">
              Zásady ochrany osobných údajov (Privacy Policy)
            </h1>
            <p className="mt-2 text-xs text-white/60">
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
                <strong>Mikrofón a hlasový prepis:</strong> Hlasové pokyny trénera prepisuje do textu rozpoznávanie reči od Apple. Zvuk pri tom môže spracovať Apple podľa svojich zásad ochrany súkromia. Encore zvukové nahrávky na svoj server neukladá, uloží sa len výsledný text poznámky.
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
              <li><strong>Formspree</strong>: spracúva správy z kontaktného formulára na tejto webstránke (meno, e-mail, text správy).</li>
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
      </main>

      <LandingFooter />
    </div>
  )
}
