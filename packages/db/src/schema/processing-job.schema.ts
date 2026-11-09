import {
    pgTable,
    pgEnum,
    uuid,
    text,
    integer,
    timestamp,
    index,
    uniqueIndex,
} from 'drizzle-orm/pg-core';

import { sql } from 'drizzle-orm';

export const processingJobStatus = pgEnum('processing_job_status', [
    'pending',
    'processing',
    'completed',
    'failed',
]);

export const processingJob = pgTable('processing_job', {
    id: uuid('id').defaultRandom().primaryKey(),
    videoId: uuid('video_id').notNull(),
    status: processingJobStatus('status').notNull().default('pending'),
    attempts: integer('attempts').notNull().default(0),
    maxAttempts: integer('max_attempts').notNull().default(3),
    progress: integer('progress').notNull().default(0),
    stage: text('stage'),
    availableAt: timestamp('available_at', { withTimezone: true })
        .notNull()
        .defaultNow(),
    lockedBy: text('locked_by'),
    lockedUntil: timestamp('locked_until', { withTimezone: true }),
    lastError: text('last_error'),
    createdAt: timestamp('created_at', { withTimezone: true })
        .notNull()
        .defaultNow(),
    startedAt: timestamp('started_at', { withTimezone: true }),
    completedAt: timestamp('completed_at', { withTimezone: true }),
}, (table) => [
    index('processing_job_pending_idx')
        .on(table.availableAt, table.createdAt)
        .where(sql`${table.status} = 'pending'`),

    index('processing_job_processing_idx')
        .on(table.lockedUntil)
        .where(sql`${table.status} = 'processing'`),

    uniqueIndex('processing_job_active_video_idx')
        .on(table.videoId)
        .where(sql`${table.status} IN ('pending', 'processing')`),
]);

export type ProcessingJob = typeof processingJob.$inferSelect;
export type NewProcessingJob = typeof processingJob.$inferInsert;