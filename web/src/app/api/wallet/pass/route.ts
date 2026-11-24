import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { PKPass, PassType } from 'passkit-generator'
import fs from 'fs'
import path from 'path'
import { checkRateLimit } from '@/lib/rate-limit'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

// MARK: - Apple Wallet Native .pkpass Generator Endpoint
// Generates a cryptographically signed Apple Wallet pass bundle (.pkpass)
// barcode = https://www.encore-sk.com/add?t=[the dancer's current invite token], the same QR as in the app
export async function GET(request: NextRequest) {
  try {
    // Only the Authorization header: a token in the address would end up in access logs.
    const token = request.headers.get('Authorization')?.replace(/^Bearer\s+/i, '')

    if (!token) {
      return NextResponse.json(
        { error: 'unauthorized', message: 'Vyžaduje sa prihlásenie.' },
        { status: 401 }
      )
    }

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://iukblwlttvrcdclmlyxu.supabase.co'
    const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ''
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: `Bearer ${token}`
        }
      }
    })

    // Verify authenticated user
    const { data: userData, error: userError } = await supabase.auth.getUser(token)
    if (userError || !userData?.user) {
      return NextResponse.json(
        { error: 'invalid_token', message: 'Neplatné alebo expirované prihlásenie.' },
        { status: 401 }
      )
    }

    const user = userData.user

    // Prevent CPU exhaustion via repeated PKCS#7 signing
    const limit = checkRateLimit(`wallet:${user.id}`, 10, 60 * 60 * 1000)
    if (!limit.allowed) {
      return NextResponse.json(
        { error: 'rate_limited', message: 'Karta sa nedá generovať tak často. Skús to prosím neskôr.' },
        { status: 429, headers: { 'Retry-After': String(limit.retryAfterSeconds) } }
      )
    }

    // Everything the card shows, asked for at once: the profile, the KSIS number the dancer picked, the classes of the
    // current couple and the current invite token. Row level security hands each user only their own.
    const [{ data: profile, error: profileError }, { data: ksisDancer }, { data: couple }, { data: activeToken }] = await Promise.all([
      supabase
        .from('profiles')
        .select('id, name, invite_code, club, card_theme, dancer_code, account_status')
        .eq('id', user.id)
        .single(),
      supabase.from('ksis_dancers').select('person_number').eq('user_id', user.id).maybeSingle(),
      supabase.from('user_couples').select('stt_class, lat_class').eq('user_id', user.id).eq('is_current', true).maybeSingle(),
      supabase
        .from('invite_tokens')
        .select('token')
        .eq('user_id', user.id)
        .is('revoked_at', null)
        .gt('expires_at', new Date().toISOString())
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle(),
    ])

    if (profileError || !profile) {
      return NextResponse.json(
        { error: 'profile_not_found', message: 'Profil tanečníka sa nenašiel.' },
        { status: 404 }
      )
    }

    if (profile.account_status && profile.account_status !== 'active') {
      return NextResponse.json(
        { error: 'account_restricted', message: 'Účet nemá oprávnenie generovať kartu.' },
        { status: 403 }
      )
    }

    const userName = profile.name || user.user_metadata?.full_name || 'Tanečník'
    // No made-up club: without one the pass simply says it is a member card.
    const userClub: string | null = profile.club || user.user_metadata?.club || null
    const rawInviteCode = profile.invite_code || user.id.substring(0, 8).toUpperCase()
    const inviteCode = rawInviteCode.replace(/[^A-Z0-9-]/gi, '') || 'PASS'
    // The pass lives for years: always the real domain (the app's universal links), never an env leftover.
    const domain = 'www.encore-sk.com'
    // The QR code is the dancer's current invite token, the same one the card in Encore shows (random,
    // 30 days, revoked by "Nový QR"). The app makes sure one exists before it asks and swaps the Wallet card
    // when it changes. Without a token: the dancer code link, as in the app.
    const qrInviteUrl = activeToken?.token
      ? `https://${domain}/add?t=${encodeURIComponent(activeToken.token)}`
      : `https://${domain}/add${profile.dancer_code ? `/${encodeURIComponent(profile.dancer_code)}` : ''}`

    const passCertB64 = process.env.APPLE_PASS_CERT_BASE64
    const passKeyB64 = process.env.APPLE_PASS_KEY_BASE64
    const wwdrCertB64 = process.env.APPLE_WWDR_CERT_BASE64
    const passTypeIdentifier = process.env.APPLE_PASS_TYPE_IDENTIFIER || 'pass.com.jakub.encore'
    const teamIdentifier = process.env.APPLE_TEAM_IDENTIFIER || '2MD5BS4DLM'

    if (!passCertB64 || !passKeyB64 || !wwdrCertB64) {
      console.error('Apple Wallet pass generation: missing Apple PassKit env certificates')
      return NextResponse.json(
        { error: 'service_unavailable', message: 'Generovanie Apple Wallet karty je momentálne nedostupné.' },
        { status: 503 }
      )
    }

    const signerCert = pemFrom(passCertB64, /-----BEGIN CERTIFICATE-----/)
    const signerKey = pemFrom(passKeyB64, /-----BEGIN (RSA |ENCRYPTED )?PRIVATE KEY-----/)
    const wwdr = pemFrom(wwdrCertB64, /-----BEGIN CERTIFICATE-----/)
    if (!signerCert || !signerKey || !wwdr) {
      console.error('Apple Wallet pass generation: invalid PEM format in certificate env vars')
      return NextResponse.json(
        { error: 'pass_config_invalid', message: 'Generovanie Apple Wallet karty zlyhalo. Skús to prosím neskôr.' },
        { status: 500 }
      )
    }
    const signerKeyPassphrase = process.env.APPLE_PASS_PASSPHRASE || undefined

    // Instantiate PKPass generator
    const pass = new PKPass(
      {},
      {
        signerCert,
        signerKey,
        signerKeyPassphrase,
        wwdr
      },
      {
        passTypeIdentifier,
        teamIdentifier,
        organizationName: 'Encore',
        description: 'Členská karta Encore',
        serialNumber: `ENC-${inviteCode}`,
        // The card theme chosen in the app (Profil → Vzhľad); Karmín when there is none.
        foregroundColor: rgbOr(profile?.card_theme?.foreground_color, 'rgb(255, 230, 153)'),
        backgroundColor: rgbOr(profile?.card_theme?.background_color, 'rgb(102, 3, 18)'),
        labelColor: rgbOr(profile?.card_theme?.label_color, 'rgb(212, 175, 55)')
      }
    )

    pass.setBarcodes({
      format: 'PKBarcodeFormatQR',
      message: qrInviteUrl,
      messageEncoding: 'iso-8859-1',
      altText: 'Naskenuj a prepoj sa v Encore'
    })

    const dancerId = profile?.dancer_code || inviteCode
    // The two facts the card in Encore shows besides the name and the club, written the same way: the KSIS number the
    // dancer picked, and the classes of the current couple ("ŠTT D · LAT D").
    const facts: { key: string; label: string; value: string }[] = []
    if (ksisDancer?.person_number) facts.push({ key: 'ksis', label: 'KSIS Č.', value: String(ksisDancer.person_number) })
    const classes = [couple?.stt_class && `ŠTT ${couple.stt_class}`, couple?.lat_class && `LAT ${couple.lat_class}`]
      .filter(Boolean)
      .join(' · ')
    if (classes) facts.push({ key: 'classes', label: 'TRIEDY', value: classes })

    const backFields = [
      {
        key: 'about',
        label: 'Encore',
        value: 'Tréningový denník pre tanečníkov a páry štandardných a latinskoamerických tancov.'
      },
      {
        key: 'connect',
        label: 'Prepojenie',
        value: `Partner naskenuje QR kód a pošle ti žiadosť o prepojenie: ${qrInviteUrl}`
      },
      {
        key: 'theme',
        label: 'Vzhľad karty',
        value: 'Motív zmeníš v Encore v Profil → Vzhľad. Potom pri karte v Encore ťukni na ↻ a karta v Peňaženke sa aktualizuje.'
      },
      { key: 'website', label: 'Web', value: `https://${domain}` }
    ]

    // iOS 27+: Poster Generic, the card's leather with the emblem in a gold sunburst above the QR code
    // (background image). The name as the bold title (a primary field without a label), the club in the footer and
    // the KSIS facts as secondary fields, as in the app.
    const poster = new PassType('posterGeneric')
    poster.headerFields.push({ key: 'dancer', label: 'ID TANEČNÍKA', value: dancerId })
    poster.primaryFields.push({ key: 'member', value: userName })
    poster.secondaryFields.push(...facts)
    poster.footerFields.push({ key: 'club', value: userClub ?? 'Členská karta' })
    poster.backFields.push(...backFields)

    // iOS 26 and earlier: store card with the leather strip. No primary field there: Wallet would print it
    // large across the strip, over the emblem. The names of the fields are the ones on the card in the app.
    const storeCard = new PassType('storeCard')
    storeCard.headerFields.push({ key: 'dancer', label: 'ID TANEČNÍKA', value: dancerId })
    storeCard.secondaryFields.push({ key: 'member', label: 'TANEČNÍK', value: userName })
    if (userClub) storeCard.secondaryFields.push({ key: 'club', label: 'KLUB', value: userClub })
    storeCard.auxiliaryFields.push(...facts)
    storeCard.backFields.push(...backFields)

    // Wallet prefers posterGeneric where it knows it and falls back to the store card elsewhere.
    pass.types.push(poster, storeCard)

    // iOS 27: two actions under the pass, opening Encore (universal links, /quick/... in the app).
    pass.featuredActions = [
      { identifier: 'competitions', type: 'viewSchedule', url: `https://${domain}/quick/ksis` },
      { identifier: 'results', type: 'membershipBenefits', url: `https://${domain}/quick/results` }
    ]

    // Icon from the public folder. No logo: the older store card stays clean at the top left (the emblem is
    // in its strip) and the poster shows its own primary logo.
    const publicDir = path.join(process.cwd(), 'public')
    const icon = readAsset(path.join(publicDir, 'logo.png'))
    if (icon) {
      pass.addBuffer('icon.png', icon)
      pass.addBuffer('icon@2x.png', icon)
    }

    // Art of the chosen theme, rendered from the app's card leather (public/wallet): the poster
    // background (iOS 27) and the strip (older iOS). @2x and @3x only, which every current iPhone uses.
    const themeId = STRIP_THEMES.includes(profile?.card_theme?.theme_id) ? profile?.card_theme?.theme_id : 'carmine'
    const art: [string, string][] = [
      [`background-${themeId}`, 'background'],
      [`strip-${themeId}`, 'strip'],
    ]
    for (const [source, name] of art) {
      for (const scale of ['@2x', '@3x']) {
        const buffer = readAsset(path.join(publicDir, 'wallet', `${source}${scale}.png`))
        if (buffer) pass.addBuffer(`${name}${scale}.png`, buffer)
      }
    }
    for (const scale of ['', '@2x', '@3x']) {
      const buffer = readAsset(path.join(publicDir, 'wallet', `primaryLogo${scale}.png`))
      if (buffer) pass.addBuffer(`primaryLogo${scale}.png`, buffer)
    }

    // Generate signed .pkpass binary buffer
    const passBuffer = await pass.getAsBuffer()

    return new NextResponse(passBuffer as unknown as BodyInit, {
      status: 200,
      headers: {
        'Content-Type': 'application/vnd.apple.pkpass',
        'Content-Disposition': `attachment; filename="encore-${inviteCode}.pkpass"`,
        'Cache-Control': 'no-cache, no-store, must-revalidate'
      }
    })
  } catch (error) {
    console.error('Apple Wallet pass generation error:', error)
    return NextResponse.json(
      { error: 'pass_generation_failed', message: 'Nepodarilo sa vygenerovať Apple Wallet kartu.' },
      { status: 500 }
    )
  }
}

