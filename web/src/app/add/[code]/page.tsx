import React from 'react'
import { Metadata } from 'next'
import Image from 'next/image'
import { createClient } from '@supabase/supabase-js'
import AddFriendClientView from '@/app/add/[code]/AddFriendClientView'

interface PageProps {
  params: Promise<{ code: string }>
}

// Generate Open Graph Metadata for Social Shares & iMessage previews
export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { code } = await params
  const cleanCode = (code || '').trim().toUpperCase()

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://iukblwlttvrcdclmlyxu.supabase.co'
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ''
  const supabase = createClient(supabaseUrl, supabaseAnonKey)

  const { data: profile } = await supabase
    .from('profiles')
    .select('name, club')
    .eq('invite_code', cleanCode)
    .single()

  const name = profile?.name || 'Tanečník'
  const title = `Encore: Pozvánka od ${name}`
  const description = `${name} ťa pozýva do aplikácie Encore – prémiového tréningového nástroja pre tanečníkov štandardu a latiny.`

  return {
    title,
    description,
    openGraph: {
      title,
      description,
      type: 'website',
      url: `https://www.encore-sk.com/add/${cleanCode}`,
      images: [
        {
          url: 'https://www.encore-sk.com/encore_stage_bg.jpg',
          width: 1200,
          height: 630,
          alt: 'Encore Dance Platform'
        }
      ]
    },
    twitter: {
      card: 'summary_large_image',
      title,
      description
    }
  }
}

export default async function AddFriendPage({ params }: PageProps) {
  const { code } = await params
  const cleanCode = (code || '').trim().toUpperCase()

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://iukblwlttvrcdclmlyxu.supabase.co'
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ''
  const supabase = createClient(supabaseUrl, supabaseAnonKey)

  const { data: profile } = await supabase
    .from('profiles')
    .select('name, club, avatar_url, invite_code')
    .eq('invite_code', cleanCode)
    .single()

  const inviter = {
    code: cleanCode,
    name: profile?.name || 'Tanečník Encore',
    club: profile?.club || 'Encore Dance Club',
    avatarUrl: profile?.avatar_url || null
  }

  const appStoreUrl = process.env.NEXT_PUBLIC_APP_STORE_URL || 'https://apps.apple.com/search?term=Encore+Dance'
  const domain = process.env.NEXT_PUBLIC_APP_DOMAIN || 'www.encore-sk.com'
  const fullInviteUrl = `https://${domain}/add/${cleanCode}`

  return (
    <AddFriendClientView
      inviter={inviter}
      appStoreUrl={appStoreUrl}
      fullInviteUrl={fullInviteUrl}
    />
  )
}
