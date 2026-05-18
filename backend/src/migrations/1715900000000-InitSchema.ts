import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * 基线 schema：当前生产数据库已有的全部表结构。
 * 全部 CREATE TABLE IF NOT EXISTS / CREATE TYPE IF NOT EXISTS，所以：
 *   - 服务器（已有 synchronize 生成的表）跑这条 migration 不会重建表、不会丢数据
 *   - 新环境（本地 / 全新部署）跑这条会从零建出与现状一致的 schema
 *
 * 后续任何 schema 变更都要新建独立的 migration 文件，禁止再依赖 synchronize。
 */
export class InitSchema1715900000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    // ============ enum 类型 ============
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "meetings_scope_enum" AS ENUM ('group', 'division', 'team');
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    `);
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "meetings_status_enum" AS ENUM ('scheduled', 'in_progress', 'ended', 'cancelled');
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    `);
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "meeting_participants_attendance_status_enum" AS ENUM ('pending', 'present', 'late', 'absent');
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    `);
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "notifications_type_enum" AS ENUM (
          'task_approved', 'task_rejected', 'task_overdue', 'task_assigned', 'task_appealed',
          'meeting_scheduled', 'meeting_reminder', 'meeting_started', 'general'
        );
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    `);

    // ============ users ============
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "users" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "username" character varying(50) NOT NULL,
        "password_hash" character varying NOT NULL,
        "real_name" character varying(50) NOT NULL,
        "role_level" integer NOT NULL,
        "position" character varying(32),
        "avatarUrl" character varying(500),
        "phone" character varying(20),
        "wechat_work_id" character varying(100),
        "group_ids" text,
        "division_ids" text,
        "status" character varying(20) NOT NULL DEFAULT 'active',
        "email" character varying,
        "session_token" character varying,
        "is_super_admin" boolean NOT NULL DEFAULT false,
        "approval_status" character varying(20) NOT NULL DEFAULT 'pending',
        "approval_reviewer_id" uuid,
        "approval_reviewed_at" TIMESTAMP,
        "approval_reject_reason" text,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_users_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_users_username" UNIQUE ("username"),
        CONSTRAINT "UQ_users_email" UNIQUE ("email")
      )
    `);

    // ============ groups ============
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "groups" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "name" character varying(100) NOT NULL,
        "leader_ids" text,
        "division_id" character varying,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_groups_id" PRIMARY KEY ("id")
      )
    `);

    // ============ divisions ============
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "divisions" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "name" character varying(100) NOT NULL,
        "leader_ids" text,
        "description" text,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_divisions_id" PRIMARY KEY ("id")
      )
    `);

    // ============ tasks ============
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "tasks" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "title" character varying(200) NOT NULL,
        "description" text,
        "content" text,
        "division_id" uuid,
        "group_id" uuid,
        "objective_id" uuid,
        "completion_requirements" text,
        "creator_id" character varying NOT NULL,
        "assignee_id" character varying NOT NULL,
        "status" character varying(20) NOT NULL DEFAULT 'pending_review',
        "priority" integer NOT NULL DEFAULT 0,
        "week_year" integer NOT NULL,
        "week_number" integer NOT NULL,
        "due_date" TIMESTAMP NOT NULL,
        "completed_at" TIMESTAMP,
        "completion_attachments" text,
        "completion_note" text,
        "overdue_minutes" integer NOT NULL DEFAULT 0,
        "rejection_reason" text,
        "rejected_by" uuid,
        "reviewed_by" uuid,
        "reviewed_at" TIMESTAMP,
        "reminded_at" TIMESTAMP,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_tasks_id" PRIMARY KEY ("id")
      )
    `);

    // ============ task_reviews ============
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "task_reviews" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "task_id" uuid NOT NULL,
        "reviewer_id" uuid NOT NULL,
        "review_type" character varying(20) NOT NULL,
        "status" character varying(20) NOT NULL,
        "rejection_reason" text,
        "reviewed_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_task_reviews_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_task_reviews_task_review_type" UNIQUE ("task_id", "review_type")
      )
    `);

    // ============ task_dependencies ============
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "task_dependencies" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "task_id" uuid NOT NULL,
        "depends_on_task_id" uuid NOT NULL,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_task_dependencies_id" PRIMARY KEY ("id")
      )
    `);

    // ============ meetings ============
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "meetings" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "title" character varying(200) NOT NULL,
        "description" text,
        "organizer_id" uuid NOT NULL,
        "group_id" uuid,
        "division_id" uuid,
        "scope" "meetings_scope_enum" NOT NULL,
        "location" character varying(200),
        "start_time" TIMESTAMP NOT NULL,
        "end_time" TIMESTAMP NOT NULL,
        "status" "meetings_status_enum" NOT NULL DEFAULT 'scheduled',
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_meetings_id" PRIMARY KEY ("id")
      )
    `);

    // ============ meeting_participants ============
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "meeting_participants" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "meeting_id" uuid NOT NULL,
        "user_id" uuid NOT NULL,
        "attendance_status" "meeting_participants_attendance_status_enum" NOT NULL DEFAULT 'pending',
        "check_in_time" TIMESTAMP,
        CONSTRAINT "PK_meeting_participants_id" PRIMARY KEY ("id")
      )
    `);

    // ============ meeting_minutes ============
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "meeting_minutes" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "meeting_id" uuid NOT NULL,
        "content" text NOT NULL,
        "recorder_id" uuid NOT NULL,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP,
        CONSTRAINT "PK_meeting_minutes_id" PRIMARY KEY ("id")
      )
    `);

    // ============ notifications ============
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "notifications" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "type" "notifications_type_enum" NOT NULL DEFAULT 'general',
        "title" character varying(200) NOT NULL,
        "content" text,
        "related_id" uuid,
        "is_read" boolean NOT NULL DEFAULT false,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_notifications_id" PRIMARY KEY ("id")
      )
    `);

    // ============ objectives ============
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "objectives" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "title" character varying(200) NOT NULL,
        "description" text,
        "scope" character varying(20) NOT NULL,
        "division_id" uuid,
        "group_id" uuid,
        "due_date" TIMESTAMP NOT NULL,
        "status" character varying(20) NOT NULL DEFAULT 'active',
        "manually_completed" boolean NOT NULL DEFAULT false,
        "created_by_id" uuid NOT NULL,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_objectives_id" PRIMARY KEY ("id")
      )
    `);

    // ============ attendance_fences ============
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "attendance_fences" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "name" character varying(100) NOT NULL,
        "center_lat" double precision NOT NULL,
        "center_lng" double precision NOT NULL,
        "radius" integer NOT NULL,
        "enabled" boolean NOT NULL DEFAULT true,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_attendance_fences_id" PRIMARY KEY ("id")
      )
    `);

    // ============ attendance_sessions ============
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "attendance_sessions" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "clock_in_at" TIMESTAMP WITH TIME ZONE NOT NULL,
        "clock_in_lat" double precision NOT NULL,
        "clock_in_lng" double precision NOT NULL,
        "clock_in_address" text,
        "clock_in_fence_id" uuid,
        "clock_out_at" TIMESTAMP WITH TIME ZONE,
        "clock_out_lat" double precision,
        "clock_out_lng" double precision,
        "clock_out_address" text,
        "status" character varying(20) NOT NULL DEFAULT 'active',
        "duration_minutes" integer NOT NULL DEFAULT 0,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_attendance_sessions_id" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_attendance_sessions_user_status"
        ON "attendance_sessions" ("user_id", "status")
    `);

    // uuid_generate_v4() 依赖 uuid-ossp 扩展。生产已经在用，且 PG 自带。
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "attendance_sessions"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "attendance_fences"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "objectives"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "notifications"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "meeting_minutes"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "meeting_participants"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "meetings"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "task_dependencies"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "task_reviews"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "tasks"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "divisions"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "groups"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "users"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "notifications_type_enum"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "meeting_participants_attendance_status_enum"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "meetings_status_enum"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "meetings_scope_enum"`);
  }
}
