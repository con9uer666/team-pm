import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Unique } from 'typeorm';

export enum ReviewType {
  DIVISION = 'division',
  GROUP = 'group',
}

export enum ReviewStatus {
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

@Entity('task_reviews')
@Unique(['taskId', 'reviewType'])
export class TaskReview {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'task_id', type: 'uuid' })
  taskId: string;

  @Column({ name: 'reviewer_id', type: 'uuid' })
  reviewerId: string;

  @Column({ name: 'review_type', type: 'varchar', length: 20 })
  reviewType: ReviewType;

  @Column({ type: 'varchar', length: 20 })
  status: ReviewStatus;

  @Column({ name: 'rejection_reason', type: 'text', nullable: true })
  rejectionReason: string | null;

  @CreateDateColumn({ name: 'reviewed_at' })
  reviewedAt: Date;
}
