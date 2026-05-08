import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { User, Task, Meeting, Group, Division, Objective } from '../../entities';
import { ApprovalGuard } from '../../common/guards/approval.guard';
import { RolesGuard } from '../../common/guards/roles.guard';

@Module({
  imports: [TypeOrmModule.forFeature([User, Task, Meeting, Group, Division, Objective])],
  controllers: [AdminController],
  providers: [AdminService, ApprovalGuard, RolesGuard],
  exports: [AdminService],
})
export class AdminModule {}
