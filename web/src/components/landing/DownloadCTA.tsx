'use client'

import { QRCodeSVG } from 'qrcode.react'
import { APP_STORE_PATH, SITE_URL } from '@/lib/site'
import AppStoreButton from './AppStoreButton'

export default function DownloadCTA() {
  return (
    <section id="stiahnut" className="px-5 py-24 sm:px-6 sm:py-28">
      <div className="landing-glow mx-auto flex max-w-6xl flex-col items-center gap-10 rounded-[20px] border border-[#FFE088]/30 bg-white/[0.07] px-6 py-14 text-center sm:py-16 lg:flex-row lg:justify-between lg:px-14 lg:text-left">
        <div className="max-w-xl">
          <p className="font-rounded text-xs font-black uppercase tracking-[0.16em] text-[#FFE088]">STIAHNUŤ PRE IPHONE</p>
          <h2 className="font-rounded mt-3 text-3xl font-black tracking-tight text-white sm:text-5xl">
            Ďalší tréning už s Encore.
          </h2>
          <p className="mt-4 text-lg text-white/75">
            Zadarmo pre iPhone. Účet si vytvoríš za minútu cez e-mail, Google alebo Apple.
          </p>
          <div className="mt-8 flex justify-center lg:justify-start">
            <AppStoreButton />
          </div>
        </div>
        <div className="hidden flex-col items-center gap-3 lg:flex">
          <div className="rounded-[16px] border border-[#FFE088]/40 bg-white p-4 shadow-lg">
            <QRCodeSVG value={`${SITE_URL}${APP_STORE_PATH}`} size={132} level="M" />
          </div>
          <p className="font-rounded text-xs font-bold uppercase tracking-wider text-white/75">
            Naskenuj fotoaparátom iPhonu
          </p>
        </div>
      </div>
    </section>
  )
}
