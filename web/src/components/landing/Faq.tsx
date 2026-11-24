import { FAQ } from '@/lib/site'

export default function Faq() {
  return (
    <section
      id="otazky"
      aria-labelledby="otazky-nadpis"
      className="border-y border-[#23090C]/10 bg-[#F6E9CE] text-[#23090C]"
    >
      <div className="mx-auto max-w-3xl px-5 py-24 sm:px-6 sm:py-28">
        <div className="text-center">
          <p className="font-rounded text-xs font-black uppercase tracking-[0.16em] text-[#7A0A1B]">ČASTÉ OTÁZKY</p>
          <h2 id="otazky-nadpis" className="font-rounded mt-3 text-3xl font-black tracking-tight text-[#23090C] sm:text-5xl">
            Čo sa často pýtate
          </h2>
        </div>
        <div className="encore-faq mt-10 space-y-3">
          {FAQ.map((item) => (
            <details
              key={item.q}
              className="group rounded-[20px] border border-[#23090C]/12 bg-[#FBF2DF] px-6 py-4 transition hover:border-[#7A0A1B]/35"
            >
              <summary className="flex min-h-11 cursor-pointer list-none items-center justify-between gap-6 text-left font-rounded text-base font-bold text-[#23090C] sm:text-lg [&::-webkit-details-marker]:hidden">
                <span>{item.q}</span>
                <span
                  aria-hidden="true"
                  className="flex h-8 w-8 flex-none items-center justify-center rounded-full border border-[#5C0614]/25 bg-[#5C0614] font-rounded text-base font-bold text-[#FFE8A3] transition-transform duration-200 group-open:rotate-45 motion-reduce:transition-none"
                >
                  +
                </span>
              </summary>
              <p className="mt-3 border-t border-[#23090C]/12 pt-3 pr-10 text-[15px] leading-relaxed text-[#23090C]/80">
                {item.a}
              </p>
            </details>
          ))}
        </div>
      </div>
    </section>
  )
}
