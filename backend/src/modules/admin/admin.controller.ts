import { Controller, Get, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AdminService } from './admin.service';
import { ApprovalGuard } from '../../common/guards/approval.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { RoleLevel } from '../../entities';

@Controller('api/admin')
@UseGuards(AuthGuard('jwt'), ApprovalGuard, RolesGuard)
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get('dashboard/stats')
  @Roles(RoleLevel.PROJECT_MANAGER)
  getDashboardStats() {
    return this.admin.getDashboardStats();
  }
}
