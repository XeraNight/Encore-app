import type { Metadata } from 'next'
import type { ComponentType, SVGProps } from 'react'
import Image from 'next/image'
import LandingNavbar from '@/components/landing/LandingNavbar'
import AppStoreButton from '@/components/landing/AppStoreButton'
import PhoneFrame from '@/components/landing/PhoneFrame'
import Reveal from '@/components/landing/Reveal'
import ShowreelVideo from '@/components/landing/ShowreelVideo'
import ChaosToOrderSection from '@/components/landing/ChaosToOrderSection'
import FeatureSplitShowcase, { type SplitFeatureItem } from '@/components/landing/FeatureSplitShowcase'
import AudienceTabs from '@/components/landing/AudienceTabs'
import PricingSection from '@/components/landing/PricingSection'
import Faq from '@/components/landing/Faq'
import DownloadCTA from '@/components/landing/DownloadCTA'
import LandingFooter from '@/components/landing/LandingFooter'
import {
  IconNoAds,
  IconOffline,
  IconPeople,
  IconShield,
  IconVideo,
} from '@/components/landing/Icons'
import { FAQ, SCREENS, SITE_URL } from '@/lib/site'

export const metadata: Metadata = {
  title: { absolute: 'Encore – tréningový denník pre spoločenské tance' },
  description:
    'Zostavy na parkete, poznámky od trénera, tréningový plán a výsledky z KSIS v jednej aplikácii pre iPhone. Pre tanečníkov a páry štandardných a latinskoamerických tancov.',
  alternates: { canonical: '/' },
  openGraph: {
    title: 'Encore – tréningový denník pre spoločenské tance',
    description: 'Zostavy, poznámky od trénera, plán a výsledky zo súťaží. Aplikácia pre iPhone.',
    type: 'website',
    url: SITE_URL,
    locale: 'sk_SK',
    images: [{ url: '/og/encore-og-1200x630.jpg', width: 1200, height: 630, alt: 'Encore – tréningový denník pre spoločenské tance' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Encore – tréningový denník pre spoločenské tance',
    description: 'Zostavy, poznámky od trénera, plán a výsledky zo súťaží. Aplikácia pre iPhone.',
    images: ['/og/encore-og-1200x630.jpg'],
  },
}

type Icon = ComponentType<SVGProps<SVGSVGElement>>

const TRUST: { icon: Icon; label: string }[] = [
  { icon: IconOffline, label: 'Funguje aj bez signálu v sále' },
  { icon: IconShield, label: 'Dáta na serveroch v EÚ' },
  { icon: IconNoAds, label: 'Bez reklám' },
  { icon: IconPeople, label: 'Po slovensky, pre slovenské súťaže' },
]

const SPLIT_FEATURES: SplitFeatureItem[] = [
  {
    id: 'po-lekcii',
    step: '01',
    eyebrow: 'DOMOV · DENNÍK A TOP 3 PRIORITY',
    iconName: 'mic',
    title: 'Zídeš z parketu a do 2 sekúnd zapisuješ.',
    text: 'Hneď po otvorení máš pred sebou rýchly zápis: Text, Hlas alebo Kamera s výberom tanca. Pod ním vidíš svoj Denník a Top 3 priority od trénera, kým ich na tréningu nezvládneš.',
    points: [
      '1-tap zápis: Text, hlasový diktát alebo kamera priamo k vybranému tancu',
      'Denník s farebnými štítkami tancov (Slowfoxtrot, Rumba, Waltz...)',
      'Top 3 priority na Domove, aby si pred lekciou hneď vedel, na čom pracuješ',
    ],
    screen: SCREENS.notes,
    video: 'top3',
    screenLabel: 'Domov – Denník a Top 3 priority',
  },
  {
    id: 'parket',
    step: '02',
    eyebrow: 'ZOSTAVY · 2D PARKET',
    iconName: 'floor',
    title: 'Zostava na parkete presne podľa stien sály.',
    text: 'Poskladaj figúry po obvode parketu podľa dlhej a krátkej steny v smere tanca. Každú figúru si môžeš pomenovať po slovensky alebo po anglicky tak, ako ju voláte s trénerom.',
    points: [
      'Orientácia podľa DLHEJ a KRÁTKEJ STENY so šípkami smeru tanca',
      'Vlastné názvy figúr (Feather Step, Bounce Fallaway, Trojkrok, Pletenec, Zášvih...)',
      'Kreslenie na parket, zrkadlenie na obrazovku a zdieľanie zostavy partnerovi cez QR kód',
    ],
    screen: SCREENS.canvas,
    video: 'canvas',
    screenLabel: 'Zostavy – Slowfox na parkete',
  },
  {
    id: 'plan',
    step: '03',
    eyebrow: 'KALENDÁR · DNES A REŽIM',
    iconName: 'calendar',
    title: 'Týždeň, dnešný tréning a najbližšia súťaž.',
    text: 'V jednom kalendári máš odlíšený tréning, samotréning, súťaž aj zapísaný výsledok. Keď dnes na tréning nemôžeš, na karte Dnes ťukneš Nejdem a plán máš hneď upravený.',
    points: [
      'Prepínač Kalendár a týždenný Režim s automatickým prehľadom dní',
      'Karta DNES s časom, sálou, disciplínou (ŠTT / LAT) a rýchlym tlačidlom Nejdem',
      'Karta NAJBLIŽŠIA SÚŤAŽ s odpočtom dní, miestom konania a stavom (Zvažujem / Idem)',
    ],
    screen: SCREENS.plan,
    video: 'plan',
    screenLabel: 'Kalendár a denný plán',
  },
  {
    id: 'sutaze',
    step: '04',
    eyebrow: 'KSIS · VÝSLEDKOVÁ LISTINA',
    iconName: 'trophy',
    title: 'Otvoríš KSIS a jedným ťuknutím uložíš výsledok.',
    text: 'Priamo v aplikácii máš vstavaný prehliadač KSIS (Výsledky, Kalendár, Pohár, Moje páry). Keď otvoríš súťaž, Encore vytiahne umiestnenie, body aj finálovú bilanciu do spodnej karty.',
    points: [
      'Automaticky rozpoznaná Výsledková listina: miesto, získané body a celkové body/finále',
      'Uloženie jednej súťaže do histórie alebo všetkých súťaží páru naraz',
      'Prehľad výsledkov sezóny, krížikov od porotcov a mapy odtancovaných súťaží',
    ],
    screen: SCREENS.competitions,
    screenLabel: 'KSIS a uloženie výsledkov',
    note: 'Encore nie je oficiálna aplikácia SZTŠ. Výsledky si ukladáš z verejného systému KSIS.',
  },
]

const VIDEO_TOOLS = [
  {
    eyebrow: 'VIDEO DUEL',
    title: 'Tvoje video vedľa vzoru',
    text: 'Pusti si svoje video z tréningu a vzor naraz, spomaľ ich na kritický krok a zapni si priesvitný vzor alebo olovnicu.',
    image: '/images/iphone_filming_parquet.jpg',
    imageAlt: 'iPhone na parkete natáčajúci tanečný pár počas tréningu',
  },
  {
    eyebrow: 'STRIH LEKCIE',
    title: 'Hodinové video rozdelené na figúry',
    text: 'Dlhé video z lekcie si v aplikácii rozstriháš na jednotlivé figúry a uložíš priamo k svojej zostave na parkete.',
    image: '/images/training_couple.jpg',
    imageAlt: 'Tanečný pár na parkete prezerá rozstrihané figúry v iPhone',
  },
  {
    eyebrow: 'SÚŤAŽNÝ DEŇ',
    title: 'Rýchla príprava pred kolom',
    text: 'V deň súťaže máš tance zoradené v poradí a pri každom svoje Top 3 od trénera, ktoré si prečítaš za 10 sekúnd pred nástupom na parket.',
    image: '/images/competition_candid.jpg',
    imageAlt: 'Tanečný pár so štartovým číslom 42 pred nástupom na súťažný parket SZTŠ',
  },
]

const STEPS = [
  { title: 'Vytvor si účet', text: 'E-mailom, cez Google alebo Apple. Zadarmo.' },
  { title: 'Pridaj si spojenia', text: 'Naskenuj QR kód alebo zadaj ID tanečníka a označ svoj tanečný pár.' },
  { title: 'Trénuj', text: 'Zostavy, poznámky a výsledky sa skladajú samy do jedného denníka.' },
]

const JSON_LD = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'SoftwareApplication',
      name: 'Encore',
      operatingSystem: 'iOS',
      applicationCategory: 'SportsApplication',
      inLanguage: 'sk',
      url: SITE_URL,
      offers: { '@type': 'Offer', price: '0', priceCurrency: 'EUR' },
    },
    {
      '@type': 'FAQPage',
      mainEntity: FAQ.map((item) => ({
        '@type': 'Question',
        name: item.q,
        acceptedAnswer: { '@type': 'Answer', text: item.a },
      })),
    },
  ],
}

