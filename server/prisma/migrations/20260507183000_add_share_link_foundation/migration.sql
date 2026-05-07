ALTER TABLE "users"
  ADD COLUMN IF NOT EXISTS "profile_share_code" TEXT,
  ADD COLUMN IF NOT EXISTS "profile_share_qr_code_url" TEXT;

ALTER TABLE "squads"
  ADD COLUMN IF NOT EXISTS "share_code" TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS "users_profile_share_code_key" ON "users"("profile_share_code");
CREATE UNIQUE INDEX IF NOT EXISTS "squads_share_code_key" ON "squads"("share_code");

CREATE TABLE IF NOT EXISTS "share_links" (
  "id" TEXT NOT NULL,
  "code" TEXT NOT NULL,
  "target_type" TEXT NOT NULL,
  "target_id" TEXT NOT NULL,
  "canonical_url" TEXT NOT NULL,
  "deep_link" TEXT NOT NULL,
  "fallback_url" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "subtitle" TEXT,
  "image_url" TEXT,
  "poster_url" TEXT,
  "preview_type" TEXT NOT NULL,
  "visibility" TEXT NOT NULL DEFAULT 'public',
  "status" TEXT NOT NULL DEFAULT 'active',
  "expires_at" TIMESTAMP(3),
  "max_uses" INTEGER,
  "used_count" INTEGER NOT NULL DEFAULT 0,
  "created_by" TEXT,
  "reward_rule_id" TEXT,
  "metadata" JSONB,
  "scan_count" INTEGER NOT NULL DEFAULT 0,
  "click_count" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "share_links_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "share_links_code_key" ON "share_links"("code");
CREATE INDEX IF NOT EXISTS "share_links_target_type_target_id_idx" ON "share_links"("target_type", "target_id");
CREATE INDEX IF NOT EXISTS "share_links_status_idx" ON "share_links"("status");
CREATE INDEX IF NOT EXISTS "share_links_visibility_idx" ON "share_links"("visibility");
CREATE INDEX IF NOT EXISTS "share_links_created_by_idx" ON "share_links"("created_by");
CREATE INDEX IF NOT EXISTS "share_links_expires_at_idx" ON "share_links"("expires_at");

CREATE TABLE IF NOT EXISTS "share_link_events" (
  "id" TEXT NOT NULL,
  "link_id" TEXT NOT NULL,
  "event_type" TEXT NOT NULL,
  "channel" TEXT,
  "user_id" TEXT,
  "anonymous_id" TEXT,
  "platform" TEXT NOT NULL,
  "user_agent" TEXT,
  "ip_hash" TEXT,
  "referrer" TEXT,
  "metadata" JSONB,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "share_link_events_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "share_link_events_link_id_idx" ON "share_link_events"("link_id");
CREATE INDEX IF NOT EXISTS "share_link_events_event_type_idx" ON "share_link_events"("event_type");
CREATE INDEX IF NOT EXISTS "share_link_events_channel_idx" ON "share_link_events"("channel");
CREATE INDEX IF NOT EXISTS "share_link_events_user_id_idx" ON "share_link_events"("user_id");
CREATE INDEX IF NOT EXISTS "share_link_events_anonymous_id_idx" ON "share_link_events"("anonymous_id");
CREATE INDEX IF NOT EXISTS "share_link_events_created_at_idx" ON "share_link_events"("created_at");

CREATE TABLE IF NOT EXISTS "invite_referrals" (
  "id" TEXT NOT NULL,
  "link_id" TEXT NOT NULL,
  "inviter_user_id" TEXT NOT NULL,
  "invitee_user_id" TEXT,
  "squad_id" TEXT,
  "reward_status" TEXT NOT NULL DEFAULT 'pending',
  "reward_type" TEXT,
  "reward_payload" JSONB,
  "qualified_at" TIMESTAMP(3),
  "granted_at" TIMESTAMP(3),
  "metadata" JSONB,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "invite_referrals_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "invite_referrals_link_id_idx" ON "invite_referrals"("link_id");
CREATE INDEX IF NOT EXISTS "invite_referrals_inviter_user_id_idx" ON "invite_referrals"("inviter_user_id");
CREATE INDEX IF NOT EXISTS "invite_referrals_invitee_user_id_idx" ON "invite_referrals"("invitee_user_id");
CREATE INDEX IF NOT EXISTS "invite_referrals_squad_id_idx" ON "invite_referrals"("squad_id");
CREATE INDEX IF NOT EXISTS "invite_referrals_reward_status_idx" ON "invite_referrals"("reward_status");
CREATE INDEX IF NOT EXISTS "invite_referrals_created_at_idx" ON "invite_referrals"("created_at");

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'share_links_created_by_fkey'
  ) THEN
    ALTER TABLE "share_links"
      ADD CONSTRAINT "share_links_created_by_fkey"
      FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'share_link_events_link_id_fkey'
  ) THEN
    ALTER TABLE "share_link_events"
      ADD CONSTRAINT "share_link_events_link_id_fkey"
      FOREIGN KEY ("link_id") REFERENCES "share_links"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'share_link_events_user_id_fkey'
  ) THEN
    ALTER TABLE "share_link_events"
      ADD CONSTRAINT "share_link_events_user_id_fkey"
      FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'invite_referrals_link_id_fkey'
  ) THEN
    ALTER TABLE "invite_referrals"
      ADD CONSTRAINT "invite_referrals_link_id_fkey"
      FOREIGN KEY ("link_id") REFERENCES "share_links"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'invite_referrals_inviter_user_id_fkey'
  ) THEN
    ALTER TABLE "invite_referrals"
      ADD CONSTRAINT "invite_referrals_inviter_user_id_fkey"
      FOREIGN KEY ("inviter_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'invite_referrals_invitee_user_id_fkey'
  ) THEN
    ALTER TABLE "invite_referrals"
      ADD CONSTRAINT "invite_referrals_invitee_user_id_fkey"
      FOREIGN KEY ("invitee_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'invite_referrals_squad_id_fkey'
  ) THEN
    ALTER TABLE "invite_referrals"
      ADD CONSTRAINT "invite_referrals_squad_id_fkey"
      FOREIGN KEY ("squad_id") REFERENCES "squads"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;
