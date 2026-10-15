'use client'

import { QRCodeSVG } from 'qrcode.react'
import { APP_STORE_PATH, SITE_URL } from '@/lib/site'
import AppStoreButton from './AppStoreButton'

export default function DownloadCTA() {
  return (
    <section id="stiahnut" className="px-4 pb-24 sm:px-6 sm:pb-32">
      <div className="landing-glow mx-auto flex max-w-6xl flex-col items-center gap-10 rounded-[2.5rem] border border-white/10 px-6 py-16 text-center sm:py-20 lg:flex-row lg:justify-between lg:px-16 lg:text-left">
        <div className="max-w-xl">
          <h2 className="font-serif text-4xl font-bold tracking-tight text-white sm:text-5xl">Ďalší tréning už s Encore.</h2>
          <p className="mt-4 text-lg text-white/70">Zadarmo pre iPhone. Účet si vytvoríš za minútu cez e-mail, Google alebo Apple.</p>
          <div className="mt-8 flex justify-center lg:justify-start">
            <AppStoreButton />
          </div>
        </div>
        <div className="hidden flex-col items-center gap-3 lg:flex">
          <div className="rounded-2xl bg-white p-4">
            <QRCodeSVG value={`${SITE_URL}${APP_STORE_PATH}`} size={132} level="M" />
          </div>
          <p className="text-sm text-white/60">Naskenuj fotoaparátom iPhonu</p>
        </div>
      </div>
    </section>
  )
}
