'use client'

import { useEffect, useRef, useState } from 'react'

/**
 * A short loop of the real app inside the phone frame (/video/app/app-<name>.webm, .mp4 and .jpg).
 * Renders the still poster <img> on SSR to guarantee crisp LCP and avoid browser-extension hydration
 * mismatches on <video>, then mounts <video> on the client and plays only while visible.
 */
export default function PhoneVideo({
  name,
  alt,
  priority = false,
  active = true,
}: {
  name: string
  alt: string
  priority?: boolean
  active?: boolean
}) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const [mounted, setMounted] = useState(false)
  const [visible, setVisible] = useState(false)
  const [reducedMotion, setReducedMotion] = useState(false)
  const playing = mounted && active && visible && !reducedMotion

  useEffect(() => {
    setMounted(true)
    const motion = window.matchMedia('(prefers-reduced-motion: reduce)')
    const read = () => setReducedMotion(motion.matches)
    read()
    motion.addEventListener('change', read)
    return () => motion.removeEventListener('change', read)
  }, [])

  useEffect(() => {
    if (!mounted) return
    const video = videoRef.current
    if (!video) return
    const observer = new IntersectionObserver(([entry]) => setVisible(entry.isIntersecting), {
      threshold: 0.25,
      rootMargin: '120px 0px',
    })
    observer.observe(video)
    return () => observer.disconnect()
  }, [mounted])

  useEffect(() => {
    const video = videoRef.current
    if (!video) return
    video.muted = true
    if (playing) void video.play().catch(() => {})
    else video.pause()
  }, [playing])

  if (!mounted) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={`/video/app/app-${name}.jpg`}
        alt={alt}
        width={1179}
        height={2556}
        fetchPriority={priority ? 'high' : 'low'}
        loading={priority ? 'eager' : 'lazy'}
        decoding={priority ? 'sync' : 'async'}
        className="h-full w-full object-cover"
      />
    )
  }

  return (
    <video
      ref={videoRef}
      suppressHydrationWarning
      width={1179}
      height={2556}
      className="h-full w-full object-cover"
      poster={`/video/app/app-${name}.jpg`}
      muted
      loop
      playsInline
      preload="none"
      aria-label={alt}
    >
      <source src={`/video/app/app-${name}.webm`} type="video/webm" />
      <source src={`/video/app/app-${name}.mp4`} type="video/mp4" />
    </video>
  )
}
