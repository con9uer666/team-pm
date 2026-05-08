import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { Notification, User } from '../../entities';
import { WechatModule } from '../wechat/wechat.module';

@Module({
  imports: [TypeOrmModule.forFeature([Notification, User]), WechatModule],
  controllers: [NotificationsController],
  providers: [NotificationsService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
