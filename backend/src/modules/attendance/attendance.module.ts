import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AttendanceController } from './attendance.controller';
import { AttendanceService } from './attendance.service';
import {
  AttendanceFence,
  AttendanceSession,
  User,
  Group,
  Division,
} from '../../entities';
import { ApprovalGuard } from '../../common/guards/approval.guard';
import { RolesGuard } from '../../common/guards/roles.guard';

@Module({
  imports: [
    TypeOrmModule.forFeature([AttendanceFence, AttendanceSession, User, Group, Division]),
  ],
  controllers: [AttendanceController],
  providers: [AttendanceService, ApprovalGuard, RolesGuard],
  exports: [AttendanceService],
})
export class AttendanceModule {}
