import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, ManyToOne, JoinColumn } from 'typeorm';

export enum RoleLevel {
  RESERVE_MEMBER = 1,
  OFFICIAL_MEMBER = 2,
  GROUP_LEADER = 3,
  PROJECT_MANAGER = 4,
  TEAM_CAPTAIN = 5,
  INSTRUCTOR = 6,
}

export enum UserStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
  PROBATION = 'probation',
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

  @Column({ name: 'is_super_admin', default: false })
  isSuperAdmin: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
