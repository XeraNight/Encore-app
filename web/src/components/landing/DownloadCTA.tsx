'use client'

import React from 'react'
import Link from 'next/link'
import { QRCodeSVG } from 'qrcode.react'

export default function DownloadCTA() {
  const qrUrl = 'https://www.encore-sk.com/download/ios'

  return (
    <section id="download" className="py-20 relative z-10 max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
      <div className="rounded-[36px] p-8 sm:p-14 bg-[#1E0409]/90 border border-white/10 backdrop-blur-2xl shadow-[0_20px_80px_rgba(0,0,0,0.9)] relative overflow-hidden flex flex-col md:flex-row items-center justify-between gap-10">

        {/* Text & Badges */}
        <div className="space-y-6 max-w-lg text-center md:text-left z-10">
          <span className="text-xs font-sans font-black tracking-[0.2em] uppercase text-[#FFE088] block">
            ZAČNI EŠTE DNES
          </span>
          <h2 className="text-3xl sm:text-5xl font-serif font-black tracking-tight text-white leading-tight">
            Tvoj tanečný svet v jednej aplikácii
          </h2>
          <p className="text-sm sm:text-base text-zinc-300">
            Dostupné pre iPhone, iPad a Android zariadenia (smartfóny a tablety). Vyvinuté špeciálne pre dynamické použitie priamo na tanečnej sále.
          </p>

          {/* Store Buttons */}
          <div className="flex flex-wrap items-center justify-center md:justify-start gap-4 pt-2">
            
            {/* App Store Button */}
            <Link
              href="/download/ios"
              className="btn-discord-pill group px-6 py-3.5 bg-white text-black font-bold text-xs flex items-center gap-3 shadow-xl hover:bg-zinc-100 hover:shadow-[0_10px_25px_rgba(255,255,255,0.25)]"
            >
              <svg className="w-6 h-6 fill-current group-hover:scale-105 transition-transform" viewBox="0 0 24 24">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.61-.75 1.04-1.8 1.01-2.87-.96.04-2.09.64-2.74 1.4-.57.65-1.06 1.73-.93 2.76 1.07.08 2.06-.54 2.66-1.29z" />
              </svg>
              <div className="text-left">
                <span className="text-[9px] block text-zinc-600 font-medium -mb-0.5">Pre iPhone & iPad</span>
                <span className="text-sm font-black flex items-center gap-1">
                  App Store
                  <span className="text-xs group-hover:translate-x-1 transition-transform inline-block">→</span>
                </span>
              </div>
            </Link>

            {/* Google Play Button */}
            <Link
              href="/download/android"
              className="btn-discord-pill group px-6 py-3.5 bg-[#121216] border border-[#FFE088]/30 text-white font-bold text-xs flex items-center gap-3 shadow-xl hover:border-[#FFE088]/70 hover:shadow-[0_10px_25px_rgba(212,175,55,0.2)]"
            >
              <svg className="w-5 h-5 fill-current text-[#FFE088] group-hover:scale-105 transition-transform" viewBox="0 0 24 24">
                <path d="M3.609 1.814L13.793 12 3.61 22.186c-.352-.361-.568-.89-.568-1.503V3.317c0-.613.216-1.142.567-1.503zm11.24 11.24l2.127 2.127-11.458 6.55 9.331-8.677zm0-2.108L5.518 2.27l11.459 6.549-2.128 2.127zm1.488 1.054l3.189 1.822c.947.541.947 1.427 0 1.968l-3.189 1.822-2.316-2.316 2.316-2.296z" />
              </svg>
              <div className="text-left">
                <span className="text-[9px] block text-zinc-400 font-medium -mb-0.5">Pre Android mobily & tablety</span>
                <span className="text-sm font-black flex items-center gap-1">
                  Google Play
                  <span className="text-xs text-[#FFE088] group-hover:translate-x-1 transition-transform inline-block">→</span>
                </span>
              </div>
            </Link>

          </div>
        </div>

        {/* QR Code Container */}
        <div className="flex flex-col items-center gap-3 p-6 rounded-3xl bg-[#0A0A0A] border border-[#FFE088]/30 shadow-2xl backdrop-blur-xl shrink-0 z-10">
          <div className="bg-white p-3 rounded-2xl shadow-lg">
            <QRCodeSVG
              value={qrUrl}
              size={140}
              bgColor="#ffffff"
              fgColor="#000000"
              level="M"
            />
          </div>
          <div className="text-center">
            <span className="text-[11px] font-bold text-[#FFE088] uppercase tracking-wider block">
              Naskenujte iPhonom
            </span>
            <span className="text-[9px] text-zinc-400">
              Priame otvorenie v App Store
            </span>
          </div>
        </div>

      </div>
    </section>
  )
}
