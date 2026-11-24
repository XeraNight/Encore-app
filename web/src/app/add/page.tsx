import React from 'react'
import { Metadata } from 'next'
import { createClient } from '@supabase/supabase-js'
import AddFriendClientView from '@/app/add/[code]/AddFriendClientView'
import { APP_STORE_PATH, SITE_URL } from '@/lib/site'

interface PageProps {
  searchParams: Promise<{ t?: string; code?: string }>
}

const INVITE_TOKEN_RE = /^tok_[0-9a-f]{16,64}$/i
const LEGACY_CODE_RE = /^[A-Z0-9-]{4,16}$/

function sanitizeInviteParam(raw: string | undefined): string {
  if (!raw) return ''
  const trimmed = raw.trim()
  if (INVITE_TOKEN_RE.test(trimmed)) return trimmed
  const upper = trimmed.toUpperCase()
  if (LEGACY_CODE_RE.test(upper)) return upper
  return ''
}

export async function generateMetadata({ searchParams }: PageProps): Promise<Metadata> {
  const { t, code } = await searchParams
  const inviteToken = sanitizeInviteParam(t || code)

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
      url: inviteToken ? `${SITE_URL}/add?t=${encodeURIComponent(inviteToken)}` : `${SITE_URL}/add`,
      images: [
        {
          url: `${SITE_URL}/og/encore-og-1200x630.jpg`,
          width: 1200,
          height: 630,
          alt: 'Encore – tréningový denník pre spoločenské tance',
        },
      ],
    },
  }
}

export default async function AddByTokenPage({ searchParams }: PageProps) {
  const { t, code } = await searchParams
  const token = sanitizeInviteParam(t || code)

  let inviter = {
    code: token || 'ENCORE',
    name: 'Tanečník Encore',
    club: 'Individuálny',
    avatarUrl: null as string | null,
  }

  // Only opaque invite tokens (tok_*) resolve through the dedicated SECURITY DEFINER RPC.
  // Never interpolate URL parameters into PostgREST .or() filters.
  if (token && INVITE_TOKEN_RE.test(token)) {
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://iukblwlttvrcdclmlyxu.supabase.co'
    const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ''
    if (supabaseAnonKey) {
      const supabase = createClient(supabaseUrl, supabaseAnonKey)
      const { data: preview } = await supabase.rpc('get_friend_invite_preview', { p_token: token })
      if (preview?.success && preview?.inviter) {
        inviter = {
          code: preview.inviter.dancer_code || preview.inviter.ksis_id || token.substring(0, 8),
          name: preview.inviter.name || 'Tanečník Encore',
          club: preview.inviter.club || 'Individuálny',
          avatarUrl: preview.inviter.avatar_url || null,
        }
      }
    }
  }

  const fullInviteUrl = token ? `${SITE_URL}/add?t=${encodeURIComponent(token)}` : `${SITE_URL}${APP_STORE_PATH}`

  return (
    <AddFriendClientView
      inviter={inviter}
      appStoreUrl={APP_STORE_PATH}
      fullInviteUrl={fullInviteUrl}
    />
  )
}
