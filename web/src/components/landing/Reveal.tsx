'use client'

import { useEffect, useRef, useState, type ReactNode } from 'react'

type RevealCallback = () => void

let sharedObserver: IntersectionObserver | null = null
const callbacks = new WeakMap<Element, RevealCallback>()

function getSharedObserver(): IntersectionObserver {
  if (!sharedObserver) {
    sharedObserver = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue
          const cb = callbacks.get(entry.target)
          if (cb) {
            cb()
            callbacks.delete(entry.target)
          }
          sharedObserver?.unobserve(entry.target)
        }
      },
      { rootMargin: '0px 0px 15% 0px' },
    )
  }
  return sharedObserver
}

/**
 * Fades content in gently before it scrolls into view using one shared IntersectionObserver.
 * Without JS, with Reduce Motion, or when already in viewport, content remains immediately visible.
 */
export default function Reveal({ children, delay = 0, className = '' }: { children: ReactNode; delay?: number; className?: string }) {
  const ref = useRef<HTMLDivElement>(null)
  const [hidden, setHidden] = useState(false)

  useEffect(() => {
    const element = ref.current
    if (!element) return
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return

    const observer = getSharedObserver()
    const raf = requestAnimationFrame(() => {
      if (element.getBoundingClientRect().top < window.innerHeight) return
      setHidden(true)
      callbacks.set(element, () => setHidden(false))
      observer.observe(element)
    })

    return () => {
      cancelAnimationFrame(raf)
      callbacks.delete(element)
      observer.unobserve(element)
    }
  }, [])

  return (
    <div
      ref={ref}
      className={`transition duration-700 ease-out motion-reduce:transition-none ${hidden ? 'translate-y-5 opacity-0' : 'translate-y-0 opacity-100'} ${className}`}
      style={{ transitionDelay: hidden ? '0ms' : `${delay}ms` }}
    >
      {children}
    </div>
  )
}
