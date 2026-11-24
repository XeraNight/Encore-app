'use client'

import { useRef, useState, type FormEvent } from 'react'

const CATEGORIES = [
  { value: 'bug', label: 'Nahlásenie chyby' },
  { value: 'feature', label: 'Nápad na funkciu' },
  { value: 'account', label: 'Účet alebo dáta' },
  { value: 'other', label: 'Iné' },
] as const

export function ContactForm() {
  const [category, setCategory] = useState<string>('bug')
  const [submitting, setSubmitting] = useState(false)
  const [succeeded, setSucceeded] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [fieldError, setFieldError] = useState<string | null>(null)
  const formRef = useRef<HTMLFormElement>(null)

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (submitting) return

    const form = event.currentTarget
    if (!form.checkValidity()) {
      form.reportValidity()
      const firstInvalid = form.querySelector<HTMLElement>(':invalid')
      firstInvalid?.focus()
      return
    }

    setSubmitting(true)
    setErrorMessage(null)
    setFieldError(null)

    const data = new FormData(form)
    const payload = {
      name: String(data.get('name') ?? ''),
      email: String(data.get('email') ?? ''),
      category: String(data.get('category') ?? category),
      message: String(data.get('message') ?? ''),
      _website: String(data.get('_website') ?? ''),
    }

    try {
      const response = await fetch('/api/support', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })
      const json = (await response.json().catch(() => ({}))) as {
        ok?: boolean
        field?: string
        message?: string
      }

      if (!response.ok || !json.ok) {
        setErrorMessage(json.message || 'Správu sa teraz nepodarilo odoslať. Skús to prosím znova.')
        if (json.field) {
          setFieldError(json.field)
          form.querySelector<HTMLElement>(`[name="${json.field}"]`)?.focus()
        }
        return
      }

      setSucceeded(true)
      form.reset()
    } catch {
      setErrorMessage('Chyba spojenia. Skontroluj internet alebo nám napíš priamo na support@encore-sk.com.')
    } finally {
      setSubmitting(false)
    }
  }

  if (succeeded) {
    return (
      <div
        role="status"
        aria-live="polite"
        className="flex flex-col items-center justify-center gap-3 rounded-2xl border border-[#FFE088]/30 bg-[#FFE088]/[0.08] px-6 py-12 text-center"
      >
        <span className="flex h-12 w-12 items-center justify-center rounded-full bg-[#FFE088] font-rounded text-xl font-black text-[#140802]">
          ✓
        </span>
        <h3 className="font-rounded text-xl font-bold text-white">Správa odoslaná</h3>
        <p className="max-w-sm text-sm leading-relaxed text-white/75">
          Ďakujeme za správu. Ozveme sa ti na e-mail spravidla do 24 až 48 hodín.
        </p>
        <button
          type="button"
          onClick={() => setSucceeded(false)}
          className="mt-2 inline-flex min-h-11 items-center rounded-xl border border-white/15 bg-white/[0.07] px-4 py-2 text-xs font-semibold text-white/85 transition hover:border-[#FFE088]/40 hover:text-white"
        >
          Poslať ďalšiu správu
        </button>
      </div>
    )
  }

  return (
    <form ref={formRef} onSubmit={handleSubmit} className="space-y-5" noValidate>
      {/* Accessible honeypot field: hidden from real users & screen readers, catches bots */}
      <div aria-hidden="true" className="absolute -left-[9999px] h-px w-px overflow-hidden">
        <label htmlFor="support-website">Webstránka</label>
        <input id="support-website" name="_website" type="text" tabIndex={-1} autoComplete="off" />
      </div>

      {/* Category: 4 visible radio options instead of <select> for single-tap scanning */}
      <fieldset className="space-y-2.5">
        <legend className="font-rounded text-xs font-black uppercase tracking-[0.14em] text-[#FFE088]">
          TÉMA SPRÁVY
        </legend>
        <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-4">
          {CATEGORIES.map((item) => {
            const checked = category === item.value
            return (
              <label
                key={item.value}
                className={`flex min-h-12 cursor-pointer items-center justify-center rounded-xl border px-3 py-2 text-center font-rounded text-xs font-bold transition ${
                  checked
                    ? 'border-[#FFE088] bg-[#FFE088] text-[#140802]'
                    : 'border-white/12 bg-white/[0.05] text-white/80 hover:border-white/25 hover:text-white'
                }`}
              >
                <input
                  type="radio"
                  name="category"
                  value={item.value}
                  checked={checked}
                  onChange={() => setCategory(item.value)}
                  className="sr-only"
                />
                <span>{item.label}</span>
              </label>
            )
          })}
        </div>
      </fieldset>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div className="space-y-1.5">
          <label htmlFor="support-name" className="block font-rounded text-xs font-black uppercase tracking-[0.12em] text-white/80">
            Meno <span aria-hidden="true" className="text-[#FFE088]">*</span>
          </label>
          <input
            id="support-name"
            type="text"
            name="name"
            required
            minLength={2}
            maxLength={100}
            autoComplete="name"
            enterKeyHint="next"
            aria-invalid={fieldError === 'name' ? 'true' : undefined}
            onInput={() => {
              if (fieldError === 'name') setFieldError(null)
            }}
            placeholder="Tvoje meno"
            className="encore-field min-h-12 w-full rounded-xl border border-white/15 bg-black/35 px-4 py-3 text-base text-white placeholder:text-white/40 transition focus:border-[#FFE088]/70"
          />
        </div>

        <div className="space-y-1.5">
          <label htmlFor="support-email" className="block font-rounded text-xs font-black uppercase tracking-[0.12em] text-white/80">
            E-mail <span aria-hidden="true" className="text-[#FFE088]">*</span>
          </label>
          <input
            id="support-email"
            type="email"
            name="email"
            required
            maxLength={160}
            autoComplete="email"
            autoCapitalize="none"
            autoCorrect="off"
            spellCheck={false}
            enterKeyHint="next"
            aria-invalid={fieldError === 'email' ? 'true' : undefined}
            onInput={() => {
              if (fieldError === 'email') setFieldError(null)
            }}
            placeholder="tvoj@email.sk"
            className="encore-field min-h-12 w-full rounded-xl border border-white/15 bg-black/35 px-4 py-3 text-base text-white placeholder:text-white/40 transition focus:border-[#FFE088]/70"
          />
        </div>
      </div>

      <div className="space-y-1.5">
        <label htmlFor="support-message" className="block font-rounded text-xs font-black uppercase tracking-[0.12em] text-white/80">
          Správa <span aria-hidden="true" className="text-[#FFE088]">*</span>
        </label>
        <textarea
          id="support-message"
          name="message"
          required
          minLength={10}
          maxLength={3000}
          rows={5}
          aria-invalid={fieldError === 'message' ? 'true' : undefined}
          onInput={() => {
            if (fieldError === 'message') setFieldError(null)
          }}
          placeholder="Opíš svoj problém, návrh alebo otázku čo najpresnejšie..."
          className="encore-field w-full rounded-xl border border-white/15 bg-black/35 px-4 py-3 text-base text-white placeholder:text-white/40 transition focus:border-[#FFE088]/70"
        />
      </div>

      {errorMessage && (
        <p role="alert" aria-live="polite" className="rounded-xl border border-red-400/30 bg-red-500/10 px-4 py-3 text-sm text-red-200">
          {errorMessage}
        </p>
      )}

      <button
        type="submit"
        disabled={submitting}
        className="encore-gold-btn w-full sm:w-auto disabled:cursor-not-allowed disabled:opacity-60"
      >
        {submitting ? 'Odosielam…' : 'Odoslať správu'}
      </button>
    </form>
  )
}
