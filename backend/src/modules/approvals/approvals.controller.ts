import { Controller, Get, Patch, Param, Body, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { IsArray, IsEnum, IsInt, IsOptional, IsString, IsUUID, MinLength, MaxLength, Min, Max } from 'class-validator';
import { ApprovalsService } from './approvals.service';
import { ApprovalGuard } from '../../common/guards/approval.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { AllowPending } from '../../common/decorators/allow-pending.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RoleLevel, Position } from '../../entities';

export class ApproveDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(6)
  roleLevel?: number;

  @IsOptional()
  @IsEnum(Position)
  position?: Position | null;

  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  groupIds?: string[];

  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  divisionIds?: string[];
}

export class RejectDto {
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  reason: string;
}

@Controller('api/approvals')
@UseGuards(AuthGuard('jwt'), ApprovalGuard, RolesGuard)
export class ApprovalsController {
  constructor(private readonly approvals: ApprovalsService) {}

  @Get('my-status')
  @AllowPending()
  getMyStatus(@CurrentUser() user: { id: string }) {
    return this.approvals.getMyStatus(user.id);
  }

  @Get('pending')
  @Roles(RoleLevel.GROUP_LEADER)
  listPending(@CurrentUser() user: { id: string }) {
    return this.approvals.listPending(user.id);
  }

  @Patch(':userId/approve')
  @Roles(RoleLevel.GROUP_LEADER)
  approve(
    @Param('userId') userId: string,
    @Body() dto: ApproveDto,
    @CurrentUser() user: { id: string },
  ) {
    return this.approvals.approve(userId, user.id, dto);
  }

  @Patch(':userId/reject')
  @Roles(RoleLevel.GROUP_LEADER)
  reject(
    @Param('userId') userId: string,
    @Body() dto: RejectDto,
    @CurrentUser() user: { id: string },
  ) {
    return this.approvals.reject(userId, user.id, dto.reason);
  }
}
