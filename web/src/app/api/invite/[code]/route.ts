import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { checkRateLimit, getClientIp } from '@/lib/rate-limit'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

const TOKEN_RE = /^tok_[0-9a-f]{16,64}$/i

/**
 * Public invite preview endpoint — only resolves opaque, revocable invite tokens (tok_*)
 * through the hardened get_friend_invite_preview RPC with IP rate limiting.
 */
export async function GET(
  request: NextRequest,
  context: { params: Promise<{ code: string }> },
) {
  const ip = getClientIp(request)
  const limit = checkRateLimit(`invite:${ip}`, 30, 10 * 60 * 1000)
  if (!limit.allowed) {
    return NextResponse.json(
      { error: 'rate_limited', message: 'Príliš veľa pokusov. Skús to znova o chvíľu.' },
      { status: 429, headers: { 'Retry-After': String(limit.retryAfterSeconds) } },
    )
  }

  try {
    const { code } = await context.params
    const cleanToken = (code || '').trim()

    if (!TOKEN_RE.test(cleanToken)) {
      return NextResponse.json(
        { error: 'invalid_code', message: 'Neplatný formát kódu pozvánky.' },
        { status: 400 },
      )
    }

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://iukblwlttvrcdclmlyxu.supabase.co'
    const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ''
    if (!supabaseAnonKey) {
      return NextResponse.json(
        { error: 'service_unavailable', message: 'Služba je momentálne nedostupná.' },
        { status: 503 },
      )
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey)
    const { data: preview, error } = await supabase.rpc('get_friend_invite_preview', { p_token: cleanToken })

    if (error || !preview?.success || !preview?.inviter) {
      return NextResponse.json(
        { error: 'not_found', message: 'Pozvánka neexistuje alebo už vypršala.' },
        { status: 404 },
      )
    }

    return NextResponse.json(
      {
        success: true,
        invite: {
          code: preview.inviter.dancer_code || '',
          name: preview.inviter.name || 'Tanečník',
          club: preview.inviter.club || '',
          avatarUrl: preview.inviter.avatar_url || null,
        },
      },
      {
        status: 200,
        headers: {
          'Cache-Control': 'private, no-cache',
        },
      },
    )
  } catch (err) {
    console.error('Invite lookup failed:', err)
    return NextResponse.json(
      { error: 'server_error', message: 'Nepodarilo sa overiť pozvánku.' },
      { status: 500 },
    )
  }
}
