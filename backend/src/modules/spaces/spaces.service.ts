import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  User,
  Group,
  Division,
  Task,
  Objective,
  ObjectiveScope,
  RoleLevel,
  TaskStatus,
} from '../../entities';

@Injectable()
export class SpacesService {
  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Group)
    private readonly groupRepo: Repository<Group>,
    @InjectRepository(Division)
    private readonly divisionRepo: Repository<Division>,
    @InjectRepository(Task)
    private readonly taskRepo: Repository<Task>,
    @InjectRepository(Objective)
    private readonly objectiveRepo: Repository<Objective>,
  ) {}

  async getMySpaces(userId: string) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('用户不存在');

    const [allGroups, allDivisions, allUsers] = await Promise.all([
      this.groupRepo.find(),
      this.divisionRepo.find(),
      this.userRepo.find({ select: ['id', 'groupIds', 'divisionIds'] }),
    ]);

    const myGroupIds = user.groupIds || [];
    const myDivisionIds = user.divisionIds || [];

    const groups = allGroups
      .filter(g => myGroupIds.includes(g.id))
      .map(g => ({
        id: g.id,
        name: g.name,
        leaderIds: g.leaderIds || [],
        memberCount: allUsers.filter(u => (u.groupIds || []).includes(g.id)).length,
      }));

    const divisions = allDivisions
      .filter(d => myDivisionIds.includes(d.id))
      .map(d => ({
        id: d.id,
        name: d.name,
        leaderIds: d.leaderIds || [],
        memberCount: allUsers.filter(u => (u.divisionIds || []).includes(d.id)).length,
      }));

    return { groups, divisions };
  }

  async getGroupSpace(groupId: string, userId: string) {
    const [group, user] = await Promise.all([
      this.groupRepo.findOne({ where: { id: groupId } }),
      this.userRepo.findOne({ where: { id: userId } }),
    ]);
    if (!group) throw new NotFoundException('技术组不存在');
    if (!user) throw new NotFoundException('用户不存在');

    const isHigh = user.isSuperAdmin || user.roleLevel >= RoleLevel.PROJECT_MANAGER;
    const isMember = (user.groupIds || []).includes(groupId);
    if (!isHigh && !isMember) throw new ForbiddenException('您不属于该技术组');

    const allUsers = await this.userRepo.find({ order: { roleLevel: 'DESC', realName: 'ASC' } });
    const members = allUsers.filter(u => (u.groupIds || []).includes(groupId));

    const [objectives, tasks] = await Promise.all([
      this.objectiveRepo.find({
        where: { scope: ObjectiveScope.GROUP, groupId },
        order: { createdAt: 'DESC' },
      }),
      this.taskRepo.find({ where: { groupId }, order: { createdAt: 'DESC' } }),
    ]);

    const objectivesWithProgress = await Promise.all(
      objectives.map(o => this.enrichObjective(o)),
    );

    return {
      info: {
        id: group.id,
        name: group.name,
        leaderIds: group.leaderIds || [],
        divisionId: group.divisionId || null,
      },
      members: members.map(m => this.publicUser(m)),
      objectives: objectivesWithProgress,
      tasks,
    };
  }

  async getDivisionSpace(divisionId: string, userId: string) {
    const [division, user] = await Promise.all([
      this.divisionRepo.findOne({ where: { id: divisionId } }),
      this.userRepo.findOne({ where: { id: userId } }),
    ]);
    if (!division) throw new NotFoundException('兵种组不存在');
    if (!user) throw new NotFoundException('用户不存在');

    const isHigh = user.isSuperAdmin || user.roleLevel >= RoleLevel.PROJECT_MANAGER;
    const isMember = (user.divisionIds || []).includes(divisionId);
    if (!isHigh && !isMember) throw new ForbiddenException('您不属于该兵种组');

    const allUsers = await this.userRepo.find({ order: { roleLevel: 'DESC', realName: 'ASC' } });
    const members = allUsers.filter(u => (u.divisionIds || []).includes(divisionId));

    const [objectives, tasks] = await Promise.all([
      this.objectiveRepo.find({
        where: { scope: ObjectiveScope.DIVISION, divisionId },
        order: { createdAt: 'DESC' },
      }),
      this.taskRepo.find({ where: { divisionId }, order: { createdAt: 'DESC' } }),
    ]);

    const objectivesWithProgress = await Promise.all(
      objectives.map(o => this.enrichObjective(o)),
    );

    return {
      info: {
        id: division.id,
        name: division.name,
        leaderIds: division.leaderIds || [],
        description: division.description || null,
      },
      members: members.map(m => this.publicUser(m)),
      objectives: objectivesWithProgress,
      tasks,
    };
  }

  private async enrichObjective(obj: Objective) {
    const tasks = await this.taskRepo.find({ where: { objectiveId: obj.id } });
    const total = tasks.length;
    const done = tasks.filter(t => t.status === TaskStatus.COMPLETED).length;
    const progress = obj.manuallyCompleted
      ? 100
      : total === 0
        ? 0
        : Math.floor((done / total) * 100);
    return { ...obj, totalTasks: total, completedTasks: done, progress };
  }

  private publicUser(u: User) {
    return {
      id: u.id,
      username: u.username,
      realName: u.realName,
      roleLevel: u.roleLevel,
      avatarUrl: u.avatarUrl,
      groupIds: u.groupIds,
      divisionIds: u.divisionIds,
      status: u.status,
    };
  }
}
