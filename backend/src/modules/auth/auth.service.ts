import { Injectable, UnauthorizedException, ConflictException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Not, Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';
import { User, RoleLevel, ApprovalStatus, Group, NotificationType } from '../../entities';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Group)
    private readonly groupRepo: Repository<Group>,
    private readonly jwtService: JwtService,
    private readonly notifications: NotificationsService,
  ) {}

  async register(dto: { username: string; password: string; realName: string; email: string; groupIds: string[] }) {
    const existing = await this.userRepo.findOne({ where: { username: dto.username } });
    if (existing) {
      throw new ConflictException('用户名已存在');
    }

    const emailExists = await this.userRepo.findOne({ where: { email: dto.email } });
    if (emailExists) {
      throw new ConflictException('邮箱已被使用');
    }

    const groups = await this.groupRepo.find({ where: { id: In(dto.groupIds) } });
    if (groups.length !== dto.groupIds.length) {
      throw new ConflictException('存在无效的技术组');
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);
    const sessionToken = randomUUID();
    const user = this.userRepo.create({
      username: dto.username,
      passwordHash,
      realName: dto.realName,
      email: dto.email,
      roleLevel: RoleLevel.RESERVE_MEMBER,
      sessionToken,
      groupIds: dto.groupIds,
      divisionIds: null,
      approvalStatus: ApprovalStatus.PENDING,
    });

    const saved = await this.userRepo.save(user);
    await this.notifyApprovers(saved, groups);
    return this.generateToken(saved);
  }

  private async notifyApprovers(target: User, groups: Group[]) {
    const leaderIds = new Set<string>();
    for (const g of groups) {
      (g.leaderIds || []).forEach(id => leaderIds.add(id));
    }
    const highLevel = await this.userRepo.find({
      where: { roleLevel: In([RoleLevel.PROJECT_MANAGER, RoleLevel.TEAM_CAPTAIN, RoleLevel.INSTRUCTOR]) },
    });
    highLevel.forEach(u => leaderIds.add(u.id));
    leaderIds.delete(target.id);

    if (!leaderIds.size) return;
    const groupNames = groups.map(g => g.name).join('、');
    await this.notifications.createBatch(
      Array.from(leaderIds),
      NotificationType.GENERAL,
      '新成员待审核',
      `${target.realName}（${target.username}）申请加入：${groupNames}`,
      target.id,
    );
  }

  async login(dto: { username: string; password: string }) {
    const user = await this.userRepo.findOne({ where: { username: dto.username } });
    if (!user) {
      throw new UnauthorizedException('用户名或密码错误');
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedException('用户名或密码错误');
    }

    user.sessionToken = randomUUID();
    await this.userRepo.save(user);
    return this.generateToken(user);
  }

  async logout(userId: string) {
    await this.userRepo.update(userId, { sessionToken: null });
  }

  private generateToken(user: User) {
    const payload = {
      sub: user.id,
      username: user.username,
      roleLevel: user.roleLevel,
      sessionToken: user.sessionToken,
    };
    return {
      accessToken: this.jwtService.sign(payload),
      user: {
        id: user.id,
        username: user.username,
        realName: user.realName,
        roleLevel: user.roleLevel,
        isSuperAdmin: user.isSuperAdmin,
        approvalStatus: user.approvalStatus,
      },
    };
  }
}
