'use client'

import React, { useState, useEffect } from 'react'
import Image from 'next/image'
import { QRCodeSVG } from 'qrcode.react'

interface InviterProps {
  code: string
  name: string
  club: string
  avatarUrl: string | null
}

interface AddFriendClientViewProps {
  inviter: InviterProps
  appStoreUrl: string
  fullInviteUrl: string
}

export default function AddFriendClientView({
  inviter,
  appStoreUrl,
  fullInviteUrl
}: AddFriendClientViewProps) {
  const [isIOS, setIsIOS] = useState(false)
  const [copied, setCopied] = useState(false)
  const [redirecting, setRedirecting] = useState(false)

  useEffect(() => {
    const ua = navigator.userAgent || ''
    const isAppleDevice = /iPhone|iPad|iPod/i.test(ua)
    setIsIOS(isAppleDevice)
  }, [])

  const copyToClipboard = async (text: string) => {
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(text)
        return true
      }
    } catch {
      // Fallback below
    }

    try {
      const textArea = document.createElement('textarea')
      textArea.value = text
      textArea.style.position = 'fixed'
      textArea.style.opacity = '0'
      document.body.appendChild(textArea)
      textArea.focus()
      textArea.select()
      const successful = document.execCommand('copy')
      document.body.removeChild(textArea)
      return successful
    } catch {
      return false
    }
  }

  const handleDownloadTap = async () => {
    setCopied(true)
    setRedirecting(true)

    // 1. Copy the full invite URL to clipboard for deferred deep linking
    await copyToClipboard(fullInviteUrl)

    // 2. Short timeout for user feedback, then redirect to App Store
    setTimeout(() => {
      window.location.href = appStoreUrl
    }, 450)
  }

  return (
    <main className="min-h-screen bg-[#070709] text-white flex flex-col items-center justify-center p-4 selection:bg-[#D4AF37] selection:text-black">
      {/* Ambient Crimson & Wine Radial Lighting */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden">
        <div className="absolute top-1/4 left-1/2 -translate-x-1/2 w-[520px] h-[360px] bg-[#9E081A] opacity-25 blur-[130px] rounded-full" />
        <div className="absolute bottom-1/4 right-1/4 w-[360px] h-[280px] bg-[#D4AF37] opacity-10 blur-[140px] rounded-full" />
      </div>

      <div className="relative z-10 w-full max-w-md flex flex-col items-center gap-6">
        {/* Header Branding */}
        <div className="flex flex-col items-center text-center gap-1.5">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#D4AF37]/10 border border-[#D4AF37]/25 text-[11px] font-black tracking-[0.2em] text-[#D4AF37] uppercase">
            <span>Encore Tanečné Spojenie</span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-serif font-black tracking-tight mt-2">
            Pozvánka od {inviter.name}
          </h1>
          <p className="text-xs text-stone-400 max-w-xs">
            Pridaj sa do Encore a spoj sa s tanečníkmi z tvojho klubu a parketu.
          </p>
        </div>

        {/* Luxury Member Card Preview */}
        <div
          className="w-full aspect-[1.72] rounded-2xl p-6 relative overflow-hidden shadow-2xl border border-[#D4AF37]/40 flex flex-col justify-between"
          style={{
            background: 'linear-gradient(135deg, #850D1C 0%, #590512 48%, #33030A 100%)',
            boxShadow: '0 25px 50px -12px rgba(133, 13, 28, 0.45), 0 0 25px rgba(212, 175, 55, 0.2)'
          }}
        >
          {/* Subtle perimeter stitching emulation */}
          <div className="absolute inset-2.5 rounded-xl border border-dashed border-[#D4AF37]/35 pointer-events-none" />

          {/* Top Row: Club & QR */}
          <div className="flex justify-between items-start relative z-10">
            <div>
              <span className="text-[10px] font-bold tracking-widest text-[#D4AF37]/80 uppercase block">
                Tanečný Klub
              </span>
              <span className="text-sm font-serif font-bold text-white">
                {inviter.club || 'Individuálny'}
              </span>
            </div>

            <div className="bg-white p-1 rounded-md shadow-md">
              <QRCodeSVG
                value={fullInviteUrl}
                size={44}
                bgColor="#ffffff"
                fgColor="#000000"
                level="M"
              />
            </div>
          </div>

          {/* Center: Monogram Logo */}
          <div className="absolute inset-0 flex items-center justify-center pointer-events-none opacity-85">
            <div className="relative w-16 h-16">
              <Image
                src="/encore_logo.png"
                alt="Encore"
                fill
                sizes="64px"
                className="object-contain drop-shadow-[0_4px_12px_rgba(0,0,0,0.6)]"
              />
            </div>
          </div>

          {/* Bottom Row: Dancer Name & Invite Code */}
          <div className="flex justify-between items-end relative z-10">
            <div>
              <span className="text-[9px] font-bold tracking-wider text-[#D4AF37]/75 uppercase block">
                Tanečník
              </span>
              <span className="text-lg font-serif font-black text-white">
                {inviter.name}
              </span>
            </div>

            <div className="text-right">
              <span className="text-[8px] font-mono font-semibold tracking-wider text-stone-400 block">
                KÓD: {inviter.code}
              </span>
              <span className="inline-flex items-center gap-1 text-[8px] font-bold text-[#D4AF37]">
                <span className="w-1.5 h-1.5 rounded-full bg-[#D4AF37]" />
                WALLET READY
              </span>
            </div>
          </div>
        </div>

        {/* Primary Action Button */}
        <div className="w-full flex flex-col gap-3">
          <button
            onClick={handleDownloadTap}
            disabled={redirecting}
            className="w-full py-4 px-6 rounded-2xl bg-gradient-to-r from-[#F7E59D] via-[#D4AF37] to-[#AA771C] text-black font-bold text-sm tracking-wide shadow-lg shadow-[#D4AF37]/20 hover:brightness-105 active:scale-[0.99] transition-all flex items-center justify-center gap-2 cursor-pointer disabled:opacity-75"
          >
            {redirecting ? (
              <span>Pripravujem pozvánku & App Store...</span>
            ) : (
              <>
                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.85c.66-.8 1.11-1.92.99-3.04-.96.04-2.12.64-2.8 1.44-.59.69-1.12 1.83-.98 2.92 1.07.08 2.13-.52 2.79-1.32z" />
                </svg>
                <span>Stiahnuť Encore a prijať pozvánku</span>
              </>
            )}
          </button>

          {copied && (
            <p className="text-center text-xs text-[#D4AF37] animate-pulse">
              Pozvánka skopírovaná do schránky! Po otvorení Encore sa automaticky prepojí.
            </p>
          )}

          {/* Desktop Fallback Instruction */}
          {!isIOS && (
            <div className="mt-4 p-4 rounded-xl bg-stone-900/60 border border-stone-800 text-center flex flex-col items-center gap-2">
              <span className="text-xs text-stone-300 font-medium">
                Používaš počítač? Naskenuj QR kód fotoaparátom iPhonu:
              </span>
              <div className="bg-white p-2 rounded-lg shadow-md mt-1">
                <QRCodeSVG
                  value={fullInviteUrl}
                  size={120}
                  bgColor="#ffffff"
                  fgColor="#000000"
                  level="M"
                />
              </div>
              <span className="text-[10px] text-stone-400 font-mono mt-1">
                Kód pozvánky: {inviter.code}
              </span>
            </div>
          )}
        </div>
      </div>
    </main>
  )
}
