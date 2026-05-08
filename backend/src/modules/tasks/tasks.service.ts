import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan, LessThanOrEqual, IsNull, In } from 'typeorm';
import { Cron } from '@nestjs/schedule';
import { Task, TaskStatus, TaskDependency, TaskReview, ReviewType, ReviewStatus, User, RoleLevel, Division, Group, NotificationType, Objective, ObjectiveScope, ObjectiveStatus } from '../../entities';
import { NotificationsService } from '../notifications/notifications.service';
import { WechatService } from '../wechat/wechat.service';

@Injectable()
export class TasksService {
  constructor(
    @InjectRepository(Task)
    private readonly taskRepo: Repository<Task>,
    @InjectRepository(TaskDependency)
    private readonly depRepo: Repository<TaskDependency>,
    @InjectRepository(TaskReview)
    private readonly reviewRepo: Repository<TaskReview>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Division)
    private readonly divisionRepo: Repository<Division>,
    @InjectRepository(Group)
    private readonly groupRepo: Repository<Group>,
    @InjectRepository(Objective)
    private readonly objectiveRepo: Repository<Objective>,
    private readonly notifications: NotificationsService,
    private readonly wechat: WechatService,
  ) {}

  async create(dto: {
    title: string;
    description?: string;
    content?: string;
    divisionId?: string;
    groupId?: string;
    objectiveId?: string;
    completionRequirements?: string;
    dueDate: string;
    priority?: number;
    dependencyIds?: string[];
    assigneeId?: string;
  }, userId: string) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('用户不存在');

    const assigneeId = dto.assigneeId || userId;
    const isAssigning = dto.assigneeId && dto.assigneeId !== userId;

    if (isAssigning) {
      if (user.roleLevel < RoleLevel.GROUP_LEADER) {
        throw new ForbiddenException('只有组长及以上可以派发任务');
      }
    }

    // Validate division/group membership for the assignee
    if (isAssigning) {
      const assignee = await this.userRepo.findOne({ where: { id: assigneeId } });
      if (!assignee) throw new NotFoundException('被指派用户不存在');
      if (dto.divisionId) {
        const assigneeDivs = assignee.divisionIds || [];
        if (!assigneeDivs.includes(dto.divisionId)) {
          throw new ForbiddenException('被指派人不属于该兵种');
        }
      }
      if (dto.groupId) {
        const assigneeGroups = assignee.groupIds || [];
        if (!assigneeGroups.includes(dto.groupId)) {
          throw new ForbiddenException('被指派人不属于该技术组');
        }
      }
    } else {
      if (dto.divisionId) {
        const userDivs = user.divisionIds || [];
        if (!userDivs.includes(dto.divisionId)) {
          throw new ForbiddenException('只能创建自己所属兵种组的任务');
        }
      }
      if (dto.groupId) {
        const userGroups = user.groupIds || [];
        if (!userGroups.includes(dto.groupId)) {
          throw new ForbiddenException('只能创建自己所属技术组的任务');
        }
      }
    }

    if (dto.objectiveId) {
      await this.assertObjectiveCompatible(dto.objectiveId, dto.divisionId, dto.groupId);
    }

    const now = new Date();
    const task = new Task();
    task.title = dto.title;
    task.description = dto.description || null;
    task.content = dto.content || null;
    task.divisionId = dto.divisionId || null;
    task.groupId = dto.groupId || null;
    task.objectiveId = dto.objectiveId || null;
    task.completionRequirements = dto.completionRequirements || null;
    task.creatorId = userId;
    task.assigneeId = assigneeId;
    task.dueDate = new Date(dto.dueDate);
    task.priority = dto.priority || 0;
    task.weekYear = now.getFullYear();
    task.weekNumber = this.getWeekNumber(now);
    task.status = TaskStatus.PENDING_REVIEW;
    const saved = await this.taskRepo.save(task);

    if (dto.dependencyIds?.length) {
      for (const depId of dto.dependencyIds) {
        const dep = new TaskDependency();
        dep.taskId = saved.id;
        dep.dependsOnTaskId = depId;
        await this.depRepo.save(dep);
      }
    }

    // If assigning (派发), auto-approve the leader's dimension review
    if (isAssigning) {
      const autoReviewTypes: ReviewType[] = [];
      if (dto.divisionId) {
        const division = await this.divisionRepo.findOne({ where: { id: dto.divisionId } });
        if (division?.leaderIds?.includes(userId)) {
          autoReviewTypes.push(ReviewType.DIVISION);
        }
      }
      if (dto.groupId) {
        const group = await this.groupRepo.findOne({ where: { id: dto.groupId } });
        if (group?.leaderIds?.includes(userId)) {
          autoReviewTypes.push(ReviewType.GROUP);
        }
      }
      // Also auto-approve for project managers and above
      if (!autoReviewTypes.length && user.roleLevel >= RoleLevel.PROJECT_MANAGER) {
        if (dto.divisionId) autoReviewTypes.push(ReviewType.DIVISION);
        if (dto.groupId) autoReviewTypes.push(ReviewType.GROUP);
      }

      for (const rt of autoReviewTypes) {
        const review = new TaskReview();
        review.taskId = saved.id;
        review.reviewerId = userId;
        review.reviewType = rt;
        review.status = ReviewStatus.APPROVED;
        await this.reviewRepo.save(review);
      }

      // Check if all reviews are done (派发者可能同时是两个维度的组长)
      const needsDivision = !!dto.divisionId;
      const needsGroup = !!dto.groupId;
      const divPassed = !needsDivision || autoReviewTypes.includes(ReviewType.DIVISION);
      const groupPassed = !needsGroup || autoReviewTypes.includes(ReviewType.GROUP);
      if (divPassed && groupPassed) {
        saved.status = TaskStatus.APPROVED;
        saved.reviewedBy = userId;
        saved.reviewedAt = new Date();
        await this.taskRepo.save(saved);
      }
    }

    if (isAssigning) {
      await this.notifications.create(
        assigneeId,
        NotificationType.TASK_ASSIGNED,
        `新任务：${saved.title}`,
        `派发人：${user.realName}\n截止：${this.formatDate(saved.dueDate)}`,
        saved.id,
        { wechatUrl: this.wechat.buildTaskUrl(saved.id) },
      );
    }

    return saved;
  }

  async findAll(query: { weekYear?: number; weekNumber?: number; status?: string; assigneeId?: string }) {
    const where: any = {};
    if (query.weekYear) where.weekYear = query.weekYear;
    if (query.weekNumber) where.weekNumber = query.weekNumber;
    if (query.status) where.status = query.status;
    if (query.assigneeId) where.assigneeId = query.assigneeId;
    return this.taskRepo.find({ where, order: { createdAt: 'DESC' } });
  }

  async findById(id: string) {
    const task = await this.taskRepo.findOne({ where: { id } });
    if (!task) throw new NotFoundException('任务不存在');
    return task;
  }

  async getDependencies(taskId: string) {
    const deps = await this.depRepo.find({ where: { taskId } });
    if (!deps.length) return [];
    const depTaskIds = deps.map(d => d.dependsOnTaskId);
    return this.taskRepo.find({ where: { id: In(depTaskIds) } });
  }

  async getReviews(taskId: string) {
    return this.reviewRepo.find({ where: { taskId } });
  }

  async getReviewableTypes(taskId: string, reviewerId: string): Promise<ReviewType[]> {
    const task = await this.findById(taskId);
    const reviewer = await this.userRepo.findOne({ where: { id: reviewerId } });
    if (!reviewer) return [];

    if (reviewer.isSuperAdmin || reviewer.roleLevel >= RoleLevel.PROJECT_MANAGER) {
      return [ReviewType.DIVISION, ReviewType.GROUP];
    }

    const types: ReviewType[] = [];
    if (task.divisionId) {
      const division = await this.divisionRepo.findOne({ where: { id: task.divisionId } });
      if (division?.leaderIds?.includes(reviewerId)) {
        types.push(ReviewType.DIVISION);
      }
    }
    if (task.groupId) {
      const group = await this.groupRepo.findOne({ where: { id: task.groupId } });
      if (group?.leaderIds?.includes(reviewerId)) {
        types.push(ReviewType.GROUP);
      }
    }
    return types;
  }

  async reviewTask(taskId: string, reviewerId: string, action: 'approve' | 'reject', reviewType: ReviewType, reason?: string) {
    const task = await this.findById(taskId);
    const reviewer = await this.userRepo.findOne({ where: { id: reviewerId } });
    if (!reviewer) throw new NotFoundException('用户不存在');

    if (reviewer.isSuperAdmin) {
      return this.executeReview(task, reviewerId, action, reviewType, reason);
    }

    if (task.status !== TaskStatus.PENDING_REVIEW) {
      throw new ForbiddenException('只能审核待审核状态的任务');
    }

    const allowedTypes = await this.getReviewableTypes(taskId, reviewerId);
    if (!allowedTypes.includes(reviewType)) {
      throw new ForbiddenException('无权进行此类型的审核');
    }

    const existing = await this.reviewRepo.findOne({ where: { taskId, reviewType } });
    if (existing) throw new ForbiddenException('该类型审核已完成');

    return this.executeReview(task, reviewerId, action, reviewType, reason);
  }

  private async executeReview(task: Task, reviewerId: string, action: 'approve' | 'reject', reviewType: ReviewType, reason?: string) {
    const review = new TaskReview();
    review.taskId = task.id;
    review.reviewerId = reviewerId;
    review.reviewType = reviewType;
    review.status = action === 'approve' ? ReviewStatus.APPROVED : ReviewStatus.REJECTED;
    review.rejectionReason = action === 'reject' ? (reason || null) : null;
    await this.reviewRepo.save(review);

    if (action === 'reject') {
      task.status = TaskStatus.REJECTED;
      task.rejectedBy = reviewerId;
      task.rejectionReason = reason || null;
      const saved = await this.taskRepo.save(task);
      await this.notifications.create(
        task.creatorId,
        NotificationType.TASK_REJECTED,
        `任务被驳回：${task.title}`,
        reason ? `原因：${reason}` : '请查看详情',
        task.id,
        { wechatUrl: this.wechat.buildTaskUrl(task.id) },
      );
      return saved;
    }

    const allReviews = await this.reviewRepo.find({ where: { taskId: task.id } });
    const divReview = allReviews.find(r => r.reviewType === ReviewType.DIVISION);
    const groupReview = allReviews.find(r => r.reviewType === ReviewType.GROUP);
    const needsDivision = !!task.divisionId;
    const needsGroup = !!task.groupId;
    const divPassed = !needsDivision || divReview?.status === ReviewStatus.APPROVED;
    const groupPassed = !needsGroup || groupReview?.status === ReviewStatus.APPROVED;

    if (divPassed && groupPassed) {
      const depsCompleted = await this.checkDependenciesCompleted(task.id);
      task.status = depsCompleted ? TaskStatus.APPROVED : TaskStatus.BLOCKED;
      task.reviewedBy = reviewerId;
      task.reviewedAt = new Date();
      const saved = await this.taskRepo.save(task);
      if (task.status === TaskStatus.APPROVED) {
        await this.notifications.create(
          task.assigneeId,
          NotificationType.TASK_APPROVED,
          `任务已通过审核：${task.title}`,
          `截止：${this.formatDate(task.dueDate)}`,
          task.id,
          { wechatUrl: this.wechat.buildTaskUrl(task.id) },
        );
      }
      return saved;
    }
    return task;
  }

  async deleteTask(taskId: string, userId: string) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user?.isSuperAdmin) throw new ForbiddenException('只有超级管理员可以删除任务');
    const task = await this.findById(taskId);
    await this.depRepo.delete({ taskId });
    await this.depRepo.delete({ dependsOnTaskId: taskId });
    await this.reviewRepo.delete({ taskId });
    await this.taskRepo.remove(task);
    return { message: '任务已删除' };
  }

  async updateObjective(taskId: string, userId: string, objectiveId: string | null) {
    const task = await this.findById(taskId);
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('用户不存在');

    let isLeaderForTask = false;
    if (task.divisionId) {
      const division = await this.divisionRepo.findOne({ where: { id: task.divisionId } });
      if (division?.leaderIds?.includes(userId)) isLeaderForTask = true;
    }
    if (!isLeaderForTask && task.groupId) {
      const group = await this.groupRepo.findOne({ where: { id: task.groupId } });
      if (group?.leaderIds?.includes(userId)) isLeaderForTask = true;
    }
    const canManage = user.isSuperAdmin || user.roleLevel >= RoleLevel.PROJECT_MANAGER || isLeaderForTask;
    if (!canManage) throw new ForbiddenException('无权修改该任务的关联目标');

    if (objectiveId) {
      await this.assertObjectiveCompatible(objectiveId, task.divisionId, task.groupId);
    }
    task.objectiveId = objectiveId;
    return this.taskRepo.save(task);
  }

  private async assertObjectiveCompatible(
    objectiveId: string,
    divisionId?: string | null,
    groupId?: string | null,
  ) {
    const obj = await this.objectiveRepo.findOne({ where: { id: objectiveId } });
    if (!obj) throw new NotFoundException('阶段性目标不存在');
    if (obj.status !== ObjectiveStatus.ACTIVE) {
      throw new ForbiddenException('目标已结束，无法关联');
    }
    if (obj.scope === ObjectiveScope.GROUP && obj.groupId !== groupId) {
      throw new ForbiddenException('任务必须属于该目标对应的技术组');
    }
    if (obj.scope === ObjectiveScope.DIVISION && obj.divisionId !== divisionId) {
      throw new ForbiddenException('任务必须属于该目标对应的兵种组');
    }
  }

  async complete(taskId: string, userId: string, attachments: string[], note?: string) {
    const task = await this.findById(taskId);
    if (task.assigneeId !== userId) throw new ForbiddenException('只能完成自己的任务');
    if (task.status !== TaskStatus.APPROVED && task.status !== TaskStatus.OVERDUE) {
      throw new ForbiddenException('任务状态不允许提交完成');
    }
    if (!attachments?.length) throw new ForbiddenException('请上传至少一个附件');
    task.status = TaskStatus.PENDING_COMPLETION;
    task.completedAt = new Date();
    task.completionAttachments = attachments;
    task.completionNote = note || null;
    if (task.completedAt > task.dueDate) {
      task.overdueMinutes = Math.floor((task.completedAt.getTime() - task.dueDate.getTime()) / 60000);
    }
    const saved = await this.taskRepo.save(task);

    const assignee = await this.userRepo.findOne({ where: { id: userId } });
    const reviewerIds = await this.collectCompletionReviewers(task);
    if (reviewerIds.length) {
      await this.notifications.createBatch(
        reviewerIds,
        NotificationType.GENERAL,
        `${assignee?.realName || '成员'} 提交结案待审`,
        `任务：${task.title}`,
        task.id,
        { wechatUrl: this.wechat.buildTaskUrl(task.id) },
      );
    }

    return saved;
  }

  async verifyCompletion(taskId: string, reviewerId: string, action: 'approve' | 'reject', reason?: string) {
    const task = await this.findById(taskId);
    if (task.status !== TaskStatus.PENDING_COMPLETION) {
      throw new ForbiddenException('任务不在待结案审核状态');
    }
    const reviewer = await this.userRepo.findOne({ where: { id: reviewerId } });
    if (!reviewer) throw new NotFoundException('用户不存在');
    if (!reviewer.isSuperAdmin && reviewer.roleLevel < RoleLevel.PROJECT_MANAGER) {
      const allowedTypes = await this.getReviewableTypes(taskId, reviewerId);
      if (!allowedTypes.length) throw new ForbiddenException('无权审核该任务结案');
    }

    if (action === 'approve') {
      task.status = TaskStatus.COMPLETED;
      task.reviewedBy = reviewerId;
      task.reviewedAt = new Date();
      const saved = await this.taskRepo.save(task);
      await this.unblockDependentTasks(taskId);
      await this.notifications.create(
        task.assigneeId,
        NotificationType.GENERAL,
        `结案已通过：${task.title}`,
        '任务正式完成',
        task.id,
        { wechatUrl: this.wechat.buildTaskUrl(task.id) },
      );
      return saved;
    } else {
      task.status = TaskStatus.APPROVED;
      task.completionAttachments = null;
      task.completionNote = null;
      task.rejectionReason = reason || null;
      task.rejectedBy = reviewerId;
      const saved = await this.taskRepo.save(task);
      await this.notifications.create(
        task.assigneeId,
        NotificationType.GENERAL,
        `结案被驳回：${task.title}`,
        reason ? `原因：${reason}` : '请修改后重新提交',
        task.id,
        { wechatUrl: this.wechat.buildTaskUrl(task.id) },
      );
      return saved;
    }
  }

  async resubmit(taskId: string, userId: string, dto: { title?: string; description?: string; dueDate?: string }) {
    const task = await this.findById(taskId);
    if (task.assigneeId !== userId) throw new ForbiddenException('只能修改自己的任务');
    if (task.status !== TaskStatus.REJECTED) throw new ForbiddenException('只能重新提交被驳回的任务');
    if (dto.title) task.title = dto.title;
    if (dto.description) task.description = dto.description;
    if (dto.dueDate) task.dueDate = new Date(dto.dueDate);
    task.status = TaskStatus.PENDING_REVIEW;
    task.rejectionReason = null;
    task.rejectedBy = null;
    await this.reviewRepo.delete({ taskId });
    return this.taskRepo.save(task);
  }

  @Cron('*/5 * * * *')
  async checkOverdueTasks() {
    const now = new Date();
    const overdueTasks = await this.taskRepo.find({
      where: { status: TaskStatus.APPROVED, dueDate: LessThan(now) },
    });
    for (const task of overdueTasks) {
      task.status = TaskStatus.OVERDUE;
      task.overdueMinutes = Math.floor((now.getTime() - task.dueDate.getTime()) / 60000);
      await this.taskRepo.save(task);
      await this.notifications.create(
        task.assigneeId,
        NotificationType.TASK_OVERDUE,
        `任务已逾期：${task.title}`,
        `原截止：${this.formatDate(task.dueDate)}`,
        task.id,
        { wechatUrl: this.wechat.buildTaskUrl(task.id) },
      );
    }
  }

  @Cron('*/30 * * * *')
  async checkUpcomingDeadlines() {
    const now = new Date();
    const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const candidates = await this.taskRepo.find({
      where: [
        { status: TaskStatus.APPROVED, remindedAt: IsNull(), dueDate: LessThanOrEqual(in24h) },
      ],
    });
    for (const task of candidates) {
      if (task.dueDate <= now) continue;
      const minutesLeft = Math.floor((task.dueDate.getTime() - now.getTime()) / 60000);
      task.remindedAt = now;
      await this.taskRepo.save(task);
      const hoursLeft = Math.max(1, Math.round(minutesLeft / 60));
      await this.notifications.create(
        task.assigneeId,
        NotificationType.GENERAL,
        `任务即将截止：${task.title}`,
        `还剩约 ${hoursLeft} 小时（截止 ${this.formatDate(task.dueDate)}）`,
        task.id,
        { wechatUrl: this.wechat.buildTaskUrl(task.id) },
      );
    }
  }

  private async collectCompletionReviewers(task: Task): Promise<string[]> {
    const reviewers = new Set<string>();
    if (task.divisionId) {
      const division = await this.divisionRepo.findOne({ where: { id: task.divisionId } });
      division?.leaderIds?.forEach(id => id !== task.assigneeId && reviewers.add(id));
    }
    if (task.groupId) {
      const group = await this.groupRepo.findOne({ where: { id: task.groupId } });
      group?.leaderIds?.forEach(id => id !== task.assigneeId && reviewers.add(id));
    }
    if (!reviewers.size) {
      const pms = await this.userRepo
        .createQueryBuilder('u')
        .where('u.role_level >= :lvl', { lvl: RoleLevel.PROJECT_MANAGER })
        .getMany();
      pms.forEach(u => u.id !== task.assigneeId && reviewers.add(u.id));
    }
    return Array.from(reviewers);
  }

  private formatDate(d: Date | string): string {
    const date = typeof d === 'string' ? new Date(d) : d;
    const pad = (n: number) => n.toString().padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }

  private async checkDependenciesCompleted(taskId: string): Promise<boolean> {
    const deps = await this.depRepo.find({ where: { taskId } });
    if (!deps.length) return true;
    const depTaskIds = deps.map(d => d.dependsOnTaskId);
    const depTasks = await this.taskRepo.find({ where: { id: In(depTaskIds) } });
    return depTasks.every(t => t.status === TaskStatus.COMPLETED);
  }

  private async unblockDependentTasks(completedTaskId: string) {
    const dependents = await this.depRepo.find({ where: { dependsOnTaskId: completedTaskId } });
    for (const dep of dependents) {
      const task = await this.taskRepo.findOne({ where: { id: dep.taskId, status: TaskStatus.BLOCKED } });
      if (!task) continue;
      const allDepsCompleted = await this.checkDependenciesCompleted(task.id);
      if (allDepsCompleted) {
        task.status = TaskStatus.APPROVED;
        await this.taskRepo.save(task);
      }
    }
  }

  async findMyScope(userId: string, query: { status?: string; scope?: 'own' | 'team' | 'all' }) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('用户不存在');

    let tasks: Task[];

    if (user.isSuperAdmin || user.roleLevel >= RoleLevel.PROJECT_MANAGER) {
      if (query.scope === 'own') {
        tasks = await this.findAll({ status: query.status, assigneeId: userId });
      } else {
        tasks = await this.findAll({ status: query.status });
      }
    } else if (user.roleLevel >= RoleLevel.GROUP_LEADER) {
      if (query.scope === 'own') {
        tasks = await this.findAll({ status: query.status, assigneeId: userId });
      } else if (query.scope === 'team') {
        const [ledGroupIds, ledDivisionIds] = await Promise.all([
          this.getLeaderGroupIds(userId),
          this.getLeaderDivisionIds(userId),
        ]);
        tasks = await this.findByGroupsAndDivisions(ledGroupIds, ledDivisionIds, query.status, userId);
      } else {
        const [own, [ledGroupIds, ledDivisionIds]] = await Promise.all([
          this.findAll({ status: query.status, assigneeId: userId }),
          Promise.all([this.getLeaderGroupIds(userId), this.getLeaderDivisionIds(userId)]),
        ]);
        const team = await this.findByGroupsAndDivisions(ledGroupIds, ledDivisionIds, query.status, userId);
        const map = new Map<string, Task>();
        [...own, ...team].forEach(t => map.set(t.id, t));
        tasks = Array.from(map.values()).sort((a, b) =>
          new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
        );
      }
    } else {
      tasks = await this.findAll({ status: query.status, assigneeId: userId });
    }

    return this.enrichWithReviewMeta(tasks, userId, user);
  }

  private async getLeaderGroupIds(userId: string): Promise<string[]> {
    const groups = await this.groupRepo.find();
    return groups.filter(g => g.leaderIds?.includes(userId)).map(g => g.id);
  }

  private async getLeaderDivisionIds(userId: string): Promise<string[]> {
    const divisions = await this.divisionRepo.find();
    return divisions.filter(d => d.leaderIds?.includes(userId)).map(d => d.id);
  }

  private async findByGroupsAndDivisions(groupIds: string[], divisionIds: string[], status?: string, excludeUserId?: string): Promise<Task[]> {
    if (!groupIds.length && !divisionIds.length) return [];

    const qb = this.taskRepo.createQueryBuilder('task');
    const conditions: string[] = [];
    const params: any = {};

    if (groupIds.length) {
      conditions.push('task.group_id IN (:...groupIds)');
      params.groupIds = groupIds;
    }
    if (divisionIds.length) {
      conditions.push('task.division_id IN (:...divisionIds)');
      params.divisionIds = divisionIds;
    }

    qb.where(`(${conditions.join(' OR ')})`, params);

    if (excludeUserId) {
      qb.andWhere('task.assignee_id != :excludeUserId', { excludeUserId });
    }
    if (status) {
      qb.andWhere('task.status = :status', { status });
    }

    qb.orderBy('task.created_at', 'DESC');
    return qb.getMany();
  }

  private async enrichWithReviewMeta(tasks: Task[], userId: string, user: User) {
    if (!tasks.length) return [];

    const pendingTaskIds = tasks.filter(t => t.status === TaskStatus.PENDING_REVIEW).map(t => t.id);
    const allReviews = pendingTaskIds.length
      ? await this.reviewRepo.find({ where: { taskId: In(pendingTaskIds) } })
      : [];

    const [ledGroupIds, ledDivisionIds] = user.isSuperAdmin || user.roleLevel >= RoleLevel.PROJECT_MANAGER
      ? [[], []]
      : await Promise.all([this.getLeaderGroupIds(userId), this.getLeaderDivisionIds(userId)]);

    return tasks.map(task => {
      const reviews = allReviews.filter(r => r.taskId === task.id);

      let reviewableTypes: string[] = [];
      if (task.status === TaskStatus.PENDING_REVIEW) {
        if (user.isSuperAdmin || user.roleLevel >= RoleLevel.PROJECT_MANAGER) {
          if (task.divisionId) reviewableTypes.push('division');
          if (task.groupId) reviewableTypes.push('group');
        } else {
          if (task.divisionId && ledDivisionIds.includes(task.divisionId)) {
            reviewableTypes.push('division');
          }
          if (task.groupId && ledGroupIds.includes(task.groupId)) {
            reviewableTypes.push('group');
          }
        }
        const existingTypes = reviews.map(r => r.reviewType);
        reviewableTypes = reviewableTypes.filter(t => !existingTypes.includes(t as any));
      }

      let canVerifyCompletion = false;
      if (task.status === TaskStatus.PENDING_COMPLETION) {
        if (user.isSuperAdmin || user.roleLevel >= RoleLevel.PROJECT_MANAGER) {
          canVerifyCompletion = true;
        } else {
          if (task.divisionId && ledDivisionIds.includes(task.divisionId)) canVerifyCompletion = true;
          if (task.groupId && ledGroupIds.includes(task.groupId)) canVerifyCompletion = true;
        }
      }

      return { ...task, reviews, reviewableTypes, canVerifyCompletion };
    });
  }

  private getWeekNumber(date: Date): number {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    const dayNum = d.getUTCDay() || 7;
    d.setUTCDate(d.getUTCDate() + 4 - dayNum);
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return Math.ceil(((d.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  }
}