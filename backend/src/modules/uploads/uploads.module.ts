import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UploadsController } from './uploads.controller';
import { User } from '../../entities';
import { ApprovalGuard } from '../../common/guards/approval.guard';

@Module({
  imports: [TypeOrmModule.forFeature([User])],
  controllers: [UploadsController],
  providers: [ApprovalGuard],
})
export class UploadsModule {}
