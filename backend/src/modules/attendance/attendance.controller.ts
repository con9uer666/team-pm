import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AttendanceService } from './attendance.service';
import { ApprovalGuard } from '../../common/guards/approval.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { IsNumber, IsOptional, IsString, IsBoolean, Min, Max, IsInt } from 'class-validator';

export class ClockDto {
  @IsNumber()
  lat: number;

  @IsNumber()
  lng: number;

  @IsNumber()
  @IsOptional()
  accuracy?: number;

  @IsString()
  @IsOptional()
  address?: string;
}

export class CreateFenceDto {
  @IsString()
  name: string;

  @IsNumber()
  centerLat: number;

  @IsNumber()
  centerLng: number;

  @IsInt()
  @Min(10)
  @Max(5000)
  radius: number;

  @IsBoolean()
  @IsOptional()
  enabled?: boolean;
}

export class UpdateFenceDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsNumber()
  @IsOptional()
  centerLat?: number;

  @IsNumber()
  @IsOptional()
  centerLng?: number;

  @IsInt()
  @Min(10)
  @Max(5000)
  @IsOptional()
  radius?: number;

  @IsBoolean()
  @IsOptional()
  enabled?: boolean;
}

@Controller('api/attendance')
@UseGuards(AuthGuard('jwt'), ApprovalGuard, RolesGuard)
export class AttendanceController {
  constructor(private readonly service: AttendanceService) {}

  @Post('clock-in')
  clockIn(@Body() dto: ClockDto, @CurrentUser() user: { id: string }) {
    return this.service.clockIn(user.id, dto);
  }

  @Post('clock-out')
  clockOut(@Body() dto: ClockDto, @CurrentUser() user: { id: string }) {
    return this.service.clockOut(user.id, dto);
  }

  @Get('active')
  async getActive(@CurrentUser() user: { id: string }) {
    return (await this.service.findActiveSession(user.id)) || null;
  }

  @Get('my')
  getMy(
    @CurrentUser() user: { id: string },
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('limit') limit?: string,
  ) {
    return this.service.getMySessions(user.id, {
      from,
      to,
      limit: limit ? +limit : undefined,
    });
  }

  @Get('stats')
  getStats(
    @Query('scope') scope?: 'week' | 'month' | 'all',
    @Query('groupId') groupId?: string,
    @Query('divisionId') divisionId?: string,
  ) {
    return this.service.getStats({ scope, groupId, divisionId });
  }

  @Get('sessions')
  getUserSessions(
    @Query('userId') userId: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('limit') limit?: string,
  ) {
    return this.service.getUserSessions(userId, {
      from,
      to,
      limit: limit ? +limit : undefined,
    });
  }

  @Get('fences')
  listFences() {
    return this.service.listFences();
  }

  @Post('fences')
  createFence(@Body() dto: CreateFenceDto, @CurrentUser() user: { id: string }) {
    return this.service.createFence(user.id, dto);
  }

  @Patch('fences/:id')
  updateFence(
    @Param('id') id: string,
    @Body() dto: UpdateFenceDto,
    @CurrentUser() user: { id: string },
  ) {
    return this.service.updateFence(user.id, id, dto);
  }

  @Delete('fences/:id')
  removeFence(@Param('id') id: string, @CurrentUser() user: { id: string }) {
    return this.service.removeFence(user.id, id);
  }
}
