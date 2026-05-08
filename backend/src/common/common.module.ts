import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../entities';
import { ApprovalGuard } from './guards/approval.guard';

@Module({
  imports: [TypeOrmModule.forFeature([User])],
  providers: [ApprovalGuard],
  exports: [ApprovalGuard, TypeOrmModule],
})
export class CommonModule {}
