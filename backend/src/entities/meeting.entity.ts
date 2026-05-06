import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

export enum MeetingScope {
  GROUP = 'group',
  DIVISION = 'division',
  TEAM = 'team',
}

export enum MeetingStatus {
  SCHEDULED = 'scheduled',
  IN_PROGRESS = 'in_progress',
  ENDED = 'ended',
  CANCELLED = 'cancelled',
}

export enum AttendanceStatus {
  PENDING = 'pending',
  PRESENT = 'present',
  LATE = 'late',
  ABSENT = 'absent',
}

@Entity('meetings')
export class Meeting {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 200 })
  title: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({ name: 'organizer_id', type: 'uuid' })
  organizerId: string;

  @Column({ name: 'group_id', type: 'uuid', nullable: true })
  groupId: string | null;

  @Column({ name: 'division_id', type: 'uuid', nullable: true })
  divisionId: string | null;

  @Column({ type: 'enum', enum: MeetingScope })
  scope: MeetingScope;

  @Column({ type: 'varchar', length: 200, nullable: true })
  location: string | null;

  @Column({ name: 'start_time', type: 'timestamp' })
  startTime: Date;

  @Column({ name: 'end_time', type: 'timestamp' })
  endTime: Date;

  @Column({ type: 'enum', enum: MeetingStatus, default: MeetingStatus.SCHEDULED })
  status: MeetingStatus;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
