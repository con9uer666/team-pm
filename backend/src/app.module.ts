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
import { User, ApprovalStatus } from './entities';

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
    TypeOrmModule.forFeature([User]),
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
  ) {}

  async onModuleInit() {
    const result = await this.userRepo
      .createQueryBuilder()
      .update(User)
      .set({ approvalStatus: ApprovalStatus.APPROVED })
      .where('approval_status IS NULL')
      .execute();
    if (result.affected && result.affected > 0) {
      this.logger.log(`Legacy users auto-approved: ${result.affected}`);
    }
  }
}
