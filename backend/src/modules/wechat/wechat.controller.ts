import { Body, Controller, Get, Logger, Post, UseGuards, Req } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../../entities';
import { WechatService } from './wechat.service';

@Controller('api/wechat')
export class WechatController {
  private readonly logger = new Logger(WechatController.name);

  constructor(
    private readonly wechatService: WechatService,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
  ) {}

  @Get('bind-qrcode')
  @UseGuards(AuthGuard('jwt'))
  async getBindQrcode(@Req() req: any) {
    const userId = req.user.userId;
    const url = await this.wechatService.createBindQrcode(userId);
    if (!url) {
      return { success: false, message: '微信推送未配置或生成二维码失败' };
    }
    return { success: true, qrcodeUrl: url };
  }

  @Post('callback')
  async callback(@Body() body: any) {
    this.logger.log(`WxPusher callback: ${JSON.stringify(body)}`);
    try {
      const action = body?.action;
      const data = body?.data || {};
      const uid: string | undefined = data.uid;
      const extra: string | undefined = data.extra;

      if (action === 'subscribe' && uid && extra) {
        const user = await this.userRepo.findOne({ where: { id: extra } });
        if (user) {
          user.wechatWorkId = uid;
          await this.userRepo.save(user);
          this.logger.log(`Bound WxPusher UID ${uid} to user ${user.username}`);
          await this.wechatService.sendMessage(
            uid,
            '绑定成功',
            `## 绑定成功\n\n你好 **${user.realName}**，你已成功绑定战队项目管理系统通知。\n\n今后任务派发、审核结果、会议提醒将第一时间推送到这里。`,
          );
        } else {
          this.logger.warn(`Callback extra=${extra} not matched to any user`);
        }
      }
    } catch (e: any) {
      this.logger.error(`Callback error: ${e.message}`);
    }
    return { code: 1000, msg: 'ok' };
  }
}