/** Themes that have strip images in public/wallet (Profil → Vzhľad in the app). */
const STRIP_THEMES = ['carmine', 'obsidian', 'midnight', 'emerald', 'mahogany']

/** The pass art never changes while the server runs: each file is read once, not on every request. */
const assetCache = new Map<string, Buffer | null>()
function readAsset(file: string): Buffer | null {
  if (!assetCache.has(file)) {
    try {
      assetCache.set(file, fs.readFileSync(file))
    } catch {
      assetCache.set(file, null)
    }
  }
  return assetCache.get(file) ?? null
}

/** The PEM text from an env value that holds either base64 of the .pem file or the text itself. */
function pemFrom(value: string, header: RegExp): string | null {
  const text = value.includes('-----BEGIN')
    ? value.replace(/\\n/g, '\n')
    : Buffer.from(value.replace(/\s/g, ''), 'base64').toString('utf-8')
  return header.test(text) ? text : null
}

/** Only a valid "rgb(0..255, 0..255, 0..255)" from the profile reaches the pass; anything else falls back. */
function rgbOr(value: unknown, fallback: string): string {
  if (typeof value !== 'string') return fallback
  const match = /^rgb\((\d{1,3}), ?(\d{1,3}), ?(\d{1,3})\)$/.exec(value)
  if (!match) return fallback
  const channels = [Number(match[1]), Number(match[2]), Number(match[3])]
  return channels.every((c) => c >= 0 && c <= 255) ? `rgb(${channels.join(', ')})` : fallback
}
