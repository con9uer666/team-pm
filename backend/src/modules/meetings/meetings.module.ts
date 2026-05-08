import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MeetingsController } from './meetings.controller';
import { MeetingsService } from './meetings.service';
import { Meeting, MeetingParticipant, MeetingMinutes, User } from '../../entities';
import { NotificationsModule } from '../notifications/notifications.module';
import { WechatModule } from '../wechat/wechat.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Meeting, MeetingParticipant, MeetingMinutes, User]),
    NotificationsModule,
    WechatModule,
  ],
  controllers: [MeetingsController],
  providers: [MeetingsService],
})
export class MeetingsModule {}
