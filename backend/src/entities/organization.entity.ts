import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

@Entity('groups')
export class Group {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 100 })
  name: string;

  @Column({ name: 'leader_ids', type: 'simple-array', nullable: true })
  leaderIds: string[] | null;

  @Column({ name: 'division_id', nullable: true })
  divisionId: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}

@Entity('divisions')
export class Division {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 100 })
  name: string;

  @Column({ name: 'leader_ids', type: 'simple-array', nullable: true })
  leaderIds: string[] | null;

  @Column({ type: 'text', nullable: true })
  description: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
