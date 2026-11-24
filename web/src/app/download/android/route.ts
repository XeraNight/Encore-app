import { NextResponse } from 'next/server'

// MARK: - Google Play Search / Direct App Link Redirect
// Redirects to Google Play Store search for "Encore" (or direct package ID if set in environment)
export async function GET() {
  const packageId = process.env.NEXT_PUBLIC_GOOGLE_PLAY_PACKAGE
  const googlePlayUrl = packageId
    ? `https://play.google.com/store/apps/details?id=${packageId}`
    : (process.env.NEXT_PUBLIC_GOOGLE_PLAY_URL || 'https://play.google.com/store/search?q=Encore&c=apps')

  return NextResponse.redirect(googlePlayUrl, {
    status: 307,
    headers: {
      'Cache-Control': 'no-cache',
    },
  })
}
