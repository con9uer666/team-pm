import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User, ApprovalStatus } from '../../entities';
import { ALLOW_PENDING_KEY } from '../decorators/allow-pending.decorator';

@Injectable()
export class ApprovalGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const allowPending = this.reflector.getAllAndOverride<boolean>(ALLOW_PENDING_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (allowPending) return true;

    const request = context.switchToHttp().getRequest();
    const jwtUser = request.user;
    if (!jwtUser) return true;

    const user = await this.userRepo.findOne({ where: { id: jwtUser.id } });
    if (!user) throw new ForbiddenException('用户不存在');

    if (user.approvalStatus !== ApprovalStatus.APPROVED) {
      throw new ForbiddenException('账号待审核，暂无权限');
    }
    return true;
  }
}
