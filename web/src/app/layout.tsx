import type { Metadata } from 'next'
import { Inter, Playfair_Display } from 'next/font/google'
import './globals.css'
import { PostHogProvider } from '@/components/PostHogProvider'
import { Analytics } from '@vercel/analytics/next'

const inter = Inter({ subsets: ['latin', 'latin-ext'], display: 'swap', variable: '--font-inter' })
const playfair = Playfair_Display({ subsets: ['latin', 'latin-ext'], display: 'swap', variable: '--font-playfair' })

export const metadata: Metadata = {
  metadataBase: new URL('https://www.encore-sk.com'),
  title: {
    default: 'Encore – tréningový denník pre spoločenské tance',
    template: '%s · Encore',
  },
  description: 'Zostavy, poznámky od trénera, tréningový plán a výsledky zo súťaží v jednej aplikácii pre iPhone. Pre tanečníkov a páry štandardných a latinskoamerických tancov.',
  icons: {
    icon: [
      { url: '/favicon.ico' },
      { url: '/icon.png', type: 'image/png' },
    ],
    apple: [
      { url: '/apple-icon.png' },
    ],
  },
  robots: { index: true, follow: true },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="sk" className={`dark ${inter.variable} ${playfair.variable}`}>
      <body className={`font-sans antialiased bg-[#050505] text-[#F5F5F5] selection:bg-[#D4AF37]/30 selection:text-white`}>
        <PostHogProvider>
          {children}
        </PostHogProvider>
        <Analytics />
      </body>
    </html>
  )
}
