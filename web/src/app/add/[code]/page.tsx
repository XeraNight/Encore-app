import React from 'react'
import { Metadata } from 'next'
import AddFriendClientView from '@/app/add/[code]/AddFriendClientView'
import { APP_STORE_PATH, SITE_URL } from '@/lib/site'

interface PageProps {
  params: Promise<{ code: string }>
}

const CODE_RE = /^[A-Z0-9-]{4,16}$/

function sanitizeCode(raw: string | undefined): string {
  const upper = (raw || '').trim().toUpperCase()
  return CODE_RE.test(upper) ? upper : ''
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { code } = await params
  const cleanCode = sanitizeCode(code)

  const title = 'Encore: Pozvánka na tanečné spojenie'
  const description = 'Pridaj sa do Encore – tréningového denníka pre tanečníkov štandardu a latiny.'

  return {
    title,
    description,
    robots: { index: false, follow: false },
    openGraph: {
      title,
      description,
      type: 'website',
      url: cleanCode ? `${SITE_URL}/add/${encodeURIComponent(cleanCode)}` : `${SITE_URL}/add`,
      images: [
        {
          url: `${SITE_URL}/og/encore-og-1200x630.jpg`,
          width: 1200,
          height: 630,
          alt: 'Encore – tréningový denník pre spoločenské tance',
        },
      ],
    },
    twitter: {
      card: 'summary_large_image',
      title,
      description,
    },
  }
}

export default async function AddFriendPage({ params }: PageProps) {
  const { code } = await params
  const cleanCode = sanitizeCode(code)

  // Public profiles are intentionally locked down from anon enumeration;
  // hand the validated dancer code cleanly to the iOS app via deferred invite link.
  const inviter = {
    code: cleanCode || 'ENCORE',
    name: 'Tanečník Encore',
    club: 'Encore',
    avatarUrl: null as string | null,
  }

  const fullInviteUrl = cleanCode
    ? `${SITE_URL}/add/${encodeURIComponent(cleanCode)}`
    : `${SITE_URL}${APP_STORE_PATH}`

  return (
    <AddFriendClientView
      inviter={inviter}
      appStoreUrl={APP_STORE_PATH}
      fullInviteUrl={fullInviteUrl}
    />
  )
}
