'use client'

import { useEffect, useRef, useState } from 'react'

const WIDE = {
  mp4: '/video/encore-showreel-1920x1080.mp4',
  webm: '/video/encore-showreel-1920x1080.webm',
  poster: '/video/encore-showreel-poster.jpg',
}
const TALL = {
  mp4: '/video/encore-showreel-720x1280.mp4',
  webm: '/video/encore-showreel-720x1280.webm',
  poster: '/video/encore-showreel-poster-vertical.jpg',
}

/**
 * The 27-second film of the app. It plays muted and in a loop only while it is on screen, does not start by itself with
 * Reduce Motion, and can always be paused or started by the visitor (WCAG 2.2.2). Phones get the vertical cut, so
 * nothing is downloaded twice.
 */
export default function ShowreelVideo() {
  const videoRef = useRef<HTMLVideoElement>(null)
  const frameRef = useRef<HTMLDivElement>(null)
  // null until the screen is measured: only the poster is shown, no video is requested yet
  const [tall, setTall] = useState<boolean | null>(null)
  const [reducedMotion, setReducedMotion] = useState(false)
  const [visible, setVisible] = useState(false)
  // what the visitor chose with the button; null = automatic (plays on screen, unless Reduce Motion is on)
  const [choice, setChoice] = useState<'play' | 'pause' | null>(null)

  const wantsPlay = choice === 'play' || (choice === null && !reducedMotion)
  const playing = visible && wantsPlay

  useEffect(() => {
    const phone = window.matchMedia('(max-width: 767px)')
    const motion = window.matchMedia('(prefers-reduced-motion: reduce)')
    const read = () => {
      setTall(phone.matches)
      setReducedMotion(motion.matches)
    }
    read()
    phone.addEventListener('change', read)
    motion.addEventListener('change', read)
    return () => {
      phone.removeEventListener('change', read)
      motion.removeEventListener('change', read)
    }
  }, [])

  // "on screen" means at least a third of the film is visible
  useEffect(() => {
    const frame = frameRef.current
    if (!frame) return
    const observer = new IntersectionObserver(([entry]) => setVisible(entry.isIntersecting), { threshold: 0.35 })
    observer.observe(frame)
    return () => observer.disconnect()
  }, [])

  useEffect(() => {
    const video = videoRef.current
    if (!video) return
    video.muted = true
    if (playing) void video.play().catch(() => {})
    else video.pause()
  }, [playing, tall])

  const source = tall ? TALL : WIDE

  return (
    <div
      ref={frameRef}
      className={`relative mx-auto w-full overflow-hidden rounded-[20px] border border-white/10 bg-[#0B0808] shadow-[0_40px_100px_-30px_rgba(0,0,0,0.9)] ${
        tall ? 'aspect-[9/16] max-w-[340px]' : 'aspect-video'
      }`}
    >
      {tall === null ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={WIDE.poster}
          alt="Náhľad ukážkového videa aplikácie Encore"
          width={1920}
          height={1080}
          loading="lazy"
          decoding="async"
          className="h-full w-full object-cover"
        />
      ) : (
        <video
          key={tall ? 'tall' : 'wide'}
          ref={videoRef}
          suppressHydrationWarning
          width={tall ? 720 : 1920}
          height={tall ? 1280 : 1080}
          className="h-full w-full object-cover"
          poster={source.poster}
          muted
          loop
          playsInline
          preload="none"
          aria-label="Ukážka aplikácie Encore: poznámka po lekcii, Top 3 priority, zostava na parkete, metronóm a kalendár"
        >
          <source src={source.webm} type="video/webm" />
          <source src={source.mp4} type="video/mp4" />
        </video>
      )}
      <button
        type="button"
        onClick={() => setChoice(wantsPlay ? 'pause' : 'play')}
        aria-label={wantsPlay ? 'Pozastaviť video' : 'Spustiť video'}
        className="absolute bottom-3 right-3 flex h-11 w-11 items-center justify-center rounded-full border border-white/15 bg-black/55 text-[#FFE088] backdrop-blur-md transition hover:border-[#FFE088]/50 active:scale-95"
      >
        {wantsPlay ? (
          <svg viewBox="0 0 24 24" className="h-5 w-5" fill="currentColor" aria-hidden>
            <rect x="6" y="5" width="4" height="14" rx="1" />
            <rect x="14" y="5" width="4" height="14" rx="1" />
          </svg>
        ) : (
          <svg viewBox="0 0 24 24" className="h-5 w-5" fill="currentColor" aria-hidden>
            <path d="M8 5.5v13a1 1 0 0 0 1.5.86l10.5-6.5a1 1 0 0 0 0-1.72L9.5 4.64A1 1 0 0 0 8 5.5Z" />
          </svg>
        )}
      </button>
    </div>
  )
}
