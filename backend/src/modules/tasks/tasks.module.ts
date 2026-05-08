import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TasksController } from './tasks.controller';
import { TasksService } from './tasks.service';
import { Task, TaskDependency, TaskReview, User, Division, Group } from '../../entities';
import { NotificationsModule } from '../notifications/notifications.module';
import { WechatModule } from '../wechat/wechat.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Task, TaskDependency, TaskReview, User, Division, Group]),
    NotificationsModule,
    WechatModule,
  ],
  controllers: [TasksController],
  providers: [TasksService],
  exports: [TasksService],
})
export class TasksModule {}
