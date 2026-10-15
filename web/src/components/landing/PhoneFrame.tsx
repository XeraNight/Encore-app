import Image from 'next/image'

/**
 * An iPhone-shaped frame around a real screenshot from the app. Until the screenshot exists, a calm
 * branded screen with the label is shown instead (never a fake app UI).
 */
export default function PhoneFrame({
  src,
  alt,
  priority = false,
  className = '',
}: {
  src?: string
  alt: string
  priority?: boolean
  className?: string
}) {
  return (
    <div
      className={`relative aspect-[1179/2556] w-full rounded-[2.75rem] bg-[#0c0c0e] p-[9px] shadow-[0_40px_90px_-30px_rgba(0,0,0,0.9)] ring-1 ring-white/15 ${className}`}
    >
      <div className="relative h-full w-full overflow-hidden rounded-[2.2rem] bg-[#16030a]">
        {src ? (
          <Image
            src={src}
            alt={alt}
            fill
            priority={priority}
            sizes="(min-width: 1024px) 320px, 72vw"
            className="object-cover"
          />
        ) : (
          <div className="flex h-full flex-col items-center justify-center gap-4 bg-[radial-gradient(80%_60%_at_50%_20%,rgba(160,20,45,0.55),transparent_70%)] px-6 text-center">
            <Image src="/logo_mark.svg" alt="" width={44} height={44} className="opacity-90" />
            <p className="font-rounded text-[11px] font-black uppercase tracking-[0.2em] text-[#FFE088]">{alt}</p>
          </div>
        )}
        <div aria-hidden className="absolute left-1/2 top-[1.6%] h-[3.2%] w-[31%] -translate-x-1/2 rounded-full bg-black" />
      </div>
    </div>
  )
}
