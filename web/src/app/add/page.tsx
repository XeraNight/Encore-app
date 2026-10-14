import React from 'react'
import { Metadata } from 'next'
import { createClient } from '@supabase/supabase-js'
import AddFriendClientView from '@/app/add/[code]/AddFriendClientView'

interface PageProps {
  searchParams: Promise<{ t?: string; code?: string }>
}

export async function generateMetadata({ searchParams }: PageProps): Promise<Metadata> {
  const { t, code } = await searchParams
  const inviteToken = t || code || ''

  const title = 'Encore: Pozvánka na tanečné spojenie'
  const description = 'Pridaj sa do Encore – prémiového tréningového nástroja pre tanečníkov štandardu a latiny.'

  return {
    title,
    description,
    openGraph: {
      title,
      description,
      type: 'website',
      url: `https://www.encore-sk.com/add?t=${inviteToken}`,
      images: [
        {
          url: 'https://www.encore-sk.com/encore_stage_bg.jpg',
          width: 1200,
          height: 630,
          alt: 'Encore Dance Platform'
        }
      ]
    }
  }
}

export default async function AddByTokenPage({ searchParams }: PageProps) {
  const { t, code } = await searchParams
  const token = t || code || ''

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://iukblwlttvrcdclmlyxu.supabase.co'
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ''
  const supabase = createClient(supabaseUrl, supabaseAnonKey)

  let inviter = {
    code: token,
    name: 'Tanečník Encore',
    club: 'Individuálny',
    avatarUrl: null as string | null
  }

  if (token) {
    // If it's an opaque token (starts with tok_)
    if (token.startsWith('tok_')) {
      const { data: preview } = await supabase.rpc('get_friend_invite_preview', { p_token: token })
      if (preview?.success && preview?.inviter) {
        inviter = {
          code: preview.inviter.dancer_code || preview.inviter.ksis_id || token.substring(0, 8),
          name: preview.inviter.name,
          club: preview.inviter.club,
          avatarUrl: preview.inviter.avatar_url
        }
      }
    } else {
      // Legacy code lookup
      const { data: profile } = await supabase
        .from('profiles')
        .select('name, club, avatar_url, invite_code, dancer_code, ksis_id')
        .or(`invite_code.eq.${token},dancer_code.eq.${token}`)
        .single()

      if (profile) {
        inviter = {
          code: profile.ksis_id ? `KSIS ${profile.ksis_id}` : (profile.dancer_code || token),
          name: profile.name || 'Tanečník Encore',
          club: profile.club || 'Individuálny',
          avatarUrl: profile.avatar_url
        }
      }
    }
  }

  const appStoreUrl = process.env.NEXT_PUBLIC_APP_STORE_URL || 'https://apps.apple.com/search?term=Encore+Dance'
  const domain = process.env.NEXT_PUBLIC_APP_DOMAIN || 'www.encore-sk.com'
  const fullInviteUrl = `https://${domain}/add?t=${token}`

  return (
    <AddFriendClientView
      inviter={inviter}
      appStoreUrl={appStoreUrl}
      fullInviteUrl={fullInviteUrl}
    />
  )
}
