import { Controller, Get, Post, Patch, Param, Body, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { MeetingsService } from './meetings.service';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RoleLevel, MeetingScope } from '../../entities';

@Controller('api/meetings')
@UseGuards(AuthGuard('jwt'), RolesGuard)
export class MeetingsController {
  constructor(private readonly service: MeetingsService) {}

  @Post()
  @Roles(RoleLevel.GROUP_LEADER)
  create(
    @CurrentUser() user: { id: string },
    @Body() dto: {
      title: string;
      description?: string;
      scope: MeetingScope;
      groupId?: string;
      divisionId?: string;
      location?: string;
      startTime: string;
      endTime: string;
    },
  ) {
    return this.service.create(user.id, dto);
  }

  @Get()
  findAll() {
    return this.service.findAll();
  }

  @Get('my')
  findMy(@CurrentUser() user: { id: string }) {
    return this.service.findByUser(user.id);
  }

  @Get(':id')
  findById(@Param('id') id: string) {
    return this.service.findById(id);
  }

  @Patch(':id/start')
  start(@Param('id') id: string, @CurrentUser() user: { id: string }) {
    return this.service.startMeeting(id, user.id);
  }

  @Patch(':id/end')
  end(@Param('id') id: string, @CurrentUser() user: { id: string }) {
    return this.service.endMeeting(id, user.id);
  }

  @Patch(':id/cancel')
  cancel(@Param('id') id: string, @CurrentUser() user: { id: string }) {
    return this.service.cancelMeeting(id, user.id);
  }

  @Post(':id/check-in')
  checkIn(@Param('id') id: string, @CurrentUser() user: { id: string }) {
    return this.service.checkIn(id, user.id);
  }

  @Get(':id/participants')
  getParticipants(@Param('id') id: string) {
    return this.service.getParticipants(id);
  }

  @Post(':id/minutes')
  @Roles(RoleLevel.GROUP_LEADER)
  saveMinutes(
    @Param('id') id: string,
    @CurrentUser() user: { id: string },
    @Body('content') content: string,
  ) {
    return this.service.saveMinutes(id, user.id, content);
  }

  @Get(':id/minutes')
  getMinutes(@Param('id') id: string) {
    return this.service.getMinutes(id);
  }
}
