import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { TasksService } from './tasks.service';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RoleLevel } from '../../entities';
import { IsString, IsOptional, IsDateString, IsInt, Min, Max, IsArray, IsUUID } from 'class-validator';

export class CreateTaskDto {
  @IsString()
  title: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsString()
  @IsOptional()
  content?: string;

  @IsUUID()
  @IsOptional()
  divisionId?: string;

  @IsUUID()
  @IsOptional()
  groupId?: string;

  @IsString()
  @IsOptional()
  completionRequirements?: string;

  @IsDateString()
  dueDate: string;

  @IsInt()
  @Min(0)
  @Max(2)
  @IsOptional()
  priority?: number;

  @IsArray()
  @IsUUID('4', { each: true })
  @IsOptional()
  dependencyIds?: string[];

  @IsUUID()
  @IsOptional()
  assigneeId?: string;
}

export class RejectTaskDto {
  @IsString()
  reason: string;
}

@Controller('api/tasks')
@UseGuards(AuthGuard('jwt'), RolesGuard)
export class TasksController {
  constructor(private readonly tasksService: TasksService) {}

  @Post()
  create(@Body() dto: CreateTaskDto, @CurrentUser() user: { id: string }) {
    return this.tasksService.create(dto, user.id);
  }

  @Get('my-scope')
  findMyScope(
    @CurrentUser() user: { id: string },
    @Query('status') status?: string,
    @Query('scope') scope?: 'own' | 'team' | 'all',
  ) {
    return this.tasksService.findMyScope(user.id, { status, scope });
  }

  @Get()
  findAll(
    @Query('weekYear') weekYear?: string,
    @Query('weekNumber') weekNumber?: string,
    @Query('status') status?: string,
    @Query('assigneeId') assigneeId?: string,
  ) {
    return this.tasksService.findAll({
      weekYear: weekYear ? +weekYear : undefined,
      weekNumber: weekNumber ? +weekNumber : undefined,
      status,
      assigneeId,
    });
  }

  @Get(':id')
  findById(@Param('id') id: string) {
    return this.tasksService.findById(id);
  }

  @Get(':id/dependencies')
  getDependencies(@Param('id') id: string) {
    return this.tasksService.getDependencies(id);
  }

  @Get(':id/reviews')
  getReviews(@Param('id') id: string) {
    return this.tasksService.getReviews(id);
  }

  @Get(':id/reviewable-types')
  getReviewableTypes(@Param('id') id: string, @CurrentUser() user: { id: string }) {
    return this.tasksService.getReviewableTypes(id, user.id);
  }

  @Patch(':id/review')
  review(
    @Param('id') id: string,
    @Body() dto: { action: 'approve' | 'reject'; reviewType: 'division' | 'group'; reason?: string },
    @CurrentUser() user: { id: string },
  ) {
    return this.tasksService.reviewTask(id, user.id, dto.action, dto.reviewType as any, dto.reason);
  }

  @Patch(':id/complete')
  complete(
    @Param('id') id: string,
    @Body() dto: { attachments: string[]; note?: string },
    @CurrentUser() user: { id: string },
  ) {
    return this.tasksService.complete(id, user.id, dto.attachments, dto.note);
  }

  @Patch(':id/verify-completion')
  @Roles(RoleLevel.GROUP_LEADER)
  verifyCompletion(
    @Param('id') id: string,
    @Body() dto: { action: 'approve' | 'reject'; reason?: string },
    @CurrentUser() user: { id: string },
  ) {
    return this.tasksService.verifyCompletion(id, user.id, dto.action, dto.reason);
  }

  @Patch(':id/resubmit')
  resubmit(
    @Param('id') id: string,
    @Body() dto: { title?: string; description?: string; dueDate?: string },
    @CurrentUser() user: { id: string },
  ) {
    return this.tasksService.resubmit(id, user.id, dto);
  }

  @Delete(':id')
  delete(@Param('id') id: string, @CurrentUser() user: { id: string }) {
    return this.tasksService.deleteTask(id, user.id);
  }
}
