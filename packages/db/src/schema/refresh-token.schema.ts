import { pgTable, uuid, text, timestamp } from 'drizzle-orm/pg-core';
import { user } from './user.schema.ts';

export const refreshToken = pgTable('refresh_token', {
    id: uuid('id').defaultRandom().primaryKey(),
    token: text('token').notNull(),
    user_id: uuid('user_id').references(() => user.id).notNull(),
    ip: text('ip').notNull(),
    user_agent: text('user_agent').notNull(),
    revoked_at: timestamp('revoked_at'),
    expires_at: timestamp('expires_at').notNull(),
    created_at: timestamp('created_at').notNull().defaultNow(),
    updated_at: timestamp('updated_at').notNull().defaultNow()
})