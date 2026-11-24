import { type NextRequest, NextResponse } from 'next/server'

// ═══════════════════════════════════════════════════════════
// SECURITY PROXY (Next.js 16)
// - Blocks direct public HTTP access to internal /wallet/* art templates
// - Enforces Fetch Metadata (Sec-Fetch-Site) resource isolation on /api/*
// - Applies hardened CSP, HSTS, CORP/COOP companion headers
// ═══════════════════════════════════════════════════════════

const isDev = process.env.NODE_ENV === 'development'
const hasPostHog = Boolean(process.env.NEXT_PUBLIC_POSTHOG_KEY)

const CONNECT_SOURCES = [
  "'self'",
  'https://iukblwlttvrcdclmlyxu.supabase.co',
  'wss://iukblwlttvrcdclmlyxu.supabase.co',
  ...(hasPostHog ? ['https://eu.posthog.com', 'https://eu-assets.i.posthog.com'] : []),
].join(' ')

const SECURITY_HEADERS: Record<string, string> = {
  ...(!isDev ? { 'Strict-Transport-Security': 'max-age=31536000; includeSubDomains; preload' } : {}),
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Permissions-Policy': [
    'camera=()',
    'microphone=()',
    'geolocation=()',
    'payment=()',
    'usb=()',
    'interest-cohort=()',
    'focus-without-user-activation=()',
  ].join(', '),
  'Content-Security-Policy': [
    "default-src 'self'",
    `script-src 'self' 'unsafe-inline'${isDev ? " 'unsafe-eval'" : ''}`,
    "style-src 'self' 'unsafe-inline'",
    "font-src 'self'",
    "img-src 'self' data: blob: https://iukblwlttvrcdclmlyxu.supabase.co",
    `connect-src ${CONNECT_SOURCES}`,
    "media-src 'self' blob: https://iukblwlttvrcdclmlyxu.supabase.co",
    "object-src 'none'",
    "frame-ancestors 'none'",
    "base-uri 'none'",
    "form-action 'self'",
    ...(!isDev ? ['upgrade-insecure-requests'] : []),
  ].join('; '),
}

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl

  // Internal Apple Wallet pass textures are read from disk by /api/wallet/pass only; never expose over HTTP.
  if (pathname === '/wallet' || pathname.startsWith('/wallet/')) {
    return new NextResponse(null, { status: 404 })
  }

  // Fetch Metadata Resource Isolation on /api/* endpoints (before auth/handler runs).
  // Native iOS URLSession requests do not send Sec-Fetch-Site and pass through normally.
  if (pathname.startsWith('/api/')) {
    const fetchSite = request.headers.get('sec-fetch-site')
    const fetchMode = request.headers.get('sec-fetch-mode')
    const fetchDest = request.headers.get('sec-fetch-dest')
    if (
      fetchSite &&
      !['same-origin', 'same-site', 'none'].includes(fetchSite) &&
      !(fetchSite === 'cross-site' && fetchMode === 'navigate' && request.method === 'GET' && !['object', 'embed'].includes(fetchDest ?? ''))
    ) {
      return new NextResponse('Forbidden', {
        status: 403,
        headers: { Vary: 'Sec-Fetch-Dest, Sec-Fetch-Mode, Sec-Fetch-Site' },
      })
    }
  }

  const response = NextResponse.next()

  if (pathname.startsWith('/api/')) {
    response.headers.set('Vary', 'Sec-Fetch-Dest, Sec-Fetch-Mode, Sec-Fetch-Site')
  }

  Object.entries(SECURITY_HEADERS).forEach(([key, value]) => {
    response.headers.set(key, value)
  })

  return response
}

export const config = {
  matcher: [
    // Match routes and /wallet/* assets (skip Next internals and non-wallet static images)
    '/wallet/:path*',
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|avif|mp4|webm)$).*)',
  ],
}
