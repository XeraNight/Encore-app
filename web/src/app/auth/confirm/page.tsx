'use client'

import React, { useEffect, useState, Suspense } from 'react'
import Image from 'next/image'
import Link from 'next/link'
import { useSearchParams } from 'next/navigation'
import { APP_STORE_PATH } from '@/lib/site'

function AuthConfirmContent() {
  const searchParams = useSearchParams()
  const [isIOS, setIsIOS] = useState(false)

  const errorParam = searchParams.get('error')
  const rawType = searchParams.get('type') || 'login'
  const type = rawType === 'recovery' ? 'recovery' : 'login'
  const hasError = Boolean(errorParam)

  const appSchemeUrl = `encore://auth-callback?type=${encodeURIComponent(type)}`

  useEffect(() => {
    if (hasError) return
    const ua = navigator.userAgent || ''
    const isApple = /iPhone|iPad|iPod/i.test(ua)
    setIsIOS(isApple)

    if (isApple) {
      const timer = setTimeout(() => {
        window.location.href = appSchemeUrl
      }, 500)
      return () => clearTimeout(timer)
    }
  }, [appSchemeUrl, hasError])

  if (hasError) {
    return (
      <div className="relative z-10 flex w-full max-w-md flex-col items-center gap-6 rounded-[20px] border border-white/10 bg-white/[0.07] p-8 text-center shadow-2xl backdrop-blur-xl">
        <div className="relative h-16 w-16">
          <Image src="/logo_mark.svg" alt="Encore" fill className="object-contain" priority />
        </div>
        <div className="space-y-2">
          <p className="font-rounded text-xs font-black uppercase tracking-[0.16em] text-[#FFE088]">
            OVERENIE ÚČTU
          </p>
          <h1 className="font-rounded text-2xl font-black tracking-tight text-white">
            Odkaz vypršal alebo bol použitý
          </h1>
          <p className="text-sm leading-relaxed text-white/75">
            Tento overovací odkaz už nie je platný. Otvor aplikáciu Encore na iPhone a nechaj si poslať nový 6-miestny kód.
          </p>
        </div>
        <div className="mt-2 flex w-full flex-col gap-3">
          <a href="encore://" className="encore-gold-btn w-full">
            Otvoriť Encore
          </a>
          <Link
            href="/support"
            className="inline-flex min-h-11 w-full items-center justify-center rounded-2xl border border-white/15 bg-white/[0.07] px-5 py-3 text-sm font-semibold text-white/85 transition hover:border-[#FFE088]/40 hover:text-white"
          >
            Potrebuješ pomoc?
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div className="relative z-10 flex w-full max-w-md flex-col items-center gap-6 rounded-[20px] border border-white/10 bg-white/[0.07] p-8 text-center shadow-2xl backdrop-blur-xl">
      <div className="relative h-16 w-16">
        <Image src="/logo_mark.svg" alt="Encore" fill className="object-contain" priority />
      </div>

      <div className="space-y-2">
        <p className="font-rounded text-xs font-black uppercase tracking-[0.16em] text-[#FFE088]">
          AUTENTIFIKÁCIA ENCORE
        </p>
        <h1 className="font-rounded text-2xl font-black tracking-tight text-white sm:text-3xl">
          {type === 'recovery' ? 'Obnova hesla' : 'Účet je overený'}
        </h1>
        <p className="text-sm leading-relaxed text-white/75">
          {isIOS
            ? 'Tvoj účet je overený. Otvárame aplikáciu Encore...'
            : 'Tvoj účet je pripravený. Otvor aplikáciu Encore na svojom iPhone a pokračuj v tréningu.'}
        </p>
      </div>

      <div className="mt-2 flex w-full flex-col gap-3">
        <a href={appSchemeUrl} className="encore-gold-btn w-full">
          Otvoriť aplikáciu Encore
        </a>

        <Link
          href={APP_STORE_PATH}
          className="inline-flex min-h-11 w-full items-center justify-center rounded-2xl border border-white/15 bg-white/[0.07] px-5 py-3 text-sm font-semibold text-white/85 transition hover:border-[#FFE088]/40 hover:text-white"
        >
          Ešte nemáš aplikáciu? Stiahnuť v App Store
        </Link>
      </div>

      <div className="flex w-full justify-between border-t border-white/10 pt-4 text-xs text-white/60">
        <Link href="/" className="hover:text-[#FFE088] transition">
          ← Domov
        </Link>
        <Link href="/support" className="hover:text-[#FFE088] transition">
          Podpora
        </Link>
      </div>
    </div>
  )
}

export default function AuthConfirmPage() {
  return (
    <main className="relative flex min-h-screen flex-col items-center justify-center overflow-hidden bg-[#140206] p-5 text-[#F5F5F5]">
      <div
        aria-hidden
        className="pointer-events-none fixed inset-0 bg-[radial-gradient(75%_55%_at_50%_20%,rgba(154,13,31,0.44),rgba(120,5,20,0.22)_52%,transparent_80%),radial-gradient(50%_40%_at_82%_14%,rgba(212,175,55,0.08),transparent_70%)]"
      />
      <Suspense
        fallback={
          <div className="relative z-10 flex w-full max-w-md flex-col items-center justify-center rounded-[20px] border border-white/10 bg-white/[0.07] p-8 text-center backdrop-blur-xl">
            <p className="text-sm text-white/75">Overujem prihlásenie...</p>
          </div>
        }
      >
        <AuthConfirmContent />
      </Suspense>
    </main>
  )
}
