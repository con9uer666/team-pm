import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ScheduleModule } from '@nestjs/schedule';
import * as path from 'path';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { TasksModule } from './modules/tasks/tasks.module';
import { MeetingsModule } from './modules/meetings/meetings.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { WechatModule } from './modules/wechat/wechat.module';
import { ApprovalsModule } from './modules/approvals/approvals.module';
import { ObjectivesModule } from './modules/objectives/objectives.module';
import { SpacesModule } from './modules/spaces/spaces.module';
import { AdminModule } from './modules/admin/admin.module';
import { AttendanceModule } from './modules/attendance/attendance.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        host: config.get('DB_HOST', 'localhost'),
        port: Number(config.get('DB_PORT', 5432)),
        username: config.get('DB_USER', 'app_user'),
        password: config.get('DB_PASSWORD'),
        database: config.get('DB_NAME', 'team_pm'),
        entities: [path.join(__dirname, 'entities', '**', '*.entity.{ts,js}')],
        migrations: [path.join(__dirname, 'migrations', '*.{ts,js}')],
        migrationsTableName: 'migrations',
        migrationsRun: true,
        synchronize: false,
        logging: config.get('DB_LOGGING') === 'true',
      }),
    }),
    ScheduleModule.forRoot(),
    AuthModule,
    UsersModule,
    TasksModule,
    MeetingsModule,
    NotificationsModule,
    WechatModule,
    ApprovalsModule,
    ObjectivesModule,
    SpacesModule,
    AdminModule,
    AttendanceModule,
  ],
})
export class AppModule {}
