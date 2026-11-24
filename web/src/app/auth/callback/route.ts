import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

const ALLOWED_TYPES = new Set(['login', 'signup', 'recovery', 'email_change'])

/**
 * Auth callback — exchanges Supabase PKCE code for a session and redirects cleanly
 * without leaking the already-consumed single-use code into URL history or logs.
 */
export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')
  const rawType = searchParams.get('type') || 'login'
  const type = ALLOWED_TYPES.has(rawType) ? rawType : 'login'

  if (code) {
    const supabase = await createClient()
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error) {
      return NextResponse.redirect(`${origin}/auth/confirm?type=${encodeURIComponent(type)}`, {
        headers: { 'Cache-Control': 'no-store' },
      })
    }
  }

  return NextResponse.redirect(`${origin}/auth/confirm?error=invalid_link`, {
    headers: { 'Cache-Control': 'no-store' },
  })
}
