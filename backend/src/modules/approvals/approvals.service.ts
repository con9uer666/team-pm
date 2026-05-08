import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { User, Group, ApprovalStatus, RoleLevel, NotificationType } from '../../entities';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class ApprovalsService {
  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Group)
    private readonly groupRepo: Repository<Group>,
    private readonly notifications: NotificationsService,
  ) {}

  async getMyStatus(userId: string) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('用户不存在');
    return {
      approvalStatus: user.approvalStatus,
      approvalRejectReason: user.approvalRejectReason,
      approvalReviewedAt: user.approvalReviewedAt,
    };
  }

  async listPending(operatorId: string) {
    const operator = await this.userRepo.findOne({ where: { id: operatorId } });
    if (!operator) throw new NotFoundException('操作者不存在');

    const pendingUsers = await this.userRepo.find({
      where: { approvalStatus: ApprovalStatus.PENDING },
      order: { createdAt: 'DESC' },
    });

    if (operator.isSuperAdmin || operator.roleLevel >= RoleLevel.PROJECT_MANAGER) {
      return pendingUsers;
    }

    const ledGroupIds = await this.getLedGroupIds(operatorId);
    if (!ledGroupIds.length) return [];
    return pendingUsers.filter(u => (u.groupIds || []).some(id => ledGroupIds.includes(id)));
  }

  async approve(
    userId: string,
    operatorId: string,
    dto: { roleLevel?: number; groupIds?: string[]; divisionIds?: string[] },
  ) {
    const operator = await this.userRepo.findOne({ where: { id: operatorId } });
    const target = await this.userRepo.findOne({ where: { id: userId } });
    if (!operator || !target) throw new NotFoundException('用户不存在');
    if (target.approvalStatus === ApprovalStatus.APPROVED) {
      throw new BadRequestException('该用户已通过审核');
    }

    const isHigh = operator.isSuperAdmin || operator.roleLevel >= RoleLevel.PROJECT_MANAGER;

    if (!isHigh) {
      const ledGroupIds = await this.getLedGroupIds(operatorId);
      const overlap = (target.groupIds || []).some(id => ledGroupIds.includes(id));
      if (!overlap) throw new ForbiddenException('您无权审核该用户');
      if (dto.divisionIds !== undefined) {
        throw new ForbiddenException('组长无权分配兵种组');
      }
    }

    if (dto.roleLevel !== undefined) {
      if (!isHigh && dto.roleLevel >= RoleLevel.PROJECT_MANAGER) {
        throw new ForbiddenException('组长只能授予组长及以下角色');
      }
      target.roleLevel = dto.roleLevel;
    }
    if (dto.groupIds !== undefined) {
      target.groupIds = dto.groupIds.length ? dto.groupIds : null;
    }
    if (dto.divisionIds !== undefined) {
      target.divisionIds = dto.divisionIds.length ? dto.divisionIds : null;
    }

    target.approvalStatus = ApprovalStatus.APPROVED;
    target.approvalReviewerId = operatorId;
    target.approvalReviewedAt = new Date();
    target.approvalRejectReason = null;
    const saved = await this.userRepo.save(target);

    await this.notifications.create(
      target.id,
      NotificationType.GENERAL,
      '账号审核通过',
      `欢迎加入，你可以开始使用系统的全部功能。`,
      undefined,
    );
    return saved;
  }

  async reject(userId: string, operatorId: string, reason: string) {
    if (!reason || !reason.trim()) throw new BadRequestException('请填写拒绝原因');
    const operator = await this.userRepo.findOne({ where: { id: operatorId } });
    const target = await this.userRepo.findOne({ where: { id: userId } });
    if (!operator || !target) throw new NotFoundException('用户不存在');
    if (target.approvalStatus === ApprovalStatus.APPROVED) {
      throw new BadRequestException('该用户已通过审核，无法驳回');
    }

    const isHigh = operator.isSuperAdmin || operator.roleLevel >= RoleLevel.PROJECT_MANAGER;
    if (!isHigh) {
      const ledGroupIds = await this.getLedGroupIds(operatorId);
      const overlap = (target.groupIds || []).some(id => ledGroupIds.includes(id));
      if (!overlap) throw new ForbiddenException('您无权审核该用户');
    }

    target.approvalStatus = ApprovalStatus.REJECTED;
    target.approvalReviewerId = operatorId;
    target.approvalReviewedAt = new Date();
    target.approvalRejectReason = reason.trim();
    const saved = await this.userRepo.save(target);

    await this.notifications.create(
      target.id,
      NotificationType.GENERAL,
      '账号审核未通过',
      `原因：${reason.trim()}`,
      undefined,
    );
    return saved;
  }

  private async getLedGroupIds(userId: string): Promise<string[]> {
    const groups = await this.groupRepo.find();
    return groups.filter(g => g.leaderIds?.includes(userId)).map(g => g.id);
  }
}
