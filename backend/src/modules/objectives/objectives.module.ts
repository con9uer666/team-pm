import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ObjectivesController } from './objectives.controller';
import { ObjectivesService } from './objectives.service';
import { Objective, Task, User, Group, Division } from '../../entities';
import { NotificationsModule } from '../notifications/notifications.module';
import { ApprovalGuard } from '../../common/guards/approval.guard';
import { RolesGuard } from '../../common/guards/roles.guard';

@Module({
  imports: [
    TypeOrmModule.forFeature([Objective, Task, User, Group, Division]),
    NotificationsModule,
  ],
  controllers: [ObjectivesController],
  providers: [ObjectivesService, ApprovalGuard, RolesGuard],
  exports: [ObjectivesService],
})
export class ObjectivesModule {}
