import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';

export enum TaskStatus {
  PENDING_REVIEW = 'pending_review',
  APPROVED = 'approved',
  REJECTED = 'rejected',
  PENDING_COMPLETION = 'pending_completion',
  COMPLETED = 'completed',
  OVERDUE = 'overdue',
  BLOCKED = 'blocked',
}

@Entity('tasks')
export class Task {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 200 })
  title: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({ type: 'text', nullable: true })
  content: string | null;

  @Column({ name: 'division_id', type: 'uuid', nullable: true })
  divisionId: string | null;

  @Column({ name: 'group_id', type: 'uuid', nullable: true })
  groupId: string | null;

  @Column({ name: 'completion_requirements', type: 'text', nullable: true })
  completionRequirements: string | null;

  @Column({ name: 'creator_id' })
  creatorId: string;

  @Column({ name: 'assignee_id' })
  assigneeId: string;

  @Column({ type: 'varchar', length: 20, default: TaskStatus.PENDING_REVIEW })
  status: TaskStatus;

  @Column({ type: 'int', default: 0 })
  priority: number;

  @Column({ name: 'week_year', type: 'int' })
  weekYear: number;

  @Column({ name: 'week_number', type: 'int' })
  weekNumber: number;

  @Column({ name: 'due_date', type: 'timestamp' })
  dueDate: Date;

  @Column({ name: 'completed_at', type: 'timestamp', nullable: true })
  completedAt: Date;

  @Column({ name: 'completion_attachments', type: 'simple-array', nullable: true })
  completionAttachments: string[] | null;

  @Column({ name: 'completion_note', type: 'text', nullable: true })
  completionNote: string | null;

  @Column({ name: 'overdue_minutes', type: 'int', default: 0 })
  overdueMinutes: number;

  @Column({ name: 'rejection_reason', type: 'text', nullable: true })
  rejectionReason: string | null;

  @Column({ name: 'rejected_by', type: 'uuid', nullable: true })
  rejectedBy: string | null;

  @Column({ name: 'reviewed_by', type: 'uuid', nullable: true })
  reviewedBy: string;

  @Column({ name: 'reviewed_at', type: 'timestamp', nullable: true })
  reviewedAt: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
