import { NextResponse } from 'next/server'

// MARK: - App Store Search / Direct App Link Redirect
// Redirects to the Apple App Store search for "Encore" (or direct app ID if set in environment)
export async function GET() {
  const directAppId = process.env.NEXT_PUBLIC_APP_STORE_ID
  const appStoreUrl = directAppId 
    ? `https://apps.apple.com/app/id${directAppId}`
    : (process.env.NEXT_PUBLIC_APP_STORE_URL || 'https://apps.apple.com/search?term=Encore')

  return NextResponse.redirect(appStoreUrl, {
    status: 307,
    headers: {
      'Cache-Control': 'no-cache',
    },
  })
}
