-- The app recorded its own purchases here and the server believed the tier it was told, so anyone signed in could
-- write themselves Premium (with the public key and their own session). Closed until purchases are verified with
-- Apple's signature (an Edge Function checking the signed transaction). Meanwhile a paid plan is proven on the
-- iPhone by StoreKit, and server-side rows count only when the owner granted them.
revoke execute on function public.record_app_store_transaction(text, text, timestamptz) from public, anon, authenticated;
