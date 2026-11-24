// Run: deno test --allow-read --allow-env --allow-net --no-lock supabase/functions/_shared/account-deletion.test.ts
import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { removeAll } from "./account-deletion.ts";

/** A stand-in for R2 that remembers what was removed and how many removals ran at the same time. */
function fakeR2(failOn?: string) {
  const removed: string[] = [];
  let running = 0;
  let mostAtOnce = 0;
  return {
    removed,
    get mostAtOnce() {
      return mostAtOnce;
    },
    async remove(key: string) {
      running += 1;
      mostAtOnce = Math.max(mostAtOnce, running);
      await new Promise((resolve) => setTimeout(resolve, 1));
      running -= 1;
      if (key === failOn) throw new Error("R2 DELETE failed: 500");
      removed.push(key);
    },
  };
}

const keys = (count: number) => Array.from({ length: count }, (_, index) => `voice/u/voice_${index}.m4a`);

Deno.test("every file is removed", async () => {
  const r2 = fakeR2();
  await removeAll(r2, keys(35));
  assertEquals(r2.removed.length, 35);
  assertEquals(new Set(r2.removed).size, 35);
});

Deno.test("at most ten removals run at the same time", async () => {
  const r2 = fakeR2();
  await removeAll(r2, keys(35));
  assertEquals(r2.mostAtOnce, 10);
});

Deno.test("no files, nothing to do", async () => {
  const r2 = fakeR2();
  await removeAll(r2, []);
  assertEquals(r2.removed.length, 0);
});

Deno.test("a failed removal rejects, so the account stays", async () => {
  const r2 = fakeR2("voice/u/voice_12.m4a");
  await assertRejects(() => removeAll(r2, keys(35)), Error, "R2 DELETE failed");
  // The groups after the failing one are never started.
  assertEquals(r2.removed.includes("voice/u/voice_34.m4a"), false);
});
