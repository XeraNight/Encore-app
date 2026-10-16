// One place for everything the landing page states about the app. Prices and plan contents mirror the
// iOS paywall (Encore/SubscriptionPaywallView.swift, EncoreProducts.storekit); change them together.

export const SITE_URL = 'https://www.encore-sk.com'
export const SUPPORT_EMAIL = 'support@encore-sk.com'
export const OPERATOR = 'Jakub Kalina'

/** Redirects to the App Store listing (set NEXT_PUBLIC_APP_STORE_ID on Vercel). */
export const APP_STORE_PATH = '/download/ios'

/**
 * Real screenshots from the app, in public/screens. While a screen is missing (undefined), the phone
 * frame shows a neutral branded placeholder instead.
 */
export const SCREENS: Record<'home' | 'canvas' | 'notes' | 'video' | 'plan' | 'competitions', string | undefined> = {
  home: undefined,
  canvas: undefined,
  notes: undefined,
  video: undefined,
  plan: undefined,
  competitions: undefined,
}

export type Billing = 'monthly' | 'annual'

export interface Plan {
  name: 'Free' | 'Plus' | 'Premium'
  tagline: string
  price: Record<Billing, string>
  /** Annual saving against twelve monthly payments, shown on the annual tab. */
  annualSaving?: string
  features: string[]
  highlighted?: boolean
}

export const PLANS: Plan[] = [
  {
    name: 'Free',
    tagline: 'Navždy zadarmo. Všetko podstatné na tréning.',
    price: { monthly: '0 €', annual: '0 €' },
    features: [
      'Parket a jedna zostava na každý tanec',
      'Poznámky, diktovanie a hlasové poznámky',
      'Tréningový plán a kalendár',
      'Výsledky a krížiky z KSIS',
      'Spoločné zostavy s partnerom',
      'Zdieľanie zostavy QR kódom',
    ],
  },
  {
    name: 'Plus',
    tagline: 'Pre páry, ktoré trénujú každý týždeň.',
    price: { monthly: '5,99 €', annual: '49,99 €' },
    annualSaving: 'ušetríš 30 %',
    highlighted: true,
    features: [
      'Všetko z Free',
      'Neobmedzené zostavy na každý tanec',
      'Top 3 priority od trénera po každej lekcii',
      'Moja sezóna: krížiky podľa tancov a vývoj počas sezóny',
      'Súťažný deň: tance v poradí a pri každom tvoje Top 3',
      'Vývoj tréningov za mesiace a sezónu',
      'Strih hodinovej lekcie na jednotlivé figúry',
    ],
  },
  {
    name: 'Premium',
    tagline: 'Pre tých, ktorí chcú vidieť každý detail.',
    price: { monthly: '14,99 €', annual: '129,99 €' },
    annualSaving: 'ušetríš 28 %',
    features: [
      'Všetko z Plus',
      'Porovnanie so vzorom: priesvitný vzor, olovnica, sklon ramien',
      'Korekcie z porovnania uložené rovno k figúre',
    ],
  },
]

export const FAQ: { q: string; a: string }[] = [
  {
    q: 'Je Encore oficiálna aplikácia SZTŠ?',
    a: 'Nie. Encore je nezávislá aplikácia. Výsledky si ukladáš sám z verejného systému KSIS a jediným oficiálnym zdrojom výsledkov a bodov ostáva Slovenský zväz tanečného športu.',
  },
  {
    q: 'Ako sa do Encore dostanú moje výsledky?',
    a: 'V aplikácii otvoríš KSIS, nájdeš svoj pár a jedným ťuknutím uložíš históriu súťaží. Po každej ďalšej súťaži si takto uložíš aj umiestnenie a krížiky od porotcov.',
  },
  {
    q: 'Funguje Encore bez internetu?',
    a: 'Áno. Zostavy, poznámky a plán máš priamo v telefóne, takže v sále bez signálu fungujú. Keď je pripojenie, zmeny sa zosynchronizujú s partnerom.',
  },
  {
    q: 'Kto vidí moje zostavy a videá?',
    a: 'Zostavy vidíš ty a partner, s ktorým sa v aplikácii prepojíš. Prepojenie potvrdzuješ ty a kedykoľvek ho môžeš zrušiť. Dáta sú uložené na serveroch v EÚ. Videá ostávajú v tvojich Fotkách a partnerovi ich pošleš sám.',
  },
  {
    q: 'Je Encore aj pre Android?',
    a: 'Zatiaľ je Encore iba pre iPhone. Verziu pre Android plánujeme neskôr.',
  },
  {
    q: 'Môžem Encore používať zadarmo?',
    a: 'Áno, navždy. Free obsahuje parket, poznámky, plán, výsledky z KSIS aj zdieľanie s partnerom. Plus a Premium pridávajú viac zostáv, Top 3 priority a analýzu videa.',
  },
  {
    q: 'Ako zruším predplatné?',
    a: 'V Nastaveniach iPhonu ťukni na svoje meno, potom Predplatné a Encore. Predplatné platí do konca zaplateného obdobia a potom sa už neobnoví.',
  },
  {
    q: 'Ako zmažem svoj účet?',
    a: 'V aplikácii v Profile → Nastavenia → Zmazať účet a osobné dáta. Zmažú sa všetky tvoje údaje na serveri. Postup nájdeš aj na stránke Zmazanie účtu.',
  },
]
