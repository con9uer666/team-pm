import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * 一次性数据修复：原本在 AppModule.onModuleInit 里硬编码、每次启动都跑一遍。
 * 搬到 migration 后只跑一次，跑完写进 migrations 表，再也不重复。
 *
 * 1. migrateApproval - 2026-05-09 之前注册的旧用户自动批准
 * 2. migrateRoles - 旧 role_level=4 升 5 并打 project_manager 职位标签 / 旧 5 级补 team_captain 标签
 * 3. sanitizeLeaders - 清掉不在小组/兵种里却挂着 leader 身份的脏数据；剩余 leader 至少提升到 group_leader
 */
export class DataMigrationFromBootstrap1715900100000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    // ---- 1. migrateApproval ----
    await queryRunner.query(`
      UPDATE "users"
      SET "approval_status" = 'approved'
      WHERE "approval_status" = 'pending'
        AND "created_at" < '2026-05-09T00:00:00Z'
    `);

    // ---- 2. migrateRoles ----
    // 旧 role_level=4 (PROJECT_MANAGER 的老定义) 没贴 position 标签的，贴 project_manager
    await queryRunner.query(`
      UPDATE "users"
      SET "position" = 'project_manager'
      WHERE "role_level" = 4 AND "position" IS NULL
    `);
    // 再把所有旧 role_level=4 升到 5（与新枚举对齐）
    await queryRunner.query(`
      UPDATE "users"
      SET "role_level" = 5
      WHERE "role_level" = 4
    `);
    // 已经是 role_level=5 但没贴 position 的，补 team_captain
    await queryRunner.query(`
      UPDATE "users"
      SET "position" = 'team_captain'
      WHERE "role_level" = 5 AND "position" IS NULL
    `);

    // ---- 3. sanitizeLeaders ----
    // 用纯 SQL 完成等价逻辑。group_ids / division_ids / leader_ids 都是 simple-array (text, 逗号分隔)
    //
    // 步骤：
    //  a) 对 groups 表：把 leader_ids 里"已不在 users.group_ids 中"的 id 剔除
    //  b) 对 divisions 表：同上
    //  c) leader_ids 剔完后变空的，置 NULL
    //  d) 剩下的 leader 如果 role_level < 3 (GROUP_LEADER)，升到 3

    // 用 PL/pgSQL 块跑一次性脚本，避免在多张表里写一堆 string_to_array
    await queryRunner.query(`
      DO $$
      DECLARE
        g RECORD;
        d RECORD;
        leader_id text;
        kept text[];
        original text[];
      BEGIN
        -- groups
        FOR g IN SELECT id, leader_ids FROM "groups" WHERE leader_ids IS NOT NULL AND leader_ids <> '' LOOP
          original := string_to_array(g.leader_ids, ',');
          kept := ARRAY[]::text[];
          FOREACH leader_id IN ARRAY original LOOP
            IF EXISTS (
              SELECT 1 FROM "users"
              WHERE id::text = leader_id
                AND group_ids IS NOT NULL
                AND g.id::text = ANY(string_to_array(group_ids, ','))
            ) THEN
              kept := array_append(kept, leader_id);
            END IF;
          END LOOP;
          IF array_length(kept, 1) IS NULL THEN
            UPDATE "groups" SET leader_ids = NULL WHERE id = g.id;
          ELSIF array_length(kept, 1) < array_length(original, 1) THEN
            UPDATE "groups" SET leader_ids = array_to_string(kept, ',') WHERE id = g.id;
          END IF;
          -- 给剩下的 leader 升角色
          FOREACH leader_id IN ARRAY kept LOOP
            UPDATE "users" SET role_level = 3
              WHERE id::text = leader_id AND role_level < 3;
          END LOOP;
        END LOOP;

        -- divisions（同样逻辑）
        FOR d IN SELECT id, leader_ids FROM "divisions" WHERE leader_ids IS NOT NULL AND leader_ids <> '' LOOP
          original := string_to_array(d.leader_ids, ',');
          kept := ARRAY[]::text[];
          FOREACH leader_id IN ARRAY original LOOP
            IF EXISTS (
              SELECT 1 FROM "users"
              WHERE id::text = leader_id
                AND division_ids IS NOT NULL
                AND d.id::text = ANY(string_to_array(division_ids, ','))
            ) THEN
              kept := array_append(kept, leader_id);
            END IF;
          END LOOP;
          IF array_length(kept, 1) IS NULL THEN
            UPDATE "divisions" SET leader_ids = NULL WHERE id = d.id;
          ELSIF array_length(kept, 1) < array_length(original, 1) THEN
            UPDATE "divisions" SET leader_ids = array_to_string(kept, ',') WHERE id = d.id;
          END IF;
          FOREACH leader_id IN ARRAY kept LOOP
            UPDATE "users" SET role_level = 3
              WHERE id::text = leader_id AND role_level < 3;
          END LOOP;
        END LOOP;
      END $$;
    `);
  }

  public async down(_queryRunner: QueryRunner): Promise<void> {
    // 数据修复不可逆：旧 role_level=4 与新 role_level=5 已经合并，无法区分；
    // 已批准的用户无法回滚成 pending。down 留空即可。
  }
}
