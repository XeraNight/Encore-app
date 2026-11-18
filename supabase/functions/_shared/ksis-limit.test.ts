// Run: deno test --allow-read --allow-env --no-lock supabase/functions/_shared/ksis-limit.test.ts
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { countNewResults, resultKey } from "./ksis-limit.ts";

const row = (sutaz_id: number, couple_id = 18967) => ({ sutaz_id, couple_id });

Deno.test("a result is told apart by the competition and the couple", () => {
  assertEquals(resultKey(row(12094)), "12094:18967");
  assertEquals(resultKey(row(12094, 5)) === resultKey(row(12094, 18967)), false);
});

Deno.test("rows the user already has do not count again", () => {
  // 600 rows on the page, 500 of them saved before: only the 100 new ones raise the count.
  const batch = Array.from({ length: 600 }, (_, index) => row(index));
  const saved = new Set(batch.slice(0, 500).map(resultKey));
  assertEquals(countNewResults(batch, saved), 100);
});

Deno.test("nothing saved yet: every row is new", () => {
  assertEquals(countNewResults([row(1), row(2), row(3)], new Set()), 3);
});

Deno.test("the same competition of another couple is a new result", () => {
  assertEquals(countNewResults([row(1, 99)], new Set([resultKey(row(1))])), 1);
});

Deno.test("an empty batch adds nothing", () => {
  assertEquals(countNewResults([], new Set([resultKey(row(1))])), 0);
});
