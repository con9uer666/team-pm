# 数据库迁移说明

## 它是什么

`backend/src/migrations/` 目录下的文件，**版本化记录数据库表结构和数据修复脚本**。替代原本启动时跑的 `synchronize: true` + `AppModule.onModuleInit` 硬编码迁移。

每次后端启动会自动跑没跑过的 migration，跑过的写进 `migrations` 表里不再重复。

---

## 日常开发：怎么加新表 / 改字段

1. 改 `backend/src/entities/xxx.entity.ts`（加字段、新建 entity 等）
2. 手写一个 migration 文件，命名 `<timestamp>-<描述>.ts`，参考已有的两个文件
3. 跑 `cd backend && npm run migration:run` 在本地数据库执行（确保 `.env` 配置好 DB_PASSWORD）
4. 提交代码（包括 migration 文件）

> 不要用 `npm run migration:generate` 自动生成——需要本地连库且容易和现状对不上。手写更可控。

回滚一条 migration：`npm run migration:revert`

---

## 服务器首次切换到 migration 体系

服务器上**已经有数据**（用户/任务/会议）。当前 schema 是 `synchronize` 生成的，没有 `migrations` 表记录。

第一次跑代码前需要手动**标记基线**，告诉 TypeORM"这两条 migration 我已经手动跑过了"，避免重复执行。

### 步骤

SSH 到服务器：

```bash
ssh ubuntu@49.233.180.22
cd /opt/app

# 1. 拉最新代码
git pull

# 2. 进入 postgres 容器，先备份再标记
docker exec -t app-postgres-1 pg_dump -U app_user team_pm > /tmp/team_pm_backup_$(date +%Y%m%d).sql

# 3. 在 postgres 里手工创建 migrations 表并插入两条已执行记录
docker exec -i app-postgres-1 psql -U app_user -d team_pm <<'SQL'
CREATE TABLE IF NOT EXISTS "migrations" (
  "id" SERIAL PRIMARY KEY,
  "timestamp" bigint NOT NULL,
  "name" character varying NOT NULL
);

INSERT INTO "migrations" ("timestamp", "name")
VALUES (1715900000000, 'InitSchema1715900000000')
ON CONFLICT DO NOTHING;

INSERT INTO "migrations" ("timestamp", "name")
VALUES (1715900100000, 'DataMigrationFromBootstrap1715900100000')
ON CONFLICT DO NOTHING;

SELECT * FROM "migrations";
SQL

# 4. 重启后端镜像
docker compose up -d --build
```

预期结果：
- `migrations` 表里有两条记录
- 后端日志显示 `No migrations are pending`，表结构和数据**完全不变**

### 如果忘了标记 baseline 直接 `docker compose up -d --build` 了会发生什么？

实际上**也不会出事**：
- `InitSchema` 全用 `CREATE TABLE IF NOT EXISTS` / `CREATE TYPE` 配 `DO $$ EXCEPTION`，已有表/类型不会重建
- `DataMigrationFromBootstrap` 用 `UPDATE WHERE` 条件过滤，已修复的数据不会再次被改

唯一的副作用是这两条会被记进 `migrations` 表，后续不会重跑。所以"忘了 baseline"等价于"直接让代码自己执行了一次幂等操作"。

但**建议还是先备份再操作**——养成习惯。

---

## 本地从零跑起来

```bash
cd backend
cp .env.example .env
# 编辑 .env 填 DB_PASSWORD

# 起一个本地 postgres（任选其一）
# - Docker: docker run -d --name pg-local -e POSTGRES_USER=app_user -e POSTGRES_PASSWORD=xxx -e POSTGRES_DB=team_pm -p 5432:5432 postgres:16
# - 系统安装: brew install postgresql && brew services start postgresql

npm install
npm run start:dev
# migration 自动跑完，表全部建出来
```

---

## 重要的约定

1. **永远不要再开启 `synchronize: true`**（已在 [app.module.ts](src/app.module.ts) 关闭）
2. **不要修改已合并的 migration 文件**，永远新建下一条
3. **migration 文件名时间戳必须严格递增**，按文件名排序就是执行顺序
4. 每条 migration 的 `down()` 尽量写完整，便于回滚；但纯数据修复（如本次的 `DataMigrationFromBootstrap`）`down()` 可以留空并加注释
