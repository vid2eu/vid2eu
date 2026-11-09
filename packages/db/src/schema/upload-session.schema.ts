import { pgTable, uuid, text, bigint, timestamp } from 'drizzle-orm/pg-core';
import { video } from './video.schema.ts';

export const uploadSession = pgTable('upload_session', {
    id: uuid('id').defaultRandom().primaryKey(),
    videoId: uuid('video_id').references(() => video.id).notNull(),
    token: text('token').notNull(),
    status: text('status').notNull(),
    expiresAt: timestamp('expires_at').notNull(),
    expectedSize: bigint('expected_size', { mode: 'number' }).notNull().default(0),
    receivedSize: bigint('received_size', { mode: 'number' }).notNull().default(0),
    createdAt: timestamp('created_at').notNull().defaultNow(),
    updatedAt: timestamp('updated_at').notNull().defaultNow(),
})
