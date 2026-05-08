import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Request } from 'express';
import { User } from '../../entities';

function cookieExtractor(req: Request): string | null {
  return req?.cookies?.token || null;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    config: ConfigService,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromExtractors([
        cookieExtractor,
        ExtractJwt.fromAuthHeaderAsBearerToken(),
      ]),
      secretOrKey: config.get<string>('JWT_SECRET')!,
    });
  }

  async validate(payload: { sub: string; username: string; roleLevel: number; sessionToken: string }) {
    const user = await this.userRepo.findOne({ where: { id: payload.sub } });
    if (!user || user.sessionToken !== payload.sessionToken) {
      throw new UnauthorizedException('会话已失效，请重新登录');
    }
    return { id: payload.sub, username: payload.username, roleLevel: payload.roleLevel };
  }
}
