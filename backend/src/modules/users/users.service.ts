import { Injectable, NotFoundException, ConflictException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { User, RoleLevel } from '../../entities';
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

  async updateRole(id: string, roleLevel: number, operatorId: string) {
    const operator = await this.userRepo.findOne({ where: { id: operatorId } });
    if (!operator) throw new NotFoundException('操作者不存在');

    if (!operator.isSuperAdmin && roleLevel >= operator.roleLevel) {
      throw new ForbiddenException('不能设置等于或高于自己的角色等级');
    }

    const target = await this.userRepo.findOne({ where: { id } });
    if (!target) throw new NotFoundException('用户不存在');
    if (target.isSuperAdmin) throw new ForbiddenException('不可修改超级管理员');

    await this.userRepo.update(id, { roleLevel });
    return this.findById(id);
  }

  async assignGroups(userId: string, groupIds: string[]) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('用户不存在');
    user.groupIds = groupIds.length ? groupIds : null;
    return this.userRepo.save(user);
  }

  async assignDivisions(userId: string, divisionIds: string[]) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('用户不存在');
    user.divisionIds = divisionIds.length ? divisionIds : null;
    return this.userRepo.save(user);
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

  async createUser(dto: { username: string; password: string; realName: string; roleLevel?: number; groupIds?: string[]; divisionIds?: string[] }) {
    const existing = await this.userRepo.findOne({ where: { username: dto.username } });
    if (existing) throw new ConflictException('用户名已存在');

    const passwordHash = await bcrypt.hash(dto.password, 10);
    const user = this.userRepo.create({
      username: dto.username,
      passwordHash,
      realName: dto.realName,
      roleLevel: dto.roleLevel || 1,
      groupIds: dto.groupIds?.length ? dto.groupIds : null,
      divisionIds: dto.divisionIds?.length ? dto.divisionIds : null,
    });
    const saved = await this.userRepo.save(user);
    return { id: saved.id, username: saved.username, realName: saved.realName, roleLevel: saved.roleLevel };
  }

  async removeUser(id: string) {
    const user = await this.userRepo.findOne({ where: { id } });
    if (!user) throw new NotFoundException('用户不存在');
    if (user.isSuperAdmin) throw new ForbiddenException('超级管理员账号不可删除');
    await this.userRepo.remove(user);
    return { message: '用户已删除' };
  }

  async setGroupLeaders(groupId: string, leaderIds: string[]) {
    const group = await this.groupRepo.findOne({ where: { id: groupId } });
    if (!group) throw new NotFoundException('技术组不存在');
    group.leaderIds = leaderIds.length ? leaderIds : null;
    return this.groupRepo.save(group);
  }

  async setDivisionLeaders(divisionId: string, leaderIds: string[]) {
    const division = await this.divisionRepo.findOne({ where: { id: divisionId } });
    if (!division) throw new NotFoundException('兵种不存在');
    division.leaderIds = leaderIds.length ? leaderIds : null;
    return this.divisionRepo.save(division);
  }

  async getOrganizationStructure() {
    const [users, groups, divisions] = await Promise.all([
      this.userRepo.find({
        select: ['id', 'username', 'realName', 'roleLevel', 'groupIds', 'divisionIds', 'status', 'isSuperAdmin'],
        order: { roleLevel: 'DESC', realName: 'ASC' },
      }),
      this.groupRepo.find({ order: { createdAt: 'ASC' } }),
      this.divisionRepo.find({ order: { createdAt: 'ASC' } }),
    ]);
    return { users, groups, divisions };
  }
}
