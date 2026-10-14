import type { Metadata } from 'next'
import { Inter, Playfair_Display } from 'next/font/google'
import './globals.css'
import { PostHogProvider } from '@/components/PostHogProvider'
import { Analytics } from '@vercel/analytics/next'

const inter = Inter({ subsets: ['latin'], display: 'swap', variable: '--font-sans' })
const playfair = Playfair_Display({ subsets: ['latin'], display: 'swap', variable: '--font-serif' })

export const metadata: Metadata = {
  title: {
    default: 'Encore — Umenie tanca. Dokonalosť tréningu.',
    template: '%s | Encore',
  },
  description: 'Prémiový digitálny asistent pre tanečné páry, trénerov a tanečníkov, ktorí chcú napredovať čo najrýchlejšie a najefektívnejšie.',
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
      <body className={`${inter.className} font-sans antialiased bg-[#050505] text-[#F5F5F5] selection:bg-[#D4AF37]/30 selection:text-white`}>
        <PostHogProvider>
          {children}
        </PostHogProvider>
        <Analytics />
      </body>
    </html>
  )
}
