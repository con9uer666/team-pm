import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

export enum NotificationType {
  TASK_APPROVED = 'task_approved',
  TASK_REJECTED = 'task_rejected',
  TASK_OVERDUE = 'task_overdue',
  TASK_ASSIGNED = 'task_assigned',
  TASK_APPEALED = 'task_appealed',
  MEETING_SCHEDULED = 'meeting_scheduled',
  MEETING_REMINDER = 'meeting_reminder',
  MEETING_STARTED = 'meeting_started',
  GENERAL = 'general',
}

@Entity('notifications')
export class Notification {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ type: 'enum', enum: NotificationType, default: NotificationType.GENERAL })
  type: NotificationType;

  @Column({ length: 200 })
  title: string;

  @Column({ type: 'text', nullable: true })
  content: string | null;

  @Column({ name: 'related_id', type: 'uuid', nullable: true })
  relatedId: string | null;

  @Column({ name: 'is_read', default: false })
  isRead: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
