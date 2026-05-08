import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Not, Repository } from 'typeorm';
import {
  User,
  Task,
  Meeting,
  Group,
  Division,
  Objective,
  ApprovalStatus,
  TaskStatus,
  ObjectiveStatus,
  MeetingStatus,
  RoleLevel,
} from '../../entities';

@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Task)
    private readonly taskRepo: Repository<Task>,
    @InjectRepository(Meeting)
    private readonly meetingRepo: Repository<Meeting>,
    @InjectRepository(Group)
    private readonly groupRepo: Repository<Group>,
    @InjectRepository(Division)
    private readonly divisionRepo: Repository<Division>,
    @InjectRepository(Objective)
    private readonly objectiveRepo: Repository<Objective>,
  ) {}

  async getDashboardStats() {
    const [
      totalUsers,
      pendingApprovals,
      approvedUsers,
      totalTasks,
      activeTasks,
      pendingReviewTasks,
      overdueTasks,
      totalMeetings,
      scheduledMeetings,
      totalGroups,
      totalDivisions,
      activeObjectives,
      completedObjectives,
      usersByRole,
    ] = await Promise.all([
      this.userRepo.count(),
      this.userRepo.count({ where: { approvalStatus: ApprovalStatus.PENDING } }),
      this.userRepo.count({ where: { approvalStatus: ApprovalStatus.APPROVED } }),
      this.taskRepo.count(),
      this.taskRepo.count({ where: { status: TaskStatus.APPROVED } }),
      this.taskRepo.count({ where: { status: TaskStatus.PENDING_REVIEW } }),
      this.taskRepo.count({ where: { status: TaskStatus.OVERDUE } }),
      this.meetingRepo.count(),
      this.meetingRepo.count({ where: { status: MeetingStatus.SCHEDULED } }),
      this.groupRepo.count(),
      this.divisionRepo.count(),
      this.objectiveRepo.count({ where: { status: ObjectiveStatus.ACTIVE } }),
      this.objectiveRepo.count({ where: { status: ObjectiveStatus.COMPLETED } }),
      this.countByRole(),
    ]);

    return {
      users: {
        total: totalUsers,
        pending: pendingApprovals,
        approved: approvedUsers,
        byRole: usersByRole,
      },
      tasks: {
        total: totalTasks,
        active: activeTasks,
        pendingReview: pendingReviewTasks,
        overdue: overdueTasks,
      },
      meetings: {
        total: totalMeetings,
        scheduled: scheduledMeetings,
      },
      organization: {
        groups: totalGroups,
        divisions: totalDivisions,
      },
      objectives: {
        active: activeObjectives,
        completed: completedObjectives,
      },
    };
  }

  private async countByRole() {
    const counts: Record<string, number> = {};
    const levels = [
      RoleLevel.RESERVE_MEMBER,
      RoleLevel.OFFICIAL_MEMBER,
      RoleLevel.GROUP_LEADER,
      RoleLevel.VICE_CAPTAIN,
      RoleLevel.PROJECT_MANAGER,
      RoleLevel.INSTRUCTOR,
    ];
    for (const lvl of levels) {
      counts[String(lvl)] = await this.userRepo.count({ where: { roleLevel: lvl } });
    }
    const fives = await this.userRepo.find({ where: { roleLevel: RoleLevel.PROJECT_MANAGER }, select: ['position'] });
    counts['5:project_manager'] = fives.filter(u => u.position === 'project_manager').length;
    counts['5:team_captain'] = fives.filter(u => u.position === 'team_captain').length;
    counts['5:unspecified'] = fives.filter(u => !u.position).length;
    return counts;
  }
}
