import 'dotenv/config';
import { defineConfig } from 'drizzle-kit';

// Migrations for the shared database live here, next to the schema they come from.
// DATABASE_URL wins when set; otherwise the same POSTGRES_* variables the services use
// (no URL-encoding of passwords needed).
export default defineConfig({
    out: './drizzle',
    schema: './src/schema/*.schema.ts',
    dialect: 'postgresql',
    dbCredentials: process.env.DATABASE_URL
        ? { url: process.env.DATABASE_URL }
        : {
            host: process.env.POSTGRES_HOST || 'localhost',
            port: Number(process.env.POSTGRES_PORT) || 5432,
            user: process.env.POSTGRES_USER,
            password: process.env.POSTGRES_PASSWORD,
            database: process.env.POSTGRES_DB || 'vid2eu',
            ssl: false,
        },
});
