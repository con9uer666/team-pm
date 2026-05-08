import { Controller, Get, Post, Patch, Delete, Param, Body, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { UsersService } from './users.service';
import { RolesGuard } from '../../common/guards/roles.guard';
import { ApprovalGuard } from '../../common/guards/approval.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { AllowPending } from '../../common/decorators/allow-pending.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RoleLevel, Position } from '../../entities';

@Controller('api/users')
@UseGuards(AuthGuard('jwt'), ApprovalGuard, RolesGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  @Roles(RoleLevel.PROJECT_MANAGER)
  findAll() {
    return this.usersService.findAll();
  }

  @Get('me')
  @AllowPending()
  getMe(@CurrentUser() user: { id: string }) {
    return this.usersService.findById(user.id);
  }

  @Patch(':id/role')
  @Roles(RoleLevel.TEAM_CAPTAIN)
  updateRole(
    @Param('id') id: string,
    @Body() body: { roleLevel: number; position?: Position | null },
    @CurrentUser() user: { id: string },
  ) {
    return this.usersService.updateRole(id, body.roleLevel, user.id, body.position);
  }

  @Patch(':id/position')
  @Roles(RoleLevel.PROJECT_MANAGER)
  updatePosition(
    @Param('id') id: string,
    @Body('position') position: Position | null,
    @CurrentUser() user: { id: string },
  ) {
    return this.usersService.updatePosition(id, position, user.id);
  }

  @Patch(':id/password')
  @Roles(RoleLevel.PROJECT_MANAGER)
  resetPassword(
    @Param('id') id: string,
    @Body('password') password: string,
    @CurrentUser() user: { id: string },
  ) {
    return this.usersService.resetPassword(id, password, user.id);
  }

  @Patch(':id/group')
  @Roles(RoleLevel.PROJECT_MANAGER)
  assignGroups(@Param('id') id: string, @Body('groupIds') groupIds: string[]) {
    return this.usersService.assignGroups(id, groupIds);
  }

  @Patch(':id/division')
  @Roles(RoleLevel.PROJECT_MANAGER)
  assignDivisions(@Param('id') id: string, @Body('divisionIds') divisionIds: string[]) {
    return this.usersService.assignDivisions(id, divisionIds);
  }

  @Post()
  @Roles(RoleLevel.PROJECT_MANAGER)
  createUser(
    @Body() dto: {
      username: string;
      password: string;
      realName: string;
      roleLevel?: number;
      position?: Position | null;
      groupIds?: string[];
      divisionIds?: string[];
      email?: string;
    },
    @CurrentUser() user: { id: string },
  ) {
    return this.usersService.createUser(dto, user.id);
  }

  @Delete(':id')
  @Roles(RoleLevel.TEAM_CAPTAIN)
  removeUser(@Param('id') id: string) {
    return this.usersService.removeUser(id);
  }
}

@Controller('api/organization')
@UseGuards(AuthGuard('jwt'), ApprovalGuard, RolesGuard)
export class OrganizationController {
  constructor(private readonly usersService: UsersService) {}

  @Get('groups')
  @AllowPending()
  getGroups() {
    return this.usersService.findAllGroups();
  }

  @Post('groups')
  @Roles(RoleLevel.PROJECT_MANAGER)
  createGroup(@Body() dto: { name: string; leaderIds?: string[]; divisionId?: string }) {
    return this.usersService.createGroup(dto);
  }

  @Patch('groups/:id/leaders')
  @Roles(RoleLevel.PROJECT_MANAGER)
  setGroupLeaders(@Param('id') id: string, @Body('leaderIds') leaderIds: string[]) {
    return this.usersService.setGroupLeaders(id, leaderIds);
  }

  @Get('divisions')
  @AllowPending()
  getDivisions() {
    return this.usersService.findAllDivisions();
  }

  @Post('divisions')
  @Roles(RoleLevel.PROJECT_MANAGER)
  createDivision(@Body() dto: { name: string; leaderIds?: string[]; description?: string }) {
    return this.usersService.createDivision(dto);
  }

  @Patch('divisions/:id/leaders')
  @Roles(RoleLevel.PROJECT_MANAGER)
  setDivisionLeaders(@Param('id') id: string, @Body('leaderIds') leaderIds: string[]) {
    return this.usersService.setDivisionLeaders(id, leaderIds);
  }

  @Get('structure')
  @AllowPending()
  getStructure() {
    return this.usersService.getOrganizationStructure();
  }
}

@Controller('api/public')
export class PublicOrgController {
  constructor(private readonly usersService: UsersService) {}

  @Get('groups')
  getGroups() {
    return this.usersService
      .findAllGroups()
      .then(list => list.map(g => ({ id: g.id, name: g.name })));
  }
}
