import type { Metadata } from 'next'
import type { ComponentType, SVGProps } from 'react'
import LandingNavbar from '@/components/landing/LandingNavbar'
import AppStoreButton from '@/components/landing/AppStoreButton'
import PhoneFrame from '@/components/landing/PhoneFrame'
import Reveal from '@/components/landing/Reveal'
import ShowreelVideo from '@/components/landing/ShowreelVideo'
import AudienceTabs from '@/components/landing/AudienceTabs'
import PricingSection from '@/components/landing/PricingSection'
import Faq from '@/components/landing/Faq'
import DownloadCTA from '@/components/landing/DownloadCTA'
import LandingFooter from '@/components/landing/LandingFooter'
import {
  IconCalendar,
  IconCheck,
  IconFloor,
  IconMic,
  IconNoAds,
  IconOffline,
  IconPeople,
  IconShield,
  IconTarget,
  IconTrophy,
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
    images: [{ url: '/encore_stage_bg.jpg', width: 1200, height: 630, alt: 'Encore' }],
  },
}

type Icon = ComponentType<SVGProps<SVGSVGElement>>

const TRUST: { icon: Icon; label: string }[] = [
  { icon: IconOffline, label: 'Funguje aj bez signálu v sále' },
  { icon: IconShield, label: 'Dáta na serveroch v EÚ' },
  { icon: IconNoAds, label: 'Bez reklám' },
  { icon: IconPeople, label: 'Po slovensky, pre slovenské súťaže' },
]

const PILLARS: { icon: Icon; eyebrow: string; title: string; text: string }[] = [
  {
    icon: IconMic,
    eyebrow: 'DO 2 SEKÚND PO LEKCII',
    title: 'Text, Hlas, Kamera',
    text: 'Zídeš z parketu a jedným ťuknutím zapíšeš postreh, nadiktuješ hlasovú poznámku alebo natočíš video rovno k tancu.',
  },
  {
    icon: IconFloor,
    eyebrow: 'ZOSTAVY NA PARKETE',
    title: 'Dlhá a krátka stena',
    text: 'Figúry uložené v smere tanca presne podľa stien sály, s vlastnými názvami, dobami a poznámkami ku každému prechodu.',
  },
  {
    icon: IconTrophy,
    eyebrow: 'KALENDÁR A KSIS',
    title: 'Režim a súťaže',
    text: 'Týždenné tréningy, samotréningy, odpočet do najbližšej súťaže a uloženie výsledkov z KSIS jedným ťuknutím.',
  },
]

