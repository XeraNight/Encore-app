// The cap on one user's saved results counts only what a save would ADD. A result the user already has (the same
// competition and couple) is overwritten by the upsert, not added, so it must not count again.

/** A saved result is told apart by the competition and the couple, the same as the upsert's conflict key. */
export function resultKey(row: { sutaz_id: number; couple_id: number | null }): string {
  return `${row.sutaz_id}:${row.couple_id}`;
}

/** How many rows of the batch the user does not have yet: only those raise the count against the cap. */
export function countNewResults(batch: { sutaz_id: number; couple_id: number | null }[], saved: Set<string>): number {
  return batch.filter((row) => !saved.has(resultKey(row))).length;
}
