import { pgTable, uuid, text, bigint, timestamp, pgEnum } from 'drizzle-orm/pg-core';
import { video } from './video.schema.ts';

export const videoAssetType = pgEnum('video_asset_type', ['480p', '720p', 'thumbnail']);

export type VideoAssetType = (typeof videoAssetType.enumValues)[number];

export const videoAsset = pgTable('video_asset', {
    id: uuid('id').defaultRandom().primaryKey(),
    videoId: uuid('video_id')
        .references(() => video.id)
        .notNull(),
    type: videoAssetType('type').notNull(),
    objectKey: text('object_key').notNull().unique(),
    size: bigint('size', { mode: 'number' }),
    mimeType: text('mime_type'),
    createdAt: timestamp('created_at').notNull().defaultNow()
});