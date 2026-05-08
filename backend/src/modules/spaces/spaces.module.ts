import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SpacesController } from './spaces.controller';
import { SpacesService } from './spaces.service';
import { User, Group, Division, Task, Objective } from '../../entities';
import { ApprovalGuard } from '../../common/guards/approval.guard';
import { RolesGuard } from '../../common/guards/roles.guard';

@Module({
  imports: [TypeOrmModule.forFeature([User, Group, Division, Task, Objective])],
  controllers: [SpacesController],
  providers: [SpacesService, ApprovalGuard, RolesGuard],
  exports: [SpacesService],
})
export class SpacesModule {}
