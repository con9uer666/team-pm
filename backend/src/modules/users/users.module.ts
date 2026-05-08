import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersController, OrganizationController } from './users.controller';
import { UsersService } from './users.service';
import { User, Group, Division } from '../../entities';
import { ApprovalGuard } from '../../common/guards/approval.guard';

@Module({
  imports: [TypeOrmModule.forFeature([User, Group, Division])],
  controllers: [UsersController, OrganizationController],
  providers: [UsersService, ApprovalGuard],
  exports: [UsersService],
})
export class UsersModule {}
