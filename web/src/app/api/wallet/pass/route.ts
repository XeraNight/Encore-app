import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { PKPass, PassType } from 'passkit-generator'
import fs from 'fs'
import path from 'path'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

// MARK: - Apple Wallet Native .pkpass Generator Endpoint
// Generates a cryptographically signed Apple Wallet pass bundle (.pkpass)
// barcode = https://www.encore-sk.com/add/[invite_code]
export async function GET(request: NextRequest) {
  try {
    const authHeader = request.headers.get('Authorization')
    const token = authHeader?.replace(/^Bearer\s+/i, '') || new URL(request.url).searchParams.get('token')

    if (!token) {
      return NextResponse.json(
        { error: 'unauthorized', message: 'Vyžaduje sa prihlásenie (Supabase JWT token).' },
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

    // Fetch user profile & invite code
    const { data: profile } = await supabase
      .from('profiles')
      .select('id, name, invite_code, club, card_theme, dancer_code')
      .eq('id', user.id)
      .single()

    const userName = profile?.name || user.user_metadata?.full_name || 'Tanečník'
    // No made-up club: without one the pass simply says it is a member card.
    const userClub: string | null = profile?.club || user.user_metadata?.club || null
    const inviteCode = profile?.invite_code || user.id.substring(0, 8).toUpperCase()
    // The pass lives for years: always the real domain (the app's universal links), never an env leftover.
    const domain = 'www.encore-sk.com'
    const qrInviteUrl = `https://${domain}/add/${inviteCode}`

    const passCertB64 = process.env.APPLE_PASS_CERT_BASE64
    const passKeyB64 = process.env.APPLE_PASS_KEY_BASE64
    const wwdrCertB64 = process.env.APPLE_WWDR_CERT_BASE64
    const passTypeIdentifier = process.env.APPLE_PASS_TYPE_IDENTIFIER || 'pass.com.jakub.encore'
    const teamIdentifier = process.env.APPLE_TEAM_IDENTIFIER || '2MD5BS4DLM'

    // If Apple certificates are not yet configured in environment variables, return clear diagnostic
    if (!passCertB64 || !passKeyB64 || !wwdrCertB64) {
      return NextResponse.json(
        {
          error: 'certificates_missing',
          message: 'Apple PassKit certifikáty zatiaľ nie sú nahrané v prostredí Vercel. Karta sa vygeneruje po nahraní Base64 certifikátov.',
          passTypeIdentifier,
          teamIdentifier,
          invite_code: inviteCode,
          qr_url: qrInviteUrl,
          user: {
            id: user.id,
            name: userName,
            club: userClub
          }
        },
        { status: 503 }
      )
    }

    // Certificates and key: base64 of the .pem file, or the .pem text itself. A wrong value is named
    // (never shown), so it can be fixed in Vercel.
    const signerCert = pemFrom(passCertB64, /-----BEGIN CERTIFICATE-----/)
    const signerKey = pemFrom(passKeyB64, /-----BEGIN (RSA |ENCRYPTED )?PRIVATE KEY-----/)
    const wwdr = pemFrom(wwdrCertB64, /-----BEGIN CERTIFICATE-----/)
    const invalid = [
      signerCert ? null : 'APPLE_PASS_CERT_BASE64',
      signerKey ? null : 'APPLE_PASS_KEY_BASE64',
      wwdr ? null : 'APPLE_WWDR_CERT_BASE64',
    ].filter(Boolean)
    if (!signerCert || !signerKey || !wwdr) {
      return NextResponse.json(
        {
          error: 'pass_config_invalid',
          message: `Vo Verceli nie je platná hodnota: ${invalid.join(', ')}. Vlož výstup príkazu base64 -i <súbor.pem> | pbcopy.`,
        },
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
        value: 'Motív zmeníš v Encore v Profil → Vzhľad. Potom kartu pridaj do Peňaženky znova.'
      },
      { key: 'website', label: 'Web', value: `https://${domain}` }
    ]

    // iOS 27+: Poster Generic, the card's leather with the emblem in a gold sunburst above the QR code
    // (background image). Only the name as the bold title (a primary field without a label) and the club
    // in the footer, so the leather stays visible.
    const poster = new PassType('posterGeneric')
    poster.headerFields.push({ key: 'dancer', label: 'ID TANEČNÍKA', value: dancerId })
    poster.primaryFields.push({ key: 'member', value: userName })
    poster.footerFields.push({ key: 'club', value: userClub ?? 'Členská karta' })
    poster.backFields.push(...backFields)

    // iOS 26 and earlier: store card with the leather strip. No primary field there: Wallet would print it
    // large across the strip, over the emblem.
    const storeCard = new PassType('storeCard')
    storeCard.headerFields.push({ key: 'dancer', label: 'ID TANEČNÍKA', value: dancerId })
    storeCard.secondaryFields.push({ key: 'member', label: 'TANEČNÍK', value: userName })
    if (userClub) storeCard.secondaryFields.push({ key: 'club', label: 'TANEČNÝ KLUB', value: userClub })
    storeCard.backFields.push(...backFields)

    // Wallet prefers posterGeneric where it knows it and falls back to the store card elsewhere.
    pass.types.push(poster, storeCard)

    // iOS 27: two actions under the pass, opening Encore (universal links, /quick/... in the app).
    pass.featuredActions = [
      { identifier: 'competitions', type: 'viewSchedule', url: `https://${domain}/quick/ksis` },
      { identifier: 'results', type: 'membershipBenefits', url: `https://${domain}/quick/results` }
    ]

    // Icon from the public folder; the logo is the emblem with the ENCORE wordmark (public/wallet), the
    // same picture as the poster's primary logo, so no logo text is needed next to it.
    const publicDir = path.join(process.cwd(), 'public')
    const iconPath = path.join(publicDir, 'logo.png')

    if (fs.existsSync(iconPath)) {
      const iconBuf = fs.readFileSync(iconPath)
      pass.addBuffer('icon.png', iconBuf)
      pass.addBuffer('icon@2x.png', iconBuf)
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
        const artPath = path.join(publicDir, 'wallet', `${source}${scale}.png`)
        if (fs.existsSync(artPath)) pass.addBuffer(`${name}${scale}.png`, fs.readFileSync(artPath))
      }
    }
    for (const scale of ['', '@2x', '@3x']) {
      const logoArt = path.join(publicDir, 'wallet', `primaryLogo${scale}.png`)
      if (!fs.existsSync(logoArt)) continue
      const logoBuf = fs.readFileSync(logoArt)
      pass.addBuffer(`primaryLogo${scale}.png`, logoBuf)
      pass.addBuffer(`logo${scale}.png`, logoBuf)
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
  } catch (error: any) {
    console.error('Apple Wallet pass generation error:', error)
    return NextResponse.json(
      { error: 'pass_generation_failed', message: error.message || 'Nepodarilo sa vygenerovať Apple Wallet preukaz.' },
      { status: 500 }
    )
  }
}

/** Themes that have strip images in public/wallet (Profil → Vzhľad in the app). */
const STRIP_THEMES = ['carmine', 'obsidian', 'midnight', 'emerald', 'mahogany']

/** The PEM text from an env value that holds either base64 of the .pem file or the text itself. */
function pemFrom(value: string, header: RegExp): string | null {
  const text = value.includes('-----BEGIN')
    ? value.replace(/\\n/g, '\n')
    : Buffer.from(value.replace(/\s/g, ''), 'base64').toString('utf-8')
  return header.test(text) ? text : null
}

/** Only a plain "rgb(r, g, b)" from the profile reaches the pass; anything else falls back. */
function rgbOr(value: unknown, fallback: string): string {
  return typeof value === 'string' && /^rgb\(\d{1,3}, ?\d{1,3}, ?\d{1,3}\)$/.test(value) ? value : fallback
}
