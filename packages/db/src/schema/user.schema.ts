import { pgTable, uuid, text, date, numeric, boolean } from 'drizzle-orm/pg-core';

export const user = pgTable('user', {
    id: uuid('id').defaultRandom().primaryKey(),
    name: text('name').notNull(),
    username: text('username').notNull().unique(),
    password: text('password').notNull(),
    limit: numeric('limit', { precision: 10, scale: 2, mode: 'number' }).notNull().default(20),
    defaultPassword: boolean('default_password').notNull().default(true),
    isAdmin: boolean('is_admin').notNull().default(false),
    created_at: date('created_at').notNull().defaultNow(),
    updated_at: date('updated_at').notNull().defaultNow()
})