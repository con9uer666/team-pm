import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MeetingsController } from './meetings.controller';
import { MeetingsService } from './meetings.service';
import { Meeting, MeetingParticipant, MeetingMinutes, User } from '../../entities';

@Module({
  imports: [TypeOrmModule.forFeature([Meeting, MeetingParticipant, MeetingMinutes, User])],
  controllers: [MeetingsController],
  providers: [MeetingsService],
})
export class MeetingsModule {}
