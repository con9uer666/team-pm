import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ApprovalsController } from './approvals.controller';
import { ApprovalsService } from './approvals.service';
import { User, Group } from '../../entities';
import { NotificationsModule } from '../notifications/notifications.module';
import { ApprovalGuard } from '../../common/guards/approval.guard';
import { RolesGuard } from '../../common/guards/roles.guard';

@Module({
  imports: [TypeOrmModule.forFeature([User, Group]), NotificationsModule],
  controllers: [ApprovalsController],
  providers: [ApprovalsService, ApprovalGuard, RolesGuard],
  exports: [ApprovalsService],
})
export class ApprovalsModule {}
