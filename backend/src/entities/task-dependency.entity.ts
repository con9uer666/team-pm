import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

@Entity('task_dependencies')
export class TaskDependency {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'task_id', type: 'uuid' })
  taskId: string;

  @Column({ name: 'depends_on_task_id', type: 'uuid' })
  dependsOnTaskId: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
