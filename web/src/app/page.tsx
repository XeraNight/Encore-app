import type { Metadata } from 'next'
import type { ComponentType, SVGProps } from 'react'
import LandingNavbar from '@/components/landing/LandingNavbar'
import AppStoreButton from '@/components/landing/AppStoreButton'
import PhoneFrame from '@/components/landing/PhoneFrame'
import Reveal from '@/components/landing/Reveal'
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
    'Zostavy na parkete, poznámky od trénera, tréningový plán a výsledky z KSIS v jednej aplikácii pre iPhone. Pre tanečníkov, páry a trénerov štandardných a latinskoamerických tancov.',
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

const PILLARS: { icon: Icon; title: string; text: string }[] = [
  {
    icon: IconFloor,
    title: 'Zostavy',
    text: 'Figúry na parkete tak, ako ich tancuješ: smer, doby a poznámka ku každému prechodu.',
  },
  {
    icon: IconTarget,
    title: 'Tréning',
    text: 'Korekcie od trénera, týždenný plán, samotréningy a krátka reflexia po každom tréningu.',
  },
  {
    icon: IconTrophy,
    title: 'Súťaže',
    text: 'Umiestnenia a krížiky od porotcov z KSIS, pekne v denníku a v kalendári sezóny.',
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
  screenLabel: string
  note?: string
}[] = [
  {
    id: 'parket',
    eyebrow: 'Parket',
    icon: IconFloor,
    title: 'Zostava, ktorú obaja tancujete rovnako.',
    text: 'Poskladaj figúry na parkete presne tak, ako idú v sále. Partner aj tréner vidia tú istú verziu a každú zmenu hneď.',
    points: ['Doby, nášľapy a smer tanca pri každej figúre', 'Poznámka k prechodu medzi figúrami', 'Zdieľanie QR kódom alebo priamo s partnerom'],
    screen: SCREENS.canvas,
    screenLabel: 'Parket',
  },
  {
    id: 'po-lekcii',
    eyebrow: 'Po lekcii',
    icon: IconMic,
    title: 'Minúta po lekcii stačí.',
    text: 'Kým začne ďalšia lekcia, nadiktuj, čo tréner povedal. Encore to prepíše po slovensky a uloží k tancu alebo figúre.',
    points: ['Diktovanie a hlasové poznámky', 'Top 3 korekcie na Domove, kým ich nezvládneš', 'Všetky poznámky na jednom mieste'],
    screen: SCREENS.notes,
    screenLabel: 'Poznámky a Top 3',
  },
  {
    id: 'video',
    eyebrow: 'Video',
    icon: IconVideo,
    title: 'Tvoje video vedľa vzoru.',
    text: 'Pusti si svoje video z tréningu a vzor naraz, spomaľ ich a opakuj problémové miesto, kým nevidíš rozdiel.',
    points: ['Porovnanie dvoch videí vedľa seba', 'Spomalenie a slučka na jeden krok', 'S Premium: vzor priesvitne cez tvoje video a olovnica'],
    screen: SCREENS.video,
    screenLabel: 'Porovnanie videí',
  },
  {
    id: 'plan',
    eyebrow: 'Plán',
    icon: IconCalendar,
    title: 'Týždeň, ktorý máš pod kontrolou.',
    text: 'Tréningy, samotréningy a súťaže v jednom kalendári. Keď tréning odpadne, ťukneš Nejdem a zmizne aj z Apple Kalendára.',
    points: ['Týždenný režim a jednorazové tréningy', 'Poznámky z každého dňa v kalendári', 'Hodiny tréningu a samotréningu za týždeň'],
    screen: SCREENS.plan,
    screenLabel: 'Plán a kalendár',
  },
  {
    id: 'sutaze',
    eyebrow: 'Súťaže',
    icon: IconTrophy,
    title: 'Každá súťaž. Každý krížik.',
    text: 'V aplikácii otvoríš KSIS a jedným ťuknutím uložíš svoje výsledky aj krížiky od porotcov. Celá sezóna je potom v denníku a v kalendári.',
    points: ['Umiestnenie, body a finále z KSIS', 'Krížiky od každého porotcu v každom kole', 'Kalendár odtancovaných súťaží'],
    screen: SCREENS.competitions,
    screenLabel: 'Súťaže',
    note: 'Encore nie je oficiálna aplikácia SZTŠ. Výsledky si ukladáš z verejného systému KSIS.',
  },
]

const STEPS = [
  { title: 'Vytvor si účet', text: 'E-mailom, cez Google alebo Apple. Zadarmo.' },
  { title: 'Prepoj sa s partnerom', text: 'Naskenuje tvoj QR kód a ty prepojenie potvrdíš.' },
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
    <div className="relative min-h-screen overflow-x-clip bg-[#0f0205] text-white">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(JSON_LD) }} />
      <div aria-hidden className="landing-glow pointer-events-none absolute inset-x-0 top-0 h-[900px]" />

      <LandingNavbar />

      <main className="relative">
        {/* Hero */}
        <section className="mx-auto grid max-w-6xl items-center gap-14 px-4 pb-20 pt-32 sm:px-6 sm:pt-40 lg:grid-cols-[1.1fr_0.9fr] lg:gap-10 lg:pb-28">
          <div className="text-center lg:text-left">
            <p className="font-rounded text-xs font-black uppercase tracking-[0.2em] text-[#FFE088]">
              Pre spoločenské tance
            </p>
            <h1 className="font-serif mt-5 text-5xl font-bold leading-[1.04] tracking-tight sm:text-6xl lg:text-7xl">
              Všetko z tréningu.
              <br />
              <span className="text-[#FFE088]">V jednom mobile.</span>
            </h1>
            <p className="mx-auto mt-6 max-w-xl text-lg leading-relaxed text-white/75 lg:mx-0">
              Zostavy na parkete, korekcie od trénera, tréningový plán a výsledky z KSIS. Encore je denník pre tanečníkov,
              páry a trénerov štandardných a latinskoamerických tancov.
            </p>
            <div className="mt-9 flex flex-col items-center gap-4 sm:flex-row sm:justify-center lg:justify-start">
              <AppStoreButton />
              <a href="#funkcie" className="py-3 text-sm font-semibold text-white/80 underline-offset-4 hover:text-white hover:underline">
                Pozrieť, čo Encore vie
              </a>
            </div>
            <p className="mt-5 text-sm text-white/55">Zadarmo pre iPhone · Plus a Premium voliteľne</p>
          </div>

          <div className="relative mx-auto h-[520px] w-full max-w-[420px] sm:h-[600px]">
            <div className="absolute left-0 top-10 w-[58%] -rotate-6 opacity-90">
              <PhoneFrame src={SCREENS.plan} alt="Plán a kalendár" />
            </div>
            <div className="absolute right-0 top-0 w-[62%]">
              <PhoneFrame src={SCREENS.home} alt="Domov" priority />
            </div>
          </div>
        </section>

        {/* Trust facts: only what is true today */}
        <section aria-label="Prečo Encore" className="border-y border-white/10 bg-white/[0.02]">
          <ul className="mx-auto grid max-w-6xl grid-cols-2 gap-6 px-4 py-8 text-sm text-white/75 sm:px-6 lg:grid-cols-4">
            {TRUST.map(({ icon: TrustIcon, label }) => (
              <li key={label} className="flex items-center gap-3">
                <TrustIcon className="h-5 w-5 flex-none text-[#FFE088]" />
                <span>{label}</span>
              </li>
            ))}
          </ul>
        </section>

        {/* Pillars */}
        <section id="funkcie" className="mx-auto max-w-6xl px-4 pt-24 sm:px-6 sm:pt-32">
          <Reveal className="mx-auto max-w-2xl text-center">
            <p className="font-rounded text-xs font-black uppercase tracking-[0.2em] text-[#FFE088]">Funkcie</p>
            <h2 className="font-serif mt-4 text-4xl font-bold tracking-tight sm:text-5xl">Tri veci, ktoré si doteraz nosil v hlave.</h2>
          </Reveal>
          <div className="mt-14 grid gap-5 md:grid-cols-3">
            {PILLARS.map(({ icon: PillarIcon, title, text }, index) => (
              <Reveal key={title} delay={index * 90}>
                <article className="h-full rounded-3xl border border-white/10 bg-white/[0.04] p-7">
                  <span className="flex h-11 w-11 items-center justify-center rounded-2xl bg-[#FFE088]/10 text-[#FFE088]">
                    <PillarIcon className="h-6 w-6" />
                  </span>
                  <h3 className="mt-6 text-xl font-semibold">{title}</h3>
                  <p className="mt-2 leading-relaxed text-white/70">{text}</p>
                </article>
              </Reveal>
            ))}
          </div>
        </section>

        {/* Features, alternating */}
        <div className="mx-auto max-w-6xl space-y-28 px-4 py-24 sm:space-y-36 sm:px-6 sm:py-32">
          {FEATURES.map((feature, index) => {
            const FeatureIcon = feature.icon
            const flipped = index % 2 === 1
            return (
              <section key={feature.id} id={feature.id} className="grid items-center gap-12 lg:grid-cols-2 lg:gap-20">
                <Reveal className={flipped ? 'lg:order-2' : ''}>
                  <p className="flex items-center gap-2 font-rounded text-xs font-black uppercase tracking-[0.2em] text-[#FFE088]">
                    <FeatureIcon className="h-4 w-4" />
                    {feature.eyebrow}
                  </p>
                  <h2 className="font-serif mt-4 text-3xl font-bold tracking-tight sm:text-4xl">{feature.title}</h2>
                  <p className="mt-4 text-lg leading-relaxed text-white/70">{feature.text}</p>
                  <ul className="mt-6 space-y-3">
                    {feature.points.map((point) => (
                      <li key={point} className="flex gap-3 text-white/80">
                        <IconCheck className="mt-1 h-4 w-4 flex-none text-[#FFE088]" />
                        <span>{point}</span>
                      </li>
                    ))}
                  </ul>
                  {feature.note && <p className="mt-6 text-sm text-white/50">{feature.note}</p>}
                </Reveal>
                <Reveal delay={120} className={`mx-auto w-full max-w-[300px] ${flipped ? 'lg:order-1' : ''}`}>
                  <PhoneFrame src={feature.screen} alt={feature.screenLabel} />
                </Reveal>
              </section>
            )
          })}
        </div>

        {/* How it works */}
        <section className="border-y border-white/10 bg-white/[0.02]">
          <div className="mx-auto max-w-6xl px-4 py-20 sm:px-6 sm:py-24">
            <Reveal className="text-center">
              <h2 className="font-serif text-3xl font-bold tracking-tight sm:text-4xl">Začneš za minútu</h2>
            </Reveal>
            <ol className="mt-12 grid gap-8 md:grid-cols-3">
              {STEPS.map((step, index) => (
                <Reveal key={step.title} delay={index * 90}>
                  <li className="flex gap-4">
                    <span className="flex h-10 w-10 flex-none items-center justify-center rounded-full border border-[#FFE088]/40 font-rounded text-sm font-black text-[#FFE088]">
                      {index + 1}
                    </span>
                    <div>
                      <h3 className="text-lg font-semibold">{step.title}</h3>
                      <p className="mt-1 text-white/70">{step.text}</p>
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
