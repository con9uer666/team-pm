import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, ManyToOne, JoinColumn } from 'typeorm';

export enum RoleLevel {
  RESERVE_MEMBER = 1,
  OFFICIAL_MEMBER = 2,
  GROUP_LEADER = 3,
  VICE_CAPTAIN = 4,
  PROJECT_MANAGER = 5,
  TEAM_CAPTAIN = 5,
  INSTRUCTOR = 6,
}

export enum Position {
  PROJECT_MANAGER = 'project_manager',
  TEAM_CAPTAIN = 'team_captain',
  VICE_CAPTAIN = 'vice_captain',
}

export enum UserStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
  PROBATION = 'probation',
}

export enum ApprovalStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true, length: 50 })
  username: string;

  @Column({ name: 'password_hash' })
  passwordHash: string;

  @Column({ name: 'real_name', length: 50 })
  realName: string;

  @Column({ name: 'role_level', type: 'int' })
  roleLevel: RoleLevel;

  @Column({ name: 'position', type: 'varchar', length: 32, nullable: true })
  position: Position | null;

  @Column({ nullable: true, length: 500 })
  avatarUrl: string;

  @Column({ nullable: true, length: 20 })
  phone: string;

  @Column({ name: 'wechat_work_id', nullable: true, length: 100 })
  wechatWorkId: string;

  @Column({ name: 'group_ids', type: 'simple-array', nullable: true })
  groupIds: string[] | null;

  @Column({ name: 'division_ids', type: 'simple-array', nullable: true })
  divisionIds: string[] | null;

  @Column({ type: 'varchar', length: 20, default: UserStatus.ACTIVE })
  status: UserStatus;

  @Column({ type: 'varchar', nullable: true, unique: true })
  email: string | null;

  @Column({ name: 'session_token', type: 'varchar', nullable: true })
  sessionToken: string | null;

  @Column({ name: 'is_super_admin', default: false })
  isSuperAdmin: boolean;

  @Column({ name: 'approval_status', type: 'varchar', length: 20, default: ApprovalStatus.PENDING })
  approvalStatus: ApprovalStatus;

  @Column({ name: 'approval_reviewer_id', type: 'uuid', nullable: true })
  approvalReviewerId: string | null;

  @Column({ name: 'approval_reviewed_at', type: 'timestamp', nullable: true })
  approvalReviewedAt: Date | null;

  @Column({ name: 'approval_reject_reason', type: 'text', nullable: true })
  approvalRejectReason: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
