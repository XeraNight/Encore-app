// Deletes a user and everything they own. Used by delete-account (the user) and owner-delete-account (the owner).
//
// Why not SQL: Supabase refuses to delete an auth user that owns Storage objects, and deleting rows from
// storage.objects in SQL does not remove the files. So the files are removed through the Storage API first, then the
// auth user (database rows cascade). If cleaning fails, it throws before the user is deleted, so the account stays.

import { getR2 } from "./r2.ts";

const BUCKET = "encore-media";
const PAGE = 100;

// deno-lint-ignore no-explicit-any
async function listAllFiles(admin: any, root: string): Promise<string[]> {
  const files: string[] = [];
  const pending = [root];
  while (pending.length > 0) {
    const dir = pending.pop()!;
    let offset = 0;
    for (;;) {
      const { data, error } = await admin.storage.from(BUCKET).list(dir, { limit: PAGE, offset });
      if (error) throw error;
      if (!data || data.length === 0) break;
      for (const item of data) {
        const path = `${dir}/${item.name}`;
        // Folders come back without an id
        if (item.id === null || item.id === undefined) pending.push(path);
        else files.push(path);
      }
      if (data.length < PAGE) break;
      offset += PAGE;
    }
  }
  return files;
}

// deno-lint-ignore no-explicit-any
export async function deleteAccountAndFiles(admin: any, userId: string): Promise<{ files: number; sharedVideos: number }> {
  const files = await listAllFiles(admin, userId);
  for (let i = 0; i < files.length; i += PAGE) {
    const batch = files.slice(i, i + PAGE);
    const { error } = await admin.storage.from(BUCKET).remove(batch);
    if (error) throw error;
  }

  // Videos shared with partner and coach live in Cloudflare R2. Their rows would cascade away with the user, the
  // files would not, so they go first.
  const { data: shared, error: sharedError } = await admin.from("shared_videos").select("key").eq("owner_id", userId);
  if (sharedError) throw sharedError;
  if (shared && shared.length > 0) {
    const r2 = getR2();
    for (const row of shared) await r2.remove(row.key);
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError) throw deleteError;

  return { files: files.length, sharedVideos: shared?.length ?? 0 };
}
