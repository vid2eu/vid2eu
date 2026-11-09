-- The previous snapshot predates video_asset_type and video.length, which were added to
-- the live database outside of migrations, so everything here tolerates already existing.
DO $$ BEGIN
	CREATE TYPE "video_asset_type" AS ENUM('480p', '720p', 'thumbnail');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;--> statement-breakpoint
ALTER TABLE "video" ADD COLUMN IF NOT EXISTS "length" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "video" ADD COLUMN IF NOT EXISTS "width" integer;--> statement-breakpoint
ALTER TABLE "video" ADD COLUMN IF NOT EXISTS "height" integer;
