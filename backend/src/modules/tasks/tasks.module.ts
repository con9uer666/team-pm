import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TasksController } from './tasks.controller';
import { TasksService } from './tasks.service';
import { Task, TaskDependency, TaskReview, User, Division, Group } from '../../entities';

@Module({
  imports: [TypeOrmModule.forFeature([Task, TaskDependency, TaskReview, User, Division, Group])],
  controllers: [TasksController],
  providers: [TasksService],
  exports: [TasksService],
})
export class TasksModule {}
