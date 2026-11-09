import { sql } from 'drizzle-orm';
import { db } from '../src/client.ts';
import { videoAsset } from '../src/schema/index.ts';

const [oldRoot, flag] = process.argv.slice(2);

if (!oldRoot) {
    console.error('Usage: node packages/db/scripts/rebase-object-keys.ts <old STORAGE_ROOT> [--dry-run]');
    process.exit(1);
}

const prefix = oldRoot.replace(/\\/g, '/').replace(/\/+$/, '') + '/';
const dryRun = flag === '--dry-run';

const rows = await db.select({ id: videoAsset.id, key: videoAsset.objectKey }).from(videoAsset);
let changed = 0;

for (const row of rows) {
    const key = row.key.replace(/\\/g, '/');
    if (!key.toLowerCase().startsWith(prefix.toLowerCase())) continue;

    const relative = key.slice(prefix.length);
    changed++;
    if (dryRun) {
        console.log(`${row.key} -> ${relative}`);
        continue;
    }
    await db.update(videoAsset).set({ objectKey: relative }).where(sql`${videoAsset.id} = ${row.id}`);
}

const absoluteLeft = rows.length - changed - rows.filter(r => !/^([a-zA-Z]:)?[\\/]/.test(r.key)).length;
console.log(`${dryRun ? 'Would rebase' : 'Rebased'} ${changed} of ${rows.length} asset keys.`);
if (absoluteLeft > 0) console.log(`${absoluteLeft} keys are absolute but outside ${prefix}; left unchanged.`);
process.exit(0);
