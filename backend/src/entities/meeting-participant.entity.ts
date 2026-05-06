import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';
import { AttendanceStatus } from './meeting.entity';

@Entity('meeting_participants')
export class MeetingParticipant {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'meeting_id', type: 'uuid' })
  meetingId: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ name: 'attendance_status', type: 'enum', enum: AttendanceStatus, default: AttendanceStatus.PENDING })
  attendanceStatus: AttendanceStatus;

  @Column({ name: 'check_in_time', type: 'timestamp', nullable: true })
  checkInTime: Date | null;
}

@Entity('meeting_minutes')
export class MeetingMinutes {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'meeting_id', type: 'uuid' })
  meetingId: string;

  @Column({ type: 'text' })
  content: string;

  @Column({ name: 'recorder_id', type: 'uuid' })
  recorderId: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @Column({ name: 'updated_at', type: 'timestamp', nullable: true })
  updatedAt: Date | null;
}
