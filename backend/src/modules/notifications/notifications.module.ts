import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { Notification, User } from '../../entities';
import { WechatModule } from '../wechat/wechat.module';
import { ApprovalGuard } from '../../common/guards/approval.guard';

@Module({
  imports: [TypeOrmModule.forFeature([Notification, User]), WechatModule],
  controllers: [NotificationsController],
  providers: [NotificationsService, ApprovalGuard],
  exports: [NotificationsService],
})
export class NotificationsModule {}
