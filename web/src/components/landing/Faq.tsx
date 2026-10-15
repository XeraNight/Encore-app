import { FAQ } from '@/lib/site'

export default function Faq() {
  return (
    <section id="otazky" className="mx-auto max-w-3xl px-4 py-24 sm:px-6 sm:py-32">
      <div className="text-center">
        <p className="font-rounded text-xs font-black uppercase tracking-[0.2em] text-[#FFE088]">Otázky</p>
        <h2 className="font-serif mt-4 text-4xl font-bold tracking-tight text-white sm:text-5xl">Čo sa často pýtate</h2>
      </div>
      <div className="mt-12 divide-y divide-white/10 border-y border-white/10">
        {FAQ.map((item) => (
          <details key={item.q} className="group py-5">
            <summary className="flex min-h-11 cursor-pointer list-none items-center justify-between gap-6 text-left text-lg font-medium text-white [&::-webkit-details-marker]:hidden">
              {item.q}
              <span
                aria-hidden
                className="flex h-8 w-8 flex-none items-center justify-center rounded-full border border-white/15 text-white/70 transition group-open:rotate-45"
              >
                +
              </span>
            </summary>
            <p className="mt-3 pr-14 leading-relaxed text-white/70">{item.a}</p>
          </details>
        ))}
      </div>
    </section>
  )
}
