-- Brings the migrations up to the schema the services actually use. The refresh_token
-- and user columns were added to the live database outside of migrations, so every
-- statement here tolerates already being applied.

-- Tokens issued before refresh_token tracked expiry can't be validated; drop them.
DO $$ BEGIN
	IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'refresh_token' AND column_name = 'expires_at') THEN
		DELETE FROM "refresh_token";
	END IF;
END $$;--> statement-breakpoint
ALTER TABLE "refresh_token" ADD COLUMN IF NOT EXISTS "ip" text NOT NULL DEFAULT '';--> statement-breakpoint
ALTER TABLE "refresh_token" ADD COLUMN IF NOT EXISTS "user_agent" text NOT NULL DEFAULT '';--> statement-breakpoint
ALTER TABLE "refresh_token" ADD COLUMN IF NOT EXISTS "revoked_at" timestamp;--> statement-breakpoint
ALTER TABLE "refresh_token" ADD COLUMN IF NOT EXISTS "expires_at" timestamp NOT NULL DEFAULT now();--> statement-breakpoint
ALTER TABLE "refresh_token" ALTER COLUMN "ip" DROP DEFAULT;--> statement-breakpoint
ALTER TABLE "refresh_token" ALTER COLUMN "user_agent" DROP DEFAULT;--> statement-breakpoint
ALTER TABLE "refresh_token" ALTER COLUMN "expires_at" DROP DEFAULT;--> statement-breakpoint
ALTER TABLE "refresh_token" ALTER COLUMN "created_at" SET DATA TYPE timestamp USING "created_at"::timestamp;--> statement-breakpoint
ALTER TABLE "refresh_token" ALTER COLUMN "created_at" SET DEFAULT now();--> statement-breakpoint
ALTER TABLE "refresh_token" ALTER COLUMN "updated_at" SET DATA TYPE timestamp USING "updated_at"::timestamp;--> statement-breakpoint
ALTER TABLE "refresh_token" ALTER COLUMN "updated_at" SET DEFAULT now();--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "refresh_token_token_idx" ON "refresh_token" ("token");--> statement-breakpoint

ALTER TABLE "user" ADD COLUMN IF NOT EXISTS "default_password" boolean DEFAULT true NOT NULL;--> statement-breakpoint
ALTER TABLE "user" ADD COLUMN IF NOT EXISTS "is_admin" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "user" ALTER COLUMN "limit" SET DATA TYPE numeric(10,2) USING "limit"::numeric(10,2);--> statement-breakpoint
ALTER TABLE "user" ALTER COLUMN "limit" SET DEFAULT '20';--> statement-breakpoint

-- upload and transcode progress, read by GET /me/videos
ALTER TABLE "upload_session" ADD COLUMN IF NOT EXISTS "received_size" bigint DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "upload_session" ADD COLUMN IF NOT EXISTS "updated_at" timestamp DEFAULT now() NOT NULL;--> statement-breakpoint
UPDATE "upload_session" SET "status" = 'pending' WHERE "status" = 'processing';--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "upload_session_token_idx" ON "upload_session" ("token");--> statement-breakpoint
ALTER TABLE "processing_job" ADD COLUMN IF NOT EXISTS "progress" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "processing_job" ADD COLUMN IF NOT EXISTS "stage" text;--> statement-breakpoint
UPDATE "processing_job" SET "progress" = 100 WHERE "status" = 'completed';--> statement-breakpoint

-- videos that finished transcoding before the status column was maintained
UPDATE "video" SET "status" = 'ready'
	WHERE "status" <> 'ready' AND EXISTS (SELECT 1 FROM "video_asset" a WHERE a."video_id" = "video"."id" AND a."type" = '720p');
