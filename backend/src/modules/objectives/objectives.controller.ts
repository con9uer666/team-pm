import { Controller, Get, Post, Patch, Delete, Param, Body, Query, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import {
  IsString,
  IsOptional,
  IsUUID,
  IsEnum,
  IsDateString,
  MinLength,
  MaxLength,
} from 'class-validator';
import { ObjectivesService } from './objectives.service';
import { ApprovalGuard } from '../../common/guards/approval.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ObjectiveScope, ObjectiveStatus } from '../../entities';

export class CreateObjectiveDto {
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  title: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @IsEnum(ObjectiveScope)
  scope: ObjectiveScope;

  @IsOptional()
  @IsUUID('4')
  divisionId?: string;

  @IsOptional()
  @IsUUID('4')
  groupId?: string;

  @IsDateString()
  dueDate: string;
}

export class UpdateObjectiveDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @IsOptional()
  @IsDateString()
  dueDate?: string;

  @IsOptional()
  @IsEnum(ObjectiveStatus)
  status?: ObjectiveStatus;
}

@Controller('api/objectives')
@UseGuards(AuthGuard('jwt'), ApprovalGuard, RolesGuard)
export class ObjectivesController {
  constructor(private readonly objectives: ObjectivesService) {}

  @Post()
  create(@Body() dto: CreateObjectiveDto, @CurrentUser() user: { id: string }) {
    return this.objectives.create(dto, user.id);
  }

  @Get()
  list(
    @Query('scope') scope: ObjectiveScope | undefined,
    @Query('divisionId') divisionId: string | undefined,
    @Query('groupId') groupId: string | undefined,
    @CurrentUser() user: { id: string },
  ) {
    return this.objectives.list({ scope, divisionId, groupId }, user.id);
  }

  @Get(':id')
  findById(@Param('id') id: string, @CurrentUser() user: { id: string }) {
    return this.objectives.findById(id, user.id);
  }

  @Get(':id/tasks')
  getTasks(@Param('id') id: string, @CurrentUser() user: { id: string }) {
    return this.objectives.getTasks(id, user.id);
  }

  @Patch(':id')
  update(
    @Param('id') id: string,
    @Body() dto: UpdateObjectiveDto,
    @CurrentUser() user: { id: string },
  ) {
    return this.objectives.update(id, user.id, dto);
  }

  @Patch(':id/complete')
  complete(@Param('id') id: string, @CurrentUser() user: { id: string }) {
    return this.objectives.complete(id, user.id);
  }

  @Delete(':id')
  remove(@Param('id') id: string, @CurrentUser() user: { id: string }) {
    return this.objectives.remove(id, user.id);
  }
}
