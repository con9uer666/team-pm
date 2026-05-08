import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import {
  Objective,
  ObjectiveScope,
  ObjectiveStatus,
  User,
  Group,
  Division,
  Task,
  TaskStatus,
  RoleLevel,
  NotificationType,
} from '../../entities';
import { NotificationsService } from '../notifications/notifications.service';

interface CreateObjectiveDto {
  title: string;
  description?: string;
  scope: ObjectiveScope;
  divisionId?: string;
  groupId?: string;
  dueDate: string;
}

interface UpdateObjectiveDto {
  title?: string;
  description?: string;
  dueDate?: string;
  status?: ObjectiveStatus;
}

interface ListQuery {
  scope?: ObjectiveScope;
  divisionId?: string;
  groupId?: string;
}

@Injectable()
export class ObjectivesService {
  constructor(
    @InjectRepository(Objective)
    private readonly objectiveRepo: Repository<Objective>,
    @InjectRepository(Task)
    private readonly taskRepo: Repository<Task>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Group)
    private readonly groupRepo: Repository<Group>,
    @InjectRepository(Division)
    private readonly divisionRepo: Repository<Division>,
    private readonly notifications: NotificationsService,
  ) {}

  async create(dto: CreateObjectiveDto, userId: string): Promise<Objective> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('用户不存在');

    if (dto.scope === ObjectiveScope.DIVISION) {
      if (!dto.divisionId) throw new BadRequestException('兵种组目标必须指定 divisionId');
    } else if (dto.scope === ObjectiveScope.GROUP) {
      if (!dto.groupId) throw new BadRequestException('技术组目标必须指定 groupId');
    } else {
      throw new BadRequestException('scope 非法');
    }

    await this.assertCanManage(user, dto.scope, dto.divisionId, dto.groupId);

    const obj = this.objectiveRepo.create({
      title: dto.title,
      description: dto.description || null,
      scope: dto.scope,
      divisionId: dto.scope === ObjectiveScope.DIVISION ? dto.divisionId! : null,
      groupId: dto.scope === ObjectiveScope.GROUP ? dto.groupId! : null,
      dueDate: new Date(dto.dueDate),
      status: ObjectiveStatus.ACTIVE,
      manuallyCompleted: false,
      createdById: userId,
    });
    const saved = await this.objectiveRepo.save(obj);

    await this.notifyMembers(saved, user.realName);

    return saved;
  }

  async list(query: ListQuery, userId: string) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('用户不存在');

    const where: any = {};
    if (query.scope) where.scope = query.scope;
    if (query.divisionId) where.divisionId = query.divisionId;
    if (query.groupId) where.groupId = query.groupId;

    const all = await this.objectiveRepo.find({ where, order: { createdAt: 'DESC' } });

    const isHigh = user.isSuperAdmin || user.roleLevel >= RoleLevel.PROJECT_MANAGER;
    const visible = isHigh
      ? all
      : all.filter(o => this.userInScope(user, o));

    return Promise.all(visible.map(o => this.withProgress(o)));
  }

  async findById(id: string, userId: string) {
    const obj = await this.objectiveRepo.findOne({ where: { id } });
    if (!obj) throw new NotFoundException('目标不存在');

    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('用户不存在');

    const isHigh = user.isSuperAdmin || user.roleLevel >= RoleLevel.PROJECT_MANAGER;
    if (!isHigh && !this.userInScope(user, obj)) {
      throw new ForbiddenException('您无权查看该目标');
    }
    return this.withProgress(obj);
  }

  async update(id: string, userId: string, dto: UpdateObjectiveDto) {
    const obj = await this.objectiveRepo.findOne({ where: { id } });
    if (!obj) throw new NotFoundException('目标不存在');

    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('用户不存在');

    await this.assertCanEdit(user, obj);

    if (dto.title !== undefined) obj.title = dto.title;
    if (dto.description !== undefined) obj.description = dto.description || null;
    if (dto.dueDate !== undefined) obj.dueDate = new Date(dto.dueDate);
    if (dto.status !== undefined) obj.status = dto.status;

    const saved = await this.objectiveRepo.save(obj);
    return this.withProgress(saved);
  }

  async complete(id: string, userId: string) {
    const obj = await this.objectiveRepo.findOne({ where: { id } });
    if (!obj) throw new NotFoundException('目标不存在');

    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('用户不存在');

    await this.assertCanEdit(user, obj);

    obj.manuallyCompleted = true;
    obj.status = ObjectiveStatus.COMPLETED;
    const saved = await this.objectiveRepo.save(obj);
    return this.withProgress(saved);
  }

  async remove(id: string, userId: string) {
    const obj = await this.objectiveRepo.findOne({ where: { id } });
    if (!obj) throw new NotFoundException('目标不存在');

    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('用户不存在');

    await this.assertCanEdit(user, obj);

    await this.taskRepo
      .createQueryBuilder()
      .update(Task)
      .set({ objectiveId: null })
      .where('objective_id = :id', { id })
      .execute();

    await this.objectiveRepo.remove(obj);
    return { message: '已删除' };
  }

  async getTasks(objectiveId: string, userId: string) {
    await this.findById(objectiveId, userId);
    return this.taskRepo.find({
      where: { objectiveId },
      order: { createdAt: 'DESC' },
    });
  }

  private async withProgress(obj: Objective) {
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

  private userInScope(user: User, obj: Objective): boolean {
    if (obj.scope === ObjectiveScope.DIVISION) {
      return (user.divisionIds || []).includes(obj.divisionId!);
    }
    return (user.groupIds || []).includes(obj.groupId!);
  }

  private async assertCanManage(
    user: User,
    scope: ObjectiveScope,
    divisionId?: string,
    groupId?: string,
  ) {
    if (user.isSuperAdmin || user.roleLevel >= RoleLevel.PROJECT_MANAGER) return;

    if (user.roleLevel < RoleLevel.GROUP_LEADER) {
      throw new ForbiddenException('只有组长及以上可以下达阶段性目标');
    }

    if (scope === ObjectiveScope.GROUP) {
      const group = await this.groupRepo.findOne({ where: { id: groupId } });
      if (!group?.leaderIds?.includes(user.id)) {
        throw new ForbiddenException('您不是该技术组的组长');
      }
    } else {
      const division = await this.divisionRepo.findOne({ where: { id: divisionId } });
      if (!division?.leaderIds?.includes(user.id)) {
        throw new ForbiddenException('您不是该兵种组的组长');
      }
    }
  }

  private async assertCanEdit(user: User, obj: Objective) {
    if (user.isSuperAdmin || user.roleLevel >= RoleLevel.PROJECT_MANAGER) return;
    if (obj.createdById === user.id) return;
    await this.assertCanManage(user, obj.scope, obj.divisionId || undefined, obj.groupId || undefined);
  }

  private async notifyMembers(obj: Objective, creatorName: string) {
    let memberIds: string[] = [];
    if (obj.scope === ObjectiveScope.GROUP && obj.groupId) {
      const users = await this.userRepo.find();
      memberIds = users
        .filter(u => (u.groupIds || []).includes(obj.groupId!))
        .map(u => u.id);
    } else if (obj.scope === ObjectiveScope.DIVISION && obj.divisionId) {
      const users = await this.userRepo.find();
      memberIds = users
        .filter(u => (u.divisionIds || []).includes(obj.divisionId!))
        .map(u => u.id);
    }
    memberIds = memberIds.filter(id => id !== obj.createdById);
    if (!memberIds.length) return;

    await this.notifications.createBatch(
      memberIds,
      NotificationType.GENERAL,
      `新阶段性目标：${obj.title}`,
      `${creatorName} 下达了新目标，截止 ${this.formatDate(obj.dueDate)}`,
      obj.id,
    );
  }

  private formatDate(d: Date): string {
    const pad = (n: number) => n.toString().padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  }
}
