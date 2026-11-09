import { pgTable, uuid, text, bigint, timestamp } from 'drizzle-orm/pg-core';
import { video } from './video.schema.ts';

export const storedVideo = pgTable('stored_video', {
    id: uuid('id').defaultRandom().primaryKey(),
    videoId: uuid('video_id')
        .references(() => video.id)
        .notNull()
        .unique(),
    objectKey: text('object_key').notNull().unique(),
    size: bigint('size', { mode: 'number' }),
    checksum: text('checksum'),
    status: text('status').notNull().default('pending'),

    createdAt: timestamp('created_at').notNull().defaultNow()
});