import { pgTable, uuid, text, integer, timestamp } from 'drizzle-orm/pg-core';

export const video = pgTable('video', {
    id: uuid('id').defaultRandom().primaryKey(),
    userId: uuid('user_id'),
    title: text('title').notNull(),
    slug: text('slug').notNull().unique(),
    views: integer('views').notNull().default(0),
    status: text('status').notNull().default('processing'),
    createdAt: timestamp('created_at').notNull().defaultNow(),
    length: integer('length').notNull().default(0),
    width: integer('width'),
    height: integer('height')
})