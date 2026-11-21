'use client'

import { useEffect, useRef, useState, useSyncExternalStore } from 'react'

const subscribeToNothing = () => () => {}

/**
 * A short loop of the real app inside the phone frame (files: /video/app/app-<name>.webm, .mp4 and a still .jpg).
 * It plays muted while it is on screen and stops when it scrolls away; with Reduce Motion it stays on the still.
 */
export default function PhoneVideo({ name, alt }: { name: string; alt: string }) {
  const videoRef = useRef<HTMLVideoElement>(null)
  // false on the server and during hydration (the still is rendered), true afterwards (the video takes over)
  const mounted = useSyncExternalStore(subscribeToNothing, () => true, () => false)
  const [visible, setVisible] = useState(false)
  const [reducedMotion, setReducedMotion] = useState(false)
  const playing = mounted && visible && !reducedMotion

  useEffect(() => {
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
    // eslint-disable-next-line @next/next/no-img-element
    return <img src={`/video/app/app-${name}.jpg`} alt={alt} className="h-full w-full object-cover" />
  }

  return (
    <video
      ref={videoRef}
      suppressHydrationWarning
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
