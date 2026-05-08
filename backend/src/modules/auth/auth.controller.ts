import { Controller, Post, Body, Res, UseGuards, Req } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AuthService } from './auth.service';
import { IsString, MinLength, MaxLength, IsEmail, IsArray, ArrayMinSize, IsUUID, IsBoolean, IsOptional } from 'class-validator';
import type { Response, Request } from 'express';

export class RegisterDto {
  @IsString()
  @MinLength(3)
  @MaxLength(50)
  username: string;

  @IsString()
  @MinLength(6)
  password: string;

  @IsString()
  @MinLength(1)
  @MaxLength(50)
  realName: string;

  @IsEmail({}, { message: '邮箱格式不正确' })
  email: string;

  @IsArray()
  @ArrayMinSize(1, { message: '请至少选择一个技术组' })
  @IsUUID('4', { each: true })
  groupIds: string[];
}

export class LoginDto {
  @IsString()
  username: string;

  @IsString()
  password: string;

  @IsOptional()
  @IsBoolean()
  rememberMe?: boolean;
}

const BASE_COOKIE = {
  httpOnly: true,
  sameSite: 'strict' as const,
  path: '/',
};

const PERSISTENT_MAX_AGE = 7 * 24 * 60 * 60 * 1000;

@Controller('api/auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  async register(@Body() dto: RegisterDto, @Res({ passthrough: true }) res: Response) {
    const { accessToken, user } = await this.authService.register(dto);
    res.cookie('token', accessToken, { ...BASE_COOKIE, maxAge: PERSISTENT_MAX_AGE });
    return { user };
  }

  @Post('login')
  async login(@Body() dto: LoginDto, @Res({ passthrough: true }) res: Response) {
    const { accessToken, user } = await this.authService.login(dto);
    const cookieOpts = dto.rememberMe === false
      ? BASE_COOKIE
      : { ...BASE_COOKIE, maxAge: PERSISTENT_MAX_AGE };
    res.cookie('token', accessToken, cookieOpts);
    return { user };
  }

  @Post('logout')
  @UseGuards(AuthGuard('jwt'))
  async logout(@Req() req: Request, @Res({ passthrough: true }) res: Response) {
    const user = req.user as { id: string };
    await this.authService.logout(user.id);
    res.clearCookie('token', { path: '/' });
    return { message: 'ok' };
  }
}
