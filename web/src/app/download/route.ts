import { NextRequest, NextResponse } from 'next/server'

// MARK: - Smart Universal Download Router
// Detects operating system and redirects to App Store or Google Play search
export async function GET(request: NextRequest) {
  const userAgent = request.headers.get('user-agent') || ''
  const origin = request.nextUrl.origin

  const isIOS = /iPhone|iPad|iPod/i.test(userAgent)
  const isAndroid = /Android/i.test(userAgent)

  if (isIOS) {
    return NextResponse.redirect(`${origin}/download/ios`, { status: 307 })
  }

  if (isAndroid) {
    return NextResponse.redirect(`${origin}/download/android`, { status: 307 })
  }

  // Desktop visitors: redirect to the landing page download anchor
  return NextResponse.redirect(`${origin}/#stiahnut`, { status: 307 })
}
