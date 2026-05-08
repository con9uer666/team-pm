import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { WechatService } from './wechat.service';
import { WechatController } from './wechat.controller';
import { User } from '../../entities';

@Module({
  imports: [TypeOrmModule.forFeature([User])],
  controllers: [WechatController],
  providers: [WechatService],
  exports: [WechatService],
})
export class WechatModule {}
