import type { NextRequest } from 'next/server'

interface RateEntry {
  count: number
  resetAt: number
}

const buckets = new Map<string, RateEntry>()
const MAX_BUCKETS = 5_000

/**
 * Lightweight sliding-window in-memory rate limiter for Next.js Route Handlers.
 * Bounds map size so an IP spray cannot grow Node memory unboundedly.
 */
export function checkRateLimit(
  key: string,
  limit: number,
  windowMs: number,
): { allowed: boolean; remaining: number; retryAfterSeconds: number } {
  const now = Date.now()

  if (buckets.size >= MAX_BUCKETS) {
    for (const [k, entry] of buckets) {
      if (entry.resetAt <= now) buckets.delete(k)
    }
    if (buckets.size >= MAX_BUCKETS) {
      const oldest = buckets.keys().next().value
      if (oldest) buckets.delete(oldest)
    }
  }

  const existing = buckets.get(key)
  if (!existing || existing.resetAt <= now) {
    buckets.set(key, { count: 1, resetAt: now + windowMs })
    return { allowed: true, remaining: limit - 1, retryAfterSeconds: 0 }
  }

  if (existing.count >= limit) {
    return {
      allowed: false,
      remaining: 0,
      retryAfterSeconds: Math.max(1, Math.ceil((existing.resetAt - now) / 1000)),
    }
  }

  existing.count += 1
  return { allowed: true, remaining: limit - existing.count, retryAfterSeconds: 0 }
}

/** Extracts the client IP from trusted proxy headers on Vercel / reverse proxies. */
export function getClientIp(request: NextRequest): string {
  const realIp = request.headers.get('x-real-ip')?.trim()
  if (realIp) return realIp
  const forwarded = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
  return forwarded || 'unknown'
}
