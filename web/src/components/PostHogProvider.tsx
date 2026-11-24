'use client'

import { useEffect } from 'react'

/**
 * Privacy-first EU PostHog analytics loader.
 * Dynamically imports posthog-js ONLY when NEXT_PUBLIC_POSTHOG_KEY is configured,
 * keeping ~50 KB gzipped out of the initial JavaScript bundle when unused or before hydration.
 */
export function PostHogProvider({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    const key = process.env.NEXT_PUBLIC_POSTHOG_KEY
    if (!key) return

    let active = true
    void import('posthog-js')
      .then(({ default: posthog }) => {
        if (!active) return
        posthog.init(key, {
          api_host: process.env.NEXT_PUBLIC_POSTHOG_HOST ?? 'https://eu.posthog.com',
          person_profiles: 'identified_only',
          capture_pageview: false,
          capture_pageleave: true,
          autocapture: false,
          persistence: 'memory',
          loaded: (ph) => {
            if (process.env.NODE_ENV === 'development') {
              ph.debug()
            }
          },
        })
      })
      .catch(() => {})

    return () => {
      active = false
    }
  }, [])

  return <>{children}</>
}
