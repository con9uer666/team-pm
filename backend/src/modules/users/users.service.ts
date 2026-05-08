import { Injectable, NotFoundException, ConflictException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { User, RoleLevel, Position, ApprovalStatus } from '../../entities';
import { Group, Division } from '../../entities';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Group)
    private readonly groupRepo: Repository<Group>,
    @InjectRepository(Division)
    private readonly divisionRepo: Repository<Division>,
  ) {}

  findAll() {
    return this.userRepo.find({ order: { roleLevel: 'DESC', createdAt: 'DESC' } });
  }

  findById(id: string) {
    return this.userRepo.findOne({ where: { id } });
  }

  async updateRole(
    id: string,
    roleLevel: number,
    operatorId: string,
    position?: Position | null,
  ) {
    const operator = await this.userRepo.findOne({ where: { id: operatorId } });
    if (!operator) throw new NotFoundException('操作者不存在');

    if (!operator.isSuperAdmin && roleLevel >= operator.roleLevel) {
      throw new ForbiddenException('不能设置等于或高于自己的角色等级');
    }

    const target = await this.userRepo.findOne({ where: { id } });
    if (!target) throw new NotFoundException('用户不存在');
    if (target.isSuperAdmin) throw new ForbiddenException('不可修改超级管理员');

    const patch: Partial<User> = { roleLevel };
    if (position !== undefined) {
      patch.position = position;
    } else if (roleLevel < RoleLevel.VICE_CAPTAIN) {
      // 角色降回组长以下时清空 position
      patch.position = null;
    }
    await this.userRepo.update(id, patch);
    return this.findById(id);
  }

  async updatePosition(id: string, position: Position | null, operatorId: string) {
    const operator = await this.userRepo.findOne({ where: { id: operatorId } });
    if (!operator) throw new NotFoundException('操作者不存在');
    const target = await this.userRepo.findOne({ where: { id } });
    if (!target) throw new NotFoundException('用户不存在');
    if (target.isSuperAdmin && !operator.isSuperAdmin) {
      throw new ForbiddenException('不可修改超级管理员');
    }
    target.position = position;
    await this.userRepo.save(target);
    return target;
  }

  async resetPassword(id: string, newPassword: string, operatorId: string) {
    if (!newPassword || newPassword.length < 6) {
      throw new BadRequestException('密码至少 6 位');
    }
    const [operator, target] = await Promise.all([
      this.userRepo.findOne({ where: { id: operatorId } }),
      this.userRepo.findOne({ where: { id } }),
    ]);
    if (!operator || !target) throw new NotFoundException('用户不存在');
    if (target.isSuperAdmin && !operator.isSuperAdmin) {
      throw new ForbiddenException('不可修改超级管理员密码');
    }
    if (
      !operator.isSuperAdmin &&
      target.id !== operator.id &&
      target.roleLevel >= operator.roleLevel
    ) {
      throw new ForbiddenException('不能修改同级或更高等级用户的密码');
    }
    target.passwordHash = await bcrypt.hash(newPassword, 10);
    target.sessionToken = null;
    await this.userRepo.save(target);
    return { message: '密码已重置' };
  }

  async assignGroups(userId: string, groupIds: string[]) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('用户不存在');

    const oldIds = user.groupIds || [];
    const removed = oldIds.filter(id => !groupIds.includes(id));

    user.groupIds = groupIds.length ? groupIds : null;
    await this.userRepo.save(user);

    for (const removedId of removed) {
      const group = await this.groupRepo.findOne({ where: { id: removedId } });
      if (group?.leaderIds?.includes(userId)) {
        const next = group.leaderIds.filter(x => x !== userId);
        group.leaderIds = next.length ? next : null;
        await this.groupRepo.save(group);
      }
    }

    return user;
  }

  async assignDivisions(userId: string, divisionIds: string[]) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('用户不存在');

    const oldIds = user.divisionIds || [];
    const removed = oldIds.filter(id => !divisionIds.includes(id));

    user.divisionIds = divisionIds.length ? divisionIds : null;
    await this.userRepo.save(user);

    for (const removedId of removed) {
      const division = await this.divisionRepo.findOne({ where: { id: removedId } });
      if (division?.leaderIds?.includes(userId)) {
        const next = division.leaderIds.filter(x => x !== userId);
        division.leaderIds = next.length ? next : null;
        await this.divisionRepo.save(division);
      }
    }

    return user;
  }

  // 组织架构
  findAllGroups() {
    return this.groupRepo.find({ order: { createdAt: 'ASC' } });
  }

  createGroup(dto: { name: string; leaderIds?: string[]; divisionId?: string }) {
    const group = this.groupRepo.create(dto);
    return this.groupRepo.save(group);
  }

  findAllDivisions() {
    return this.divisionRepo.find({ order: { createdAt: 'ASC' } });
  }

  createDivision(dto: { name: string; leaderIds?: string[]; description?: string }) {
    const division = this.divisionRepo.create(dto);
    return this.divisionRepo.save(division);
  }

  async createUser(dto: {
    username: string;
    password: string;
    realName: string;
    roleLevel?: number;
    position?: Position | null;
    groupIds?: string[];
    divisionIds?: string[];
    email?: string;
  }, operatorId?: string) {
    const existing = await this.userRepo.findOne({ where: { username: dto.username } });
    if (existing) throw new ConflictException('用户名已存在');

    const passwordHash = await bcrypt.hash(dto.password, 10);
    const now = new Date();
    const user = this.userRepo.create({
      username: dto.username,
      passwordHash,
      realName: dto.realName,
      roleLevel: dto.roleLevel || 1,
      position: dto.position ?? null,
      groupIds: dto.groupIds?.length ? dto.groupIds : null,
      divisionIds: dto.divisionIds?.length ? dto.divisionIds : null,
      email: dto.email?.trim() || null,
      approvalStatus: ApprovalStatus.APPROVED,
      approvalReviewerId: operatorId ?? null,
      approvalReviewedAt: now,
    });
    const saved = await this.userRepo.save(user);
    return saved;
  }

  async removeUser(id: string) {
    const user = await this.userRepo.findOne({ where: { id } });
    if (!user) throw new NotFoundException('用户不存在');
    if (user.isSuperAdmin) throw new ForbiddenException('超级管理员账号不可删除');

    const [groups, divisions] = await Promise.all([
      this.groupRepo.find(),
      this.divisionRepo.find(),
    ]);
    for (const g of groups) {
      if (g.leaderIds?.includes(id)) {
        const next = g.leaderIds.filter(x => x !== id);
        g.leaderIds = next.length ? next : null;
        await this.groupRepo.save(g);
      }
    }
    for (const d of divisions) {
      if (d.leaderIds?.includes(id)) {
        const next = d.leaderIds.filter(x => x !== id);
        d.leaderIds = next.length ? next : null;
        await this.divisionRepo.save(d);
      }
    }

    await this.userRepo.remove(user);
    return { message: '用户已删除' };
  }

  async setGroupLeaders(groupId: string, leaderIds: string[]) {
    const group = await this.groupRepo.findOne({ where: { id: groupId } });
    if (!group) throw new NotFoundException('技术组不存在');

    if (leaderIds.length) {
      const leaders = await this.userRepo.find({ where: { id: In(leaderIds) } });
      if (leaders.length !== leaderIds.length) {
        throw new BadRequestException('部分用户不存在');
      }
      const unapproved = leaders.find(u => u.approvalStatus !== ApprovalStatus.APPROVED);
      if (unapproved) {
        throw new BadRequestException('未审核用户不可设为组长');
      }
      for (const u of leaders) {
        let dirty = false;
        if (u.roleLevel < RoleLevel.GROUP_LEADER) {
          u.roleLevel = RoleLevel.GROUP_LEADER;
          dirty = true;
        }
        const current = u.groupIds || [];
        if (!current.includes(groupId)) {
          u.groupIds = [...current, groupId];
          dirty = true;
        }
        if (dirty) await this.userRepo.save(u);
      }
    }

    group.leaderIds = leaderIds.length ? leaderIds : null;
    return this.groupRepo.save(group);
  }

  async setDivisionLeaders(divisionId: string, leaderIds: string[]) {
    const division = await this.divisionRepo.findOne({ where: { id: divisionId } });
    if (!division) throw new NotFoundException('兵种不存在');

    if (leaderIds.length) {
      const leaders = await this.userRepo.find({ where: { id: In(leaderIds) } });
      if (leaders.length !== leaderIds.length) {
        throw new BadRequestException('部分用户不存在');
      }
      const unapproved = leaders.find(u => u.approvalStatus !== ApprovalStatus.APPROVED);
      if (unapproved) {
        throw new BadRequestException('未审核用户不可设为组长');
      }
      for (const u of leaders) {
        let dirty = false;
        if (u.roleLevel < RoleLevel.GROUP_LEADER) {
          u.roleLevel = RoleLevel.GROUP_LEADER;
          dirty = true;
        }
        const current = u.divisionIds || [];
        if (!current.includes(divisionId)) {
          u.divisionIds = [...current, divisionId];
          dirty = true;
        }
        if (dirty) await this.userRepo.save(u);
      }
    }

    division.leaderIds = leaderIds.length ? leaderIds : null;
    return this.divisionRepo.save(division);
  }

  async getOrganizationStructure() {
    const [users, groups, divisions] = await Promise.all([
      this.userRepo.find({
        select: ['id', 'username', 'realName', 'roleLevel', 'position', 'groupIds', 'divisionIds', 'status', 'isSuperAdmin'],
        order: { roleLevel: 'DESC', realName: 'ASC' },
      }),
      this.groupRepo.find({ order: { createdAt: 'ASC' } }),
      this.divisionRepo.find({ order: { createdAt: 'ASC' } }),
    ]);
    return { users, groups, divisions };
  }
}