const FEATURES: {
  id: string
  eyebrow: string
  icon: Icon
  title: string
  text: string
  points: string[]
  screen?: string
  /** A loop of the real app in /video/app (app-<name>); shown instead of the screenshot. */
  video?: string
  screenLabel: string
  note?: string
}[] = [
  {
    id: 'po-lekcii',
    eyebrow: 'DOMOV · DENNÍK A TOP 3 PRIORITY',
    icon: IconMic,
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
    eyebrow: 'ZOSTAVY · 2D PARKET',
    icon: IconFloor,
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
    eyebrow: 'KALENDÁR · DNES A REŽIM',
    icon: IconCalendar,
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
    eyebrow: 'KSIS · VÝSLEDKOVÁ LISTINA',
    icon: IconTrophy,
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
  },
  {
    eyebrow: 'STRIH LEKCIE',
    title: 'Hodinové video rozdelené na figúry',
    text: 'Dlhé video z lekcie si v aplikácii rozstriháš na jednotlivé figúry a uložíš priamo k svojej zostave na parkete.',
  },
  {
    eyebrow: 'SÚŤAŽNÝ DEŇ',
    title: 'Rýchla príprava pred kolom',
    text: 'V deň súťaže máš tance zoradené v poradí a pri každom svoje Top 3 od trénera, ktoré si prečítaš za 10 sekúnd pred nástupom na parket.',
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

export default function HomePage() {
  return (
    <div className="relative min-h-screen overflow-x-clip bg-[#140206] text-[#F5F5F5]">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(JSON_LD) }} />
      {/* §1A EllegancePageBackground crimson velvet stage light; two soft pools of light and one spotlight beam drift
          slowly over it (transform only, see .stage-light in globals.css) */}
      <div aria-hidden className="pointer-events-none fixed inset-0 overflow-hidden">
        <div className="absolute inset-0 bg-[radial-gradient(75%_55%_at_50%_24%,rgba(154,13,31,0.44),rgba(120,5,20,0.22)_52%,transparent_80%),radial-gradient(50%_40%_at_82%_14%,rgba(212,175,55,0.08),transparent_70%)]" />
        <div className="stage-light stage-light-a" />
        <div className="stage-light stage-light-b" />
        <div className="stage-beam" />
      </div>

      <LandingNavbar />

      <main className="relative">
        {/* Hero */}
        <section className="mx-auto grid max-w-6xl items-center gap-14 px-5 pb-20 pt-32 sm:px-6 sm:pt-40 lg:grid-cols-[1.08fr_0.92fr] lg:gap-12 lg:pb-28">
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
                className="inline-flex min-h-11 items-center rounded-2xl border border-white/15 bg-white/[0.07] px-5 py-3 text-sm font-semibold text-white/90 transition hover:border-[#FFE088]/40 hover:text-white active:scale-[0.97]"
              >
                Pozrieť obrazovky z apky
              </a>
            </div>
            <p className="mt-5 text-sm text-white/65">Zadarmo pre iPhone · Plus a Premium voliteľne</p>
          </div>

          <div className="relative mx-auto h-[520px] w-full max-w-[430px] sm:h-[610px]">
            <div className="absolute left-0 top-10 w-[58%] -rotate-6 opacity-95 transition duration-300 hover:rotate-0">
              <PhoneFrame src={SCREENS.canvas} video="canvas" alt="Zostavy – Slowfox na parkete" />
            </div>
            <div className="absolute right-0 top-0 w-[62%]">
              <PhoneFrame src={SCREENS.home} video="home" alt="Domov – rýchly zápis, Denník a Top 3 priority" priority />
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
        <section aria-label="Prečo Encore" className="border-y border-white/10 bg-white/[0.04] backdrop-blur-md">
          <ul className="mx-auto grid max-w-6xl grid-cols-2 gap-6 px-5 py-7 text-sm font-medium text-white/80 sm:px-6 lg:grid-cols-4">
            {TRUST.map(({ icon: TrustIcon, label }) => (
              <li key={label} className="flex items-center gap-3">
                <TrustIcon className="h-5 w-5 flex-none text-[#FFE088]" />
                <span>{label}</span>
              </li>
            ))}
          </ul>
        </section>

        {/* Pillars (§1A glass cards: white 7%, border white 10% 1pt, radius 20pt) */}
        <section id="funkcie" className="mx-auto max-w-6xl px-5 pt-24 sm:px-6 sm:pt-32">
          <Reveal className="mx-auto max-w-2xl text-center">
            <p className="font-rounded text-xs font-black uppercase tracking-[0.16em] text-[#FFE088]">HLAVNÁ SLUČKA TRÉNINGU</p>
            <h2 className="font-rounded mt-3 text-3xl font-black tracking-tight sm:text-5xl">
              Tri veci, ktoré si doteraz nosil v hlave.
            </h2>
          </Reveal>
          <div className="mt-12 grid gap-5 md:grid-cols-3">
            {PILLARS.map(({ icon: PillarIcon, eyebrow, title, text }, index) => (
              <Reveal key={title} delay={index * 90}>
                <article className="h-full rounded-[20px] border border-white/10 bg-white/[0.07] p-6 backdrop-blur-md">
                  <div className="flex items-center gap-2.5">
                    <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-[#FFE088]/15 text-[#FFE088]">
                      <PillarIcon className="h-5 w-5" />
                    </span>
                    <p className="font-rounded text-[11px] font-black uppercase tracking-[0.14em] text-[#FFE088]">
                      {eyebrow}
                    </p>
                  </div>
                  <h3 className="font-rounded mt-4 text-xl font-bold text-white">{title}</h3>
                  <p className="mt-2 text-[15px] leading-relaxed text-white/75">{text}</p>
                </article>
              </Reveal>
            ))}
          </div>
        </section>

        {/* Features, alternating with real app screenshots */}
        <div className="mx-auto max-w-6xl space-y-24 px-5 py-24 sm:space-y-32 sm:px-6 sm:py-32">
          {FEATURES.map((feature, index) => {
            const FeatureIcon = feature.icon
            const flipped = index % 2 === 1
            return (
              <section key={feature.id} id={feature.id} className="grid items-center gap-12 lg:grid-cols-2 lg:gap-20">
                <Reveal className={flipped ? 'lg:order-2' : ''}>
                  <div className="rounded-[20px] border border-white/10 bg-white/[0.07] p-7 sm:p-9 backdrop-blur-md">
                    <p className="flex items-center gap-2 font-rounded text-xs font-black uppercase tracking-[0.14em] text-[#FFE088]">
                      <FeatureIcon className="h-4 w-4" />
                      {feature.eyebrow}
                    </p>
                    <h2 className="font-rounded mt-3 text-2xl font-black tracking-tight text-white sm:text-4xl">
                      {feature.title}
                    </h2>
                    <p className="mt-4 text-base leading-relaxed text-white/75 sm:text-lg">{feature.text}</p>
                    <ul className="mt-6 space-y-3 border-t border-white/10 pt-5">
                      {feature.points.map((point) => (
                        <li key={point} className="flex gap-3 text-[15px] text-white/85">
                          <IconCheck className="mt-1 h-4 w-4 flex-none text-[#FFE088]" />
                          <span>{point}</span>
                        </li>
                      ))}
                    </ul>
                    {feature.note && <p className="mt-5 text-xs text-white/60">{feature.note}</p>}
                  </div>
                </Reveal>
                <Reveal delay={120} className={`mx-auto w-full max-w-[300px] ${flipped ? 'lg:order-1' : ''}`}>
                  <PhoneFrame src={feature.screen} video={feature.video} alt={feature.screenLabel} />
                </Reveal>
              </section>
            )
          })}
        </div>

        {/* Video & Competition Day tools (§1A glass cards) */}
        <section id="video" className="mx-auto max-w-6xl px-5 pb-24 sm:px-6 sm:pb-32">
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
                <article className="h-full rounded-[20px] border border-white/10 bg-white/[0.07] p-6 backdrop-blur-md">
                  <p className="font-rounded text-[11px] font-black uppercase tracking-[0.14em] text-[#FFE088]">
                    {tool.eyebrow}
                  </p>
                  <h3 className="font-rounded mt-3 text-xl font-bold text-white">{tool.title}</h3>
                  <p className="mt-2 text-[15px] leading-relaxed text-white/75">{tool.text}</p>
                </article>
              </Reveal>
            ))}
          </div>
        </section>

        {/* How it works */}
        <section className="border-y border-white/10 bg-white/[0.04]">
          <div className="mx-auto max-w-6xl px-5 py-20 sm:px-6 sm:py-24">
            <Reveal className="text-center">
              <p className="font-rounded text-xs font-black uppercase tracking-[0.16em] text-[#FFE088]">ŠTART DO MINÚTY</p>
              <h2 className="font-rounded mt-3 text-3xl font-black tracking-tight sm:text-4xl">Začneš za minútu</h2>
            </Reveal>
            <ol className="mt-12 grid gap-6 md:grid-cols-3">
              {STEPS.map((step, index) => (
                <Reveal key={step.title} delay={index * 90}>
                  <li className="flex h-full gap-4 rounded-[20px] border border-white/10 bg-white/[0.07] p-6">
                    <span className="flex h-10 w-10 flex-none items-center justify-center rounded-full bg-[#FFE088] font-rounded text-sm font-black text-[#080808]">
                      {index + 1}
                    </span>
                    <div>
                      <h3 className="font-rounded text-lg font-bold text-white">{step.title}</h3>
                      <p className="mt-1 text-[15px] leading-relaxed text-white/75">{step.text}</p>
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
