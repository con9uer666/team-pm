import { Injectable, UnauthorizedException, ConflictException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';
import { User, RoleLevel } from '../../entities';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    private readonly jwtService: JwtService,
  ) {}

  async register(dto: { username: string; password: string; realName: string; email: string }) {
    const existing = await this.userRepo.findOne({ where: { username: dto.username } });
    if (existing) {
      throw new ConflictException('用户名已存在');
    }

    const emailExists = await this.userRepo.findOne({ where: { email: dto.email } });
    if (emailExists) {
      throw new ConflictException('邮箱已被使用');
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
    });

    await this.userRepo.save(user);
    return this.generateToken(user);
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
      },
    };
  }
}
