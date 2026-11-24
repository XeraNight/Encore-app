import Image from 'next/image'
import PhoneVideo from './PhoneVideo'

/**
 * An iPhone-shaped frame around a real screenshot, or a short loop (`video`), from the app. Until either exists,
 * a calm branded screen with the label is shown instead (never a fake app UI).
 */
export default function PhoneFrame({
  src,
  video,
  alt,
  priority = false,
  active = true,
  className = '',
}: {
  src?: string
  /** Name of a loop in /video/app (app-<name>.webm|mp4|jpg); wins over `src`. */
  video?: string
  alt: string
  priority?: boolean
  /** Set false when hidden inside a crossfade stack so the video decoder pauses immediately. */
  active?: boolean
  className?: string
}) {
  return (
    <div className={`w-full [container-type:inline-size] ${className}`}>
      {/* Sleek iPhone 16 Pro Black Titanium hardware chassis with proportional corners (never bloated at small widths) */}
      <div className="relative aspect-[1179/2556] w-full rounded-[12cqw] bg-gradient-to-br from-[#4f4b47] via-[#262528] to-[#111113] p-[1.8px] shadow-[0_32px_70px_-24px_rgba(0,0,0,0.85)] ring-1 ring-white/15">
        {/* Subtle titanium side hardware buttons */}
        <span aria-hidden="true" className="pointer-events-none absolute -left-[2.5px] top-[16.5%] h-[4.5%] w-[2px] rounded-l-sm bg-gradient-to-b from-white/30 via-[#38363a] to-white/15" />
        <span aria-hidden="true" className="pointer-events-none absolute -left-[2.5px] top-[23.5%] h-[7.2%] w-[2px] rounded-l-sm bg-gradient-to-b from-white/30 via-[#38363a] to-white/15" />
        <span aria-hidden="true" className="pointer-events-none absolute -left-[2.5px] top-[32.5%] h-[7.2%] w-[2px] rounded-l-sm bg-gradient-to-b from-white/30 via-[#38363a] to-white/15" />
        <span aria-hidden="true" className="pointer-events-none absolute -right-[2.5px] top-[26%] h-[10.5%] w-[2px] rounded-r-sm bg-gradient-to-b from-white/30 via-[#38363a] to-white/15" />

        {/* Razor-thin matte black Pro display bezel */}
        <div className="h-full w-full rounded-[11.2cqw] bg-[#060608] p-[2.3cqw]">
          <div className="relative h-full w-full overflow-hidden rounded-[9cqw] bg-[#16030a]">
            {video ? (
              <PhoneVideo name={video} alt={alt} priority={priority} active={active} />
            ) : src ? (
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
                <Image src="/encore_mark.png" alt="" width={404} height={644} className="h-14 w-auto opacity-95" />
                <p className="font-rounded text-[11px] font-black uppercase tracking-[0.2em] text-[#FFE088]">{alt}</p>
              </div>
            )}
            {/* Compact Dynamic Island */}
            <div
              aria-hidden="true"
              className="pointer-events-none absolute left-1/2 top-[1.7%] h-[2.5%] w-[26.5%] -translate-x-1/2 rounded-full bg-black ring-1 ring-white/[0.06]"
            />
          </div>
        </div>
      </div>
    </div>
  )
}
