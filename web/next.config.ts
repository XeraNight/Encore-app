import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  // Security: disable X-Powered-By header (information disclosure)
  // Security #15 — don't reveal tech stack to attackers
  poweredByHeader: false,

  // Security headers applied globally (supplements middleware)
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'X-DNS-Prefetch-Control',
            value: 'on',
          },
          // Subresource Integrity hint for browsers (Security #8 / OWASP A08)
          {
            key: 'Cross-Origin-Resource-Policy',
            value: 'same-origin',
          },
          {
            key: 'Cross-Origin-Opener-Policy',
            value: 'same-origin',
          },
          {
            key: 'Cross-Origin-Embedder-Policy',
            value: 'credentialless',
          },
        ],
      },
    ]
  },

  // The Apple Wallet pass reads its icon and logo from public/ at runtime; without this the
  // serverless function on Vercel may not have the files and the pass fails.
  outputFileTracingIncludes: {
    '/api/wallet/pass': ['./public/logo.png', './public/wallet/**'],
  },

  // Lock Screen buttons of the app open /quick/…; without Encore installed they land on the download page.
  async redirects() {
    return [{ source: '/quick/:action*', destination: '/download/ios', permanent: false }]
  },

  // Images: only allow Supabase storage domain
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'iukblwlttvrcdclmlyxu.supabase.co',
        pathname: '/storage/v1/object/public/**',
      },
    ],
  },

  experimental: {
    // Server Actions are enabled by default in Next.js 14+
  },
}

export default nextConfig
