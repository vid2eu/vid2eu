-- video_asset references this type; it was only created by the next migration, so fresh databases failed here
DO $$ BEGIN
	CREATE TYPE "video_asset_type" AS ENUM('480p', '720p', 'thumbnail');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;--> statement-breakpoint
CREATE TYPE "processing_job_status" AS ENUM('pending', 'processing', 'completed', 'failed');--> statement-breakpoint
CREATE TABLE "processing_job" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"video_id" uuid NOT NULL,
	"status" "processing_job_status" DEFAULT 'pending'::"processing_job_status" NOT NULL,
	"attempts" integer DEFAULT 0 NOT NULL,
	"max_attempts" integer DEFAULT 3 NOT NULL,
	"available_at" timestamp with time zone DEFAULT now() NOT NULL,
	"locked_by" text,
	"locked_until" timestamp with time zone,
	"last_error" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"started_at" timestamp with time zone,
	"completed_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "refresh_token" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"token" text NOT NULL,
	"user_id" uuid NOT NULL,
	"created_at" date DEFAULT 'now()' NOT NULL,
	"updated_at" date DEFAULT 'now()' NOT NULL
);
--> statement-breakpoint
CREATE TABLE "stored_video" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"video_id" uuid NOT NULL UNIQUE,
	"object_key" text NOT NULL UNIQUE,
	"size" bigint,
	"checksum" text,
	"status" text DEFAULT 'pending' NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "upload_session" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"video_id" uuid NOT NULL,
	"token" text NOT NULL,
	"status" text NOT NULL,
	"expires_at" timestamp NOT NULL,
	"expected_size" bigint DEFAULT 0 NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "user" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"name" text NOT NULL,
	"username" text NOT NULL UNIQUE,
	"password" text NOT NULL,
	"limit" integer NOT NULL,
	"created_at" date DEFAULT now() NOT NULL,
	"updated_at" date DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "video_asset" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"video_id" uuid NOT NULL,
	"type" "video_asset_type" NOT NULL,
	"object_key" text NOT NULL UNIQUE,
	"size" bigint,
	"mime_type" text,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "video" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"user_id" uuid,
	"title" text NOT NULL,
	"slug" text NOT NULL UNIQUE,
	"views" integer DEFAULT 0 NOT NULL,
	"status" text DEFAULT 'processing' NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE INDEX "processing_job_pending_idx" ON "processing_job" ("available_at","created_at") WHERE "status" = 'pending';--> statement-breakpoint
CREATE INDEX "processing_job_processing_idx" ON "processing_job" ("locked_until") WHERE "status" = 'processing';--> statement-breakpoint
CREATE UNIQUE INDEX "processing_job_active_video_idx" ON "processing_job" ("video_id") WHERE "status" IN ('pending', 'processing');--> statement-breakpoint
ALTER TABLE "refresh_token" ADD CONSTRAINT "refresh_token_user_id_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "user"("id");--> statement-breakpoint
ALTER TABLE "stored_video" ADD CONSTRAINT "stored_video_video_id_video_id_fkey" FOREIGN KEY ("video_id") REFERENCES "video"("id");--> statement-breakpoint
ALTER TABLE "upload_session" ADD CONSTRAINT "upload_session_video_id_video_id_fkey" FOREIGN KEY ("video_id") REFERENCES "video"("id");--> statement-breakpoint
ALTER TABLE "video_asset" ADD CONSTRAINT "video_asset_video_id_video_id_fkey" FOREIGN KEY ("video_id") REFERENCES "video"("id");