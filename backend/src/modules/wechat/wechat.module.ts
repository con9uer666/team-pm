import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { WechatService } from './wechat.service';
import { WechatController } from './wechat.controller';
import { User } from '../../entities';
import { ApprovalGuard } from '../../common/guards/approval.guard';

@Module({
  imports: [TypeOrmModule.forFeature([User])],
  controllers: [WechatController],
  providers: [WechatService, ApprovalGuard],
  exports: [WechatService],
})
export class WechatModule {}
