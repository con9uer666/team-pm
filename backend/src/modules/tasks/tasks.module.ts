import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TasksController } from './tasks.controller';
import { TasksService } from './tasks.service';
import { Task, TaskDependency, TaskReview, User, Division, Group, Objective } from '../../entities';
import { NotificationsModule } from '../notifications/notifications.module';
import { WechatModule } from '../wechat/wechat.module';
import { ApprovalGuard } from '../../common/guards/approval.guard';

@Module({
  imports: [
    TypeOrmModule.forFeature([Task, TaskDependency, TaskReview, User, Division, Group, Objective]),
    NotificationsModule,
    WechatModule,
  ],
  controllers: [TasksController],
  providers: [TasksService, ApprovalGuard],
  exports: [TasksService],
})
export class TasksModule {}
