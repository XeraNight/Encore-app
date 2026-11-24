import { NextRequest, NextResponse } from 'next/server'
import { checkRateLimit, getClientIp } from '@/lib/rate-limit'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

const ALLOWED_CATEGORIES = new Set(['bug', 'feature', 'account', 'other'])
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/

/**
 * Server-side proxy for the /support contact form.
 * Keeps the Formspree endpoint off the client bundle, enforces rate limits,
 * validates input length/format, checks a hidden honeypot field, and rejects
 * cross-site browser requests via Fetch Metadata.
 */
export async function POST(request: NextRequest) {
  const headers = {
    'Vary': 'Sec-Fetch-Dest, Sec-Fetch-Mode, Sec-Fetch-Site',
    'Cache-Control': 'no-store',
  }

  const fetchSite = request.headers.get('sec-fetch-site')
  if (fetchSite && !['same-origin', 'same-site', 'none'].includes(fetchSite)) {
    return NextResponse.json(
      { error: 'forbidden', message: 'Neoprávnená požiadavka.' },
      { status: 403, headers },
    )
  }

  const ip = getClientIp(request)
  const limit = checkRateLimit(`support:${ip}`, 5, 60 * 60 * 1000)
  if (!limit.allowed) {
    return NextResponse.json(
      {
        error: 'rate_limited',
        message: 'Poslal si priveľa správ za sebou. Skús to prosím znova o chvíľu alebo napíš priamo na support@encore-sk.com.',
      },
      {
        status: 429,
        headers: { ...headers, 'Retry-After': String(limit.retryAfterSeconds) },
      },
    )
  }

  let body: Record<string, unknown>
  try {
    const raw = await request.text()
    if (raw.length > 16_384) {
      return NextResponse.json(
        { error: 'payload_too_large', message: 'Správa je príliš dlhá.' },
        { status: 413, headers },
      )
    }
    body = JSON.parse(raw) as Record<string, unknown>
  } catch {
    return NextResponse.json(
      { error: 'invalid_json', message: 'Neplatný formát odoslanej správy.' },
      { status: 400, headers },
    )
  }

  // Accessible honeypot: real users never fill this field; silently pretend success for bots.
  const honeypot = typeof body._website === 'string' ? body._website.trim() : ''
  if (honeypot.length > 0) {
    return NextResponse.json({ ok: true }, { status: 200, headers })
  }

  const name = cleanText(body.name, 100)
  const email = cleanText(body.email, 160).toLowerCase()
  const category = typeof body.category === 'string' && ALLOWED_CATEGORIES.has(body.category) ? body.category : 'other'
  const message = cleanText(body.message, 3000)

  if (name.length < 2) {
    return NextResponse.json(
      { error: 'invalid_name', field: 'name', message: 'Zadaj prosím svoje meno (aspoň 2 znaky).' },
      { status: 400, headers },
    )
  }
  if (!EMAIL_RE.test(email)) {
    return NextResponse.json(
      { error: 'invalid_email', field: 'email', message: 'Zadaj prosím platnú e-mailovú adresu.' },
      { status: 400, headers },
    )
  }
  if (message.length < 10) {
    return NextResponse.json(
      { error: 'invalid_message', field: 'message', message: 'Napíš prosím aspoň pár slov (min. 10 znakov).' },
      { status: 400, headers },
    )
  }

  const formspreeEndpoint = process.env.FORMSPREE_ENDPOINT || 'https://formspree.io/f/myeyrbza'

  try {
    const upstream = await fetch(formspreeEndpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({ name, email, category, message }),
      signal: AbortSignal.timeout(8_000),
    })

    if (!upstream.ok) {
      console.error('Support form upstream error:', upstream.status)
      return NextResponse.json(
        {
          error: 'upstream_failed',
          message: 'Správu sa teraz nepodarilo odoslať. Napíš nám prosím priamo na support@encore-sk.com.',
        },
        { status: 502, headers },
      )
    }

    return NextResponse.json({ ok: true }, { status: 200, headers })
  } catch (err) {
    console.error('Support form request failed:', err)
    return NextResponse.json(
      {
        error: 'upstream_timeout',
        message: 'Spojenie trvalo príliš dlho. Skús to znova alebo napíš na support@encore-sk.com.',
      },
      { status: 504, headers },
    )
  }
}

function cleanText(value: unknown, maxLen: number): string {
  if (typeof value !== 'string') return ''
  // Strip ASCII control characters except newline/tab
  return value.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '').trim().slice(0, maxLen)
}