const STAGE_MOTES = [
  { left: '42%', top: '16%', size: 3, dur: '16s', delay: '-2s' },
  { left: '53%', top: '28%', size: 2.5, dur: '21s', delay: '-7s' },
  { left: '47%', top: '42%', size: 3.5, dur: '19s', delay: '-11s' },
  { left: '58%', top: '20%', size: 2, dur: '24s', delay: '-4s' },
  { left: '38%', top: '34%', size: 2.5, dur: '18s', delay: '-9s' },
  { left: '51%', top: '54%', size: 2, dur: '22s', delay: '-14s' },
]

export default function HomePage() {
  return (
    <div id="top" className="relative min-h-screen overflow-x-clip bg-[#140206] text-[#F5F5F5]">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(JSON_LD) }} />

      {/* Lightweight static crimson velvet wash (never invalidates GPU layers while scrolling) */}
      <div
        aria-hidden="true"
        className="pointer-events-none fixed inset-0 bg-[radial-gradient(75%_55%_at_50%_24%,rgba(154,13,31,0.42),rgba(120,5,20,0.2)_52%,transparent_80%),radial-gradient(50%_40%_at_82%_14%,rgba(212,175,55,0.08),transparent_70%)]"
      />

      <LandingNavbar />

      <main className="relative">
        {/* Hero with Hero-scoped animated spotlight + subtle Ellegance ballroom atmosphere */}
        <section className="relative overflow-hidden">
          <div aria-hidden="true" className="pointer-events-none absolute inset-0 overflow-hidden">
            <div className="stage-light stage-light-a" />
            <div className="stage-light stage-light-b" />
            <div className="stage-beam" />
            {STAGE_MOTES.map((m, i) => (
              <span
                key={i}
                className="stage-mote"
                style={{
                  left: m.left,
                  top: m.top,
                  width: `${m.size}px`,
                  height: `${m.size}px`,
                  ['--mote-dur' as string]: m.dur,
                  ['--mote-delay' as string]: m.delay,
                }}
              />
            ))}
          </div>
          <div
            aria-hidden="true"
            className="pointer-events-none absolute inset-0 opacity-[0.07] [mask-image:radial-gradient(ellipse_75%_65%_at_50%_38%,black_15%,transparent_82%)]"
          >
            <Image
              src="/images/hero_ballroom_floor.jpg"
              alt=""
              fill
              sizes="100vw"
              className="object-cover object-center mix-blend-luminosity"
            />
          </div>

          <div className="relative mx-auto grid max-w-6xl items-center gap-12 px-5 pb-20 pt-28 sm:px-6 sm:pt-36 lg:grid-cols-[1.08fr_0.92fr] lg:gap-12 lg:pb-24">
            <div className="text-center lg:text-left">
              <p className="font-rounded text-xs font-black uppercase tracking-[0.16em] text-[#FFE088]">
                PRE SPOLOČENSKÉ TANCE · ŠTT A LAT
              </p>
              <h1 className="font-rounded mt-4 text-4xl font-black leading-[1.06] tracking-tight sm:text-6xl lg:text-[4rem]">
                Zídeš z parketu.
                <br />
                <span className="text-[#FFE088]">Do 2 sekúnd zapisuješ.</span>
              </h1>
              <p className="mx-auto mt-6 max-w-xl text-lg leading-relaxed text-white/75 lg:mx-0">
                Rýchly zápis po lekcii (Text, Hlas, Kamera), 2D parket so zostavami, Top 3 priority od trénera, týždenný
                režim a výsledky z KSIS v jednej aplikácii pre iPhone.
              </p>
              <div className="mt-8 flex flex-wrap items-center justify-center gap-2.5 lg:justify-start">
                {['Text · Hlas · Kamera', '2D Parket', 'Top 3 Priority', 'KSIS Výsledky'].map((chip) => (
                  <span
                    key={chip}
                    className="rounded-full border border-[#FFE088]/30 bg-white/[0.07] px-3.5 py-1.5 font-rounded text-xs font-bold tracking-wide text-[#FFE088]"
                  >
                    {chip}
                  </span>
                ))}
              </div>
              <div className="mt-9 flex flex-col items-center gap-4 sm:flex-row sm:justify-center lg:justify-start">
                <AppStoreButton />
                <a
                  href="#funkcie"
                  className="inline-flex min-h-14 items-center rounded-2xl border border-white/15 bg-white/[0.07] px-6 py-3 font-rounded text-sm font-bold text-white/90 transition hover:border-[#FFE088]/45 hover:text-white active:scale-[0.97]"
                >
                  Pozrieť obrazovky z apky
                </a>
              </div>
              <p className="mt-5 text-sm text-white/65">Zadarmo pre iPhone · Plus a Premium voliteľne</p>
            </div>

            <div className="relative mx-auto h-[460px] w-full max-w-[350px] sm:h-[550px] sm:max-w-[400px]">
              <div className="absolute left-0 top-10 w-[56%] -rotate-6 opacity-95 transition duration-300 hover:rotate-0">
                <PhoneFrame src={SCREENS.canvas} video="canvas" alt="Zostavy – Slowfox na parkete" />
              </div>
              <div className="absolute right-0 top-0 w-[60%]">
                <PhoneFrame src={SCREENS.home} video="home" alt="Domov – rýchly zápis, Denník a Top 3 priority" priority />
              </div>
            </div>
          </div>
        </section>

        {/* The 27-second film of the app (sample data), right under the hero */}
        <section id="ukazka" aria-labelledby="ukazka-nadpis" className="mx-auto max-w-6xl px-5 pb-20 sm:px-6 lg:pb-28">
          <Reveal className="mx-auto mb-8 max-w-2xl text-center">
            <p className="font-rounded text-xs font-black uppercase tracking-[0.16em] text-[#FFE088]">27 SEKÚND S APPKOU</p>
            <h2 id="ukazka-nadpis" className="font-rounded mt-3 text-3xl font-black tracking-tight sm:text-4xl">
              Tréner povie 20 vecí. V Encore ostanú tri.
            </h2>
          </Reveal>
          <Reveal>
            <ShowreelVideo />
          </Reveal>
          <p className="mt-4 text-center text-xs text-white/60">Ukážka z appky s ukážkovými dátami.</p>
        </section>

        {/* Trust facts: only what is true today */}
        <section aria-label="Prečo Encore" className="border-t border-white/10 bg-white/[0.04]">
          <ul className="mx-auto grid max-w-6xl grid-cols-2 gap-6 px-5 py-7 text-sm font-medium text-white/80 sm:px-6 lg:grid-cols-4">
            {TRUST.map(({ icon: TrustIcon, label }) => (
              <li key={label} className="group flex items-center gap-3">
                <TrustIcon className="h-5 w-5 flex-none text-[#FFE088]" />
                <span>{label}</span>
              </li>
            ))}
          </ul>
        </section>

        {/* Scroll-Driven "Chaos -> Order" Scrollytelling Section */}
        <ChaosToOrderSection />

        {/* Framed Two-Tone Sticky Feature Showcase (Rounded Crimson Velvet Monolith on Warm Champagne Cream) */}
        <FeatureSplitShowcase features={SPLIT_FEATURES} />

        {/* Video & Competition Day tools (§1A glass cards on dark velvet — crisp full-width horizontal transition) */}
        <section id="video" className="border-t border-[#FFE088]/15">
          <div className="mx-auto max-w-6xl px-5 py-24 sm:px-6 sm:py-28">
            <Reveal className="mx-auto max-w-2xl text-center">
              <p className="inline-flex items-center gap-2 font-rounded text-xs font-black uppercase tracking-[0.16em] text-[#FFE088]">
                <IconVideo className="h-4 w-4" />
                NÁSTROJE V SÁLE A NA SÚŤAŽI
              </p>
              <h2 className="font-rounded mt-3 text-3xl font-black tracking-tight sm:text-4xl">
                Keď potrebuješ rozobrať detail alebo nastúpiť na kolo.
              </h2>
            </Reveal>
            <div className="mt-10 grid gap-5 md:grid-cols-3">
              {VIDEO_TOOLS.map((tool, index) => (
                <Reveal key={tool.title} delay={index * 90}>
                  <article className="group flex h-full flex-col overflow-hidden rounded-[20px] border border-white/10 bg-white/[0.07] transition hover:border-[#FFE088]/30">
                    <div className="relative aspect-[16/10] w-full overflow-hidden border-b border-white/10 bg-[#140206]">
                      <Image
                        src={tool.image}
                        alt={tool.imageAlt}
                        fill
                        sizes="(min-width: 768px) 360px, 92vw"
                        className="object-cover transition duration-500 group-hover:scale-[1.03] motion-reduce:transition-none"
                      />
                      <div
                        aria-hidden="true"
                        className="pointer-events-none absolute inset-0 bg-gradient-to-t from-[#140206]/85 via-[#140206]/20 to-transparent"
                      />
                      <p className="absolute bottom-3 left-5 font-rounded text-[11px] font-black uppercase tracking-[0.14em] text-[#FFE088]">
                        {tool.eyebrow}
                      </p>
                    </div>
                    <div className="p-6">
                      <h3 className="font-rounded text-xl font-bold text-white">{tool.title}</h3>
                      <p className="mt-2 text-[15px] leading-relaxed text-white/75">{tool.text}</p>
                    </div>
                  </article>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        {/* How it works — Warm Champagne Cream editorial band echoing the two-tone visual system */}
        <section className="border-y border-[#23090C]/10 bg-[#F6E9CE] text-[#23090C]">
          <div className="mx-auto max-w-6xl px-5 py-20 sm:px-6 sm:py-24">
            <Reveal className="text-center">
              <p className="font-rounded text-xs font-black uppercase tracking-[0.16em] text-[#7A0A1B]">ŠTART DO MINÚTY</p>
              <h2 className="font-rounded mt-3 text-3xl font-black tracking-tight text-[#23090C] sm:text-4xl">
                Začneš za minútu
              </h2>
            </Reveal>
            <ol className="mt-12 grid gap-6 md:grid-cols-3">
              {STEPS.map((step, index) => (
                <Reveal key={step.title} delay={index * 90}>
                  <li className="flex h-full gap-4 rounded-[20px] border border-[#23090C]/12 bg-[#FBF2DF] p-6 shadow-[0_12px_30px_-16px_rgba(35,9,12,0.18)]">
                    <span className="flex h-10 w-10 flex-none items-center justify-center rounded-full bg-[#5C0614] font-rounded text-sm font-black text-[#FFE8A3]">
                      {index + 1}
                    </span>
                    <div>
                      <h3 className="font-rounded text-lg font-bold text-[#23090C]">{step.title}</h3>
                      <p className="mt-1 text-[15px] leading-relaxed text-[#23090C]/75">{step.text}</p>
                    </div>
                  </li>
                </Reveal>
              ))}
            </ol>
          </div>
        </section>

        <AudienceTabs />
        <PricingSection />
        <Faq />
        <DownloadCTA />
      </main>

      <LandingFooter />
    </div>
  )
}
