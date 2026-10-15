import Link from 'next/link'
import { APP_STORE_PATH } from '@/lib/site'
import { IconApple } from './Icons'

/** Black App Store button in the shape and wording of Apple's badge ("Stiahnuť v App Store"). */
export default function AppStoreButton({ size = 'large' }: { size?: 'large' | 'small' }) {
  const large = size === 'large'
  return (
    <Link
      href={APP_STORE_PATH}
      className={`group inline-flex items-center gap-3 rounded-2xl border border-white/25 bg-black text-white transition hover:border-white/50 active:scale-[0.97] ${
        large ? 'h-14 px-5' : 'h-10 px-3.5'
      }`}
      aria-label="Stiahnuť Encore v App Store"
    >
      <IconApple className={large ? 'h-7 w-7' : 'h-5 w-5'} />
      <span className="flex flex-col items-start leading-none">
        <span className={large ? 'text-[11px] text-white/80' : 'text-[9px] text-white/80'}>Stiahnuť v</span>
        <span className={`font-semibold tracking-tight ${large ? 'text-[21px]' : 'text-[15px]'}`}>App Store</span>
      </span>
    </Link>
  )
}
