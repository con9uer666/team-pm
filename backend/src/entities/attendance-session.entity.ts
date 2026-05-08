import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, Index } from 'typeorm';

export enum AttendanceSessionStatus {
  ACTIVE = 'active',
  CLOSED = 'closed',
  AUTO_CLOSED = 'auto_closed',
}

@Entity('attendance_sessions')
@Index(['userId', 'status'])
export class AttendanceSession {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ name: 'clock_in_at', type: 'timestamptz' })
  clockInAt: Date;

  @Column({ name: 'clock_in_lat', type: 'double precision' })
  clockInLat: number;

  @Column({ name: 'clock_in_lng', type: 'double precision' })
  clockInLng: number;

  @Column({ name: 'clock_in_address', type: 'text', nullable: true })
  clockInAddress: string | null;

  @Column({ name: 'clock_in_fence_id', type: 'uuid', nullable: true })
  clockInFenceId: string | null;

  @Column({ name: 'clock_out_at', type: 'timestamptz', nullable: true })
  clockOutAt: Date | null;

  @Column({ name: 'clock_out_lat', type: 'double precision', nullable: true })
  clockOutLat: number | null;

  @Column({ name: 'clock_out_lng', type: 'double precision', nullable: true })
  clockOutLng: number | null;

  @Column({ name: 'clock_out_address', type: 'text', nullable: true })
  clockOutAddress: string | null;

  @Column({ type: 'varchar', length: 20, default: AttendanceSessionStatus.ACTIVE })
  status: AttendanceSessionStatus;

  @Column({ name: 'duration_minutes', type: 'int', default: 0 })
  durationMinutes: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
