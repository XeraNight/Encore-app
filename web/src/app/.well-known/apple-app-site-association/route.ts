import { NextResponse } from 'next/server'

export const dynamic = 'force-static'

// MARK: - Apple App Site Association (Universal Links)
// Handled by iOS to open the Encore app directly when scanning QR codes or clicking links.
// /quick/* are the Lock Screen and Control Center buttons. /auth/* stays on the web: the app's own
// auth links use encore://auth-callback, so web sign-in links must not be taken over by the app.
export async function GET() {
  const teamId = process.env.APPLE_TEAM_IDENTIFIER || '2MD5BS4DLM'
  const bundleId = process.env.APPLE_BUNDLE_IDENTIFIER || 'com.jakub.encore'
  const appID = `${teamId}.${bundleId}`

  const aasa = {
    applinks: {
      apps: [],
      details: [
        {
          appID,
          paths: [
            '/add*',
            '/add/*',
            '/u/*',
            '/quick/*',
            '/download*',
            '/routine/*',
            '/invite/*'
          ],
          components: [
            {
              '/': '/add/*'
            },
            {
              '/': '/u/*'
            },
            {
              '/': '/quick/*'
            },
            {
              '/': '/download*'
            },
            {
              '/': '/routine/*'
            },
            {
              '/': '/invite/*'
            }
          ]
        }
      ]
    },
    webcredentials: {
      apps: [appID]
    }
  }

  return NextResponse.json(aasa, {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=86400, immutable'
    }
  })
}
