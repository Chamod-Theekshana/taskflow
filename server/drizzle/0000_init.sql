CREATE SEQUENCE "public"."change_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1;--> statement-breakpoint
CREATE TABLE "devices" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"installation_id" varchar(64) NOT NULL,
	"platform" varchar(10) DEFAULT 'other' NOT NULL,
	"push_token" text,
	"app_version" varchar(32),
	"timezone" varchar(64),
	"local_reminders" boolean DEFAULT true NOT NULL,
	"last_pulled_seq" bigint DEFAULT 0 NOT NULL,
	"last_seen_at" timestamp with time zone DEFAULT now() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "devices_platform_check" CHECK ("devices"."platform" in ('android', 'ios', 'web', 'other'))
);
--> statement-breakpoint
CREATE TABLE "notifications" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"type" varchar(20) NOT NULL,
	"title" varchar(200) NOT NULL,
	"body" text DEFAULT '' NOT NULL,
	"data" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"task_id" uuid,
	"dedupe_key" varchar(200),
	"pushed_count" integer DEFAULT 0 NOT NULL,
	"read_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "notifications_type_check" CHECK ("notifications"."type" in ('reminder', 'digest', 'system', 'test'))
);
--> statement-breakpoint
CREATE TABLE "refresh_tokens" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"family_id" uuid NOT NULL,
	"token_hash" varchar(64) NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"revoked_at" timestamp with time zone,
	"replaced_by_id" uuid,
	"installation_id" varchar(64),
	"user_agent" varchar(400),
	"ip" varchar(64),
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "settings" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"notifications_enabled" boolean DEFAULT true NOT NULL,
	"daily_digest_enabled" boolean DEFAULT false NOT NULL,
	"daily_digest_time" varchar(5) DEFAULT '08:00' NOT NULL,
	"theme_mode" varchar(10) DEFAULT 'dark' NOT NULL,
	"default_priority" varchar(10) DEFAULT 'medium' NOT NULL,
	"daily_goal" integer DEFAULT 4 NOT NULL,
	"custom_categories" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"timezone" varchar(64) DEFAULT 'UTC' NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"change_seq" bigint DEFAULT nextval('change_seq') NOT NULL,
	CONSTRAINT "settings_theme_mode_check" CHECK ("settings"."theme_mode" in ('dark', 'light', 'system')),
	CONSTRAINT "settings_priority_check" CHECK ("settings"."default_priority" in ('low', 'medium', 'high')),
	CONSTRAINT "settings_daily_goal_check" CHECK ("settings"."daily_goal" between 1 and 20)
);
--> statement-breakpoint
CREATE TABLE "subtasks" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"task_id" uuid NOT NULL,
	"title" varchar(200) NOT NULL,
	"is_completed" boolean DEFAULT false NOT NULL,
	"position" integer DEFAULT 0 NOT NULL
);
--> statement-breakpoint
CREATE TABLE "tasks" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"title" varchar(200) NOT NULL,
	"description" text DEFAULT '' NOT NULL,
	"due_date" date NOT NULL,
	"due_time" varchar(5),
	"is_all_day" boolean DEFAULT false NOT NULL,
	"timezone" varchar(64) DEFAULT 'UTC' NOT NULL,
	"due_at" timestamp with time zone NOT NULL,
	"priority" varchar(10) DEFAULT 'medium' NOT NULL,
	"category" varchar(100) DEFAULT '' NOT NULL,
	"is_completed" boolean DEFAULT false NOT NULL,
	"completed_at" timestamp with time zone,
	"reminder" boolean DEFAULT false NOT NULL,
	"reminder_minutes" integer DEFAULT 15 NOT NULL,
	"remind_at" timestamp with time zone,
	"reminder_sent_at" timestamp with time zone,
	"repeat_rule" varchar(10) DEFAULT 'none' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	"server_updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"change_seq" bigint DEFAULT nextval('change_seq') NOT NULL,
	CONSTRAINT "tasks_priority_check" CHECK ("tasks"."priority" in ('low', 'medium', 'high')),
	CONSTRAINT "tasks_repeat_rule_check" CHECK ("tasks"."repeat_rule" in ('none', 'daily', 'weekdays', 'weekly', 'monthly')),
	CONSTRAINT "tasks_reminder_minutes_check" CHECK ("tasks"."reminder_minutes" between 0 and 10080)
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"email" varchar(254) NOT NULL,
	"full_name" varchar(120) NOT NULL,
	"password_hash" text NOT NULL,
	"password_changed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "devices" ADD CONSTRAINT "devices_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_task_id_tasks_id_fk" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "settings" ADD CONSTRAINT "settings_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "subtasks" ADD CONSTRAINT "subtasks_task_id_tasks_id_fk" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "devices_user_installation_key" ON "devices" USING btree ("user_id","installation_id");--> statement-breakpoint
CREATE UNIQUE INDEX "devices_push_token_key" ON "devices" USING btree ("push_token") WHERE "devices"."push_token" is not null;--> statement-breakpoint
CREATE INDEX "notifications_user_created_idx" ON "notifications" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "notifications_dedupe_key" ON "notifications" USING btree ("dedupe_key");--> statement-breakpoint
CREATE UNIQUE INDEX "refresh_tokens_token_hash_key" ON "refresh_tokens" USING btree ("token_hash");--> statement-breakpoint
CREATE INDEX "refresh_tokens_user_idx" ON "refresh_tokens" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "refresh_tokens_family_idx" ON "refresh_tokens" USING btree ("family_id");--> statement-breakpoint
CREATE INDEX "subtasks_task_idx" ON "subtasks" USING btree ("task_id","position");--> statement-breakpoint
CREATE INDEX "tasks_user_change_seq_idx" ON "tasks" USING btree ("user_id","change_seq");--> statement-breakpoint
CREATE INDEX "tasks_user_due_idx" ON "tasks" USING btree ("user_id","due_at");--> statement-breakpoint
CREATE INDEX "tasks_pending_reminder_idx" ON "tasks" USING btree ("remind_at") WHERE "tasks"."reminder" = true and "tasks"."is_completed" = false and "tasks"."deleted_at" is null and "tasks"."reminder_sent_at" is null;--> statement-breakpoint
CREATE UNIQUE INDEX "users_email_key" ON "users" USING btree ("email");