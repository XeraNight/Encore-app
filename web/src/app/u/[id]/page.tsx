import { redirect } from 'next/navigation'

/**
 * Legacy /u/[id] member card links have been superseded by signed /add?t=tok_... invite tokens.
 * Redirecting avoids rendering attacker-supplied query strings on www.encore-sk.com.
 */
export default function LegacyUserCardRedirect() {
  redirect('/download')
}
