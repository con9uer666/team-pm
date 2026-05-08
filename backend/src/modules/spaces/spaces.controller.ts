import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { SpacesService } from './spaces.service';
import { ApprovalGuard } from '../../common/guards/approval.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('api/spaces')
@UseGuards(AuthGuard('jwt'), ApprovalGuard, RolesGuard)
export class SpacesController {
  constructor(private readonly spaces: SpacesService) {}

  @Get('my')
  getMy(@CurrentUser() user: { id: string }) {
    return this.spaces.getMySpaces(user.id);
  }

  @Get('group/:id')
  getGroup(@Param('id') id: string, @CurrentUser() user: { id: string }) {
    return this.spaces.getGroupSpace(id, user.id);
  }

  @Get('division/:id')
  getDivision(@Param('id') id: string, @CurrentUser() user: { id: string }) {
    return this.spaces.getDivisionSpace(id, user.id);
  }
}
