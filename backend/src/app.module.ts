import { Module, OnModuleInit, Logger } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule, InjectRepository } from '@nestjs/typeorm';
import { ScheduleModule } from '@nestjs/schedule';
import { Repository } from 'typeorm';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { TasksModule } from './modules/tasks/tasks.module';
import { MeetingsModule } from './modules/meetings/meetings.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { UploadsModule } from './modules/uploads/uploads.module';
import { WechatModule } from './modules/wechat/wechat.module';
import { ApprovalsModule } from './modules/approvals/approvals.module';
import { ObjectivesModule } from './modules/objectives/objectives.module';
import { SpacesModule } from './modules/spaces/spaces.module';
import { AdminModule } from './modules/admin/admin.module';
import { User, Group, Division, ApprovalStatus, Position, RoleLevel } from './entities';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        host: config.get('DB_HOST', 'localhost'),
        port: 5432,
        username: 'app_user',
        password: config.get('DB_PASSWORD'),
        database: 'team_pm',
        entities: [__dirname + '/entities/**/*.entity{.ts,.js}'],
        synchronize: true,
      }),
    }),
    TypeOrmModule.forFeature([User, Group, Division]),
    ScheduleModule.forRoot(),
    AuthModule,
    UsersModule,
    TasksModule,
    MeetingsModule,
    NotificationsModule,
    UploadsModule,
    WechatModule,
    ApprovalsModule,
    ObjectivesModule,
    SpacesModule,
    AdminModule,
  ],
})
export class AppModule implements OnModuleInit {
  private readonly logger = new Logger(AppModule.name);

  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Group)
    private readonly groupRepo: Repository<Group>,
    @InjectRepository(Division)
    private readonly divisionRepo: Repository<Division>,
  ) {}

  async onModuleInit() {
    await this.migrateApproval();
    await this.migrateRoles();
    await this.sanitizeLeaders();
  }

  private async migrateApproval() {
    const cutoff = new Date('2026-05-09T00:00:00Z');
    const result = await this.userRepo
      .createQueryBuilder()
      .update(User)
      .set({ approvalStatus: ApprovalStatus.APPROVED })
      .where('approval_status = :pending AND created_at < :cutoff', {
        pending: ApprovalStatus.PENDING,
        cutoff,
      })
      .execute();
    if (result.affected && result.affected > 0) {
      this.logger.log(`Legacy users auto-approved: ${result.affected}`);
    }
  }

  private async migrateRoles() {
    const tagProjectManagers = await this.userRepo
      .createQueryBuilder()
      .update(User)
      .set({ position: Position.PROJECT_MANAGER })
      .where('role_level = 4 AND position IS NULL')
      .execute();
    if (tagProjectManagers.affected) {
      this.logger.log(`Tagged old project managers: ${tagProjectManagers.affected}`);
    }

    const bumpProjectManagers = await this.userRepo
      .createQueryBuilder()
      .update(User)
      .set({ roleLevel: 5 })
      .where('role_level = 4')
      .execute();
    if (bumpProjectManagers.affected) {
      this.logger.log(`Bumped project managers to level 5: ${bumpProjectManagers.affected}`);
    }

    const tagTeamCaptains = await this.userRepo
      .createQueryBuilder()
      .update(User)
      .set({ position: Position.TEAM_CAPTAIN })
      .where('role_level = 5 AND position IS NULL')
      .execute();
    if (tagTeamCaptains.affected) {
      this.logger.log(`Tagged old team captains: ${tagTeamCaptains.affected}`);
    }
  }

  private async sanitizeLeaders() {
    const [groups, divisions, users] = await Promise.all([
      this.groupRepo.find(),
      this.divisionRepo.find(),
      this.userRepo.find(),
    ]);
    const userById = new Map(users.map(u => [u.id, u]));

    let leaderCleans = 0;
    let roleBumps = 0;

    for (const g of groups) {
      const original = g.leaderIds || [];
      if (!original.length) continue;
      const kept = original.filter(id => {
        const u = userById.get(id);
        return u && (u.groupIds || []).includes(g.id);
      });
      if (kept.length !== original.length) {
        g.leaderIds = kept.length ? kept : null;
        await this.groupRepo.save(g);
        leaderCleans += original.length - kept.length;
      }
      for (const id of kept) {
        const u = userById.get(id);
        if (u && u.roleLevel < RoleLevel.GROUP_LEADER) {
          u.roleLevel = RoleLevel.GROUP_LEADER;
          await this.userRepo.save(u);
          roleBumps += 1;
        }
      }
    }

    for (const d of divisions) {
      const original = d.leaderIds || [];
      if (!original.length) continue;
      const kept = original.filter(id => {
        const u = userById.get(id);
        return u && (u.divisionIds || []).includes(d.id);
      });
      if (kept.length !== original.length) {
        d.leaderIds = kept.length ? kept : null;
        await this.divisionRepo.save(d);
        leaderCleans += original.length - kept.length;
      }
      for (const id of kept) {
        const u = userById.get(id);
        if (u && u.roleLevel < RoleLevel.GROUP_LEADER) {
          u.roleLevel = RoleLevel.GROUP_LEADER;
          await this.userRepo.save(u);
          roleBumps += 1;
        }
      }
    }

    if (leaderCleans || roleBumps) {
      this.logger.log(`Leader sanitization: removed ${leaderCleans} invalid, promoted ${roleBumps} to group leader`);
    }
  }
}
