import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  Meeting, MeetingScope, MeetingStatus, AttendanceStatus,
  MeetingParticipant, MeetingMinutes, User,
} from '../../entities';

@Injectable()
export class MeetingsService {
  constructor(
    @InjectRepository(Meeting)
    private readonly meetingRepo: Repository<Meeting>,
    @InjectRepository(MeetingParticipant)
    private readonly participantRepo: Repository<MeetingParticipant>,
    @InjectRepository(MeetingMinutes)
    private readonly minutesRepo: Repository<MeetingMinutes>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
  ) {}

  async create(organizerId: string, dto: {
    title: string;
    description?: string;
    scope: MeetingScope;
    groupId?: string;
    divisionId?: string;
    location?: string;
    startTime: string;
    endTime: string;
  }) {
    const meeting = this.meetingRepo.create({
      organizerId,
      title: dto.title,
      description: dto.description || null,
      scope: dto.scope,
      groupId: dto.groupId || null,
      divisionId: dto.divisionId || null,
      location: dto.location || null,
      startTime: new Date(dto.startTime),
      endTime: new Date(dto.endTime),
      status: MeetingStatus.SCHEDULED,
    });
    const saved = await this.meetingRepo.save(meeting);

    const participants = await this.getParticipantsByScope(dto.scope, dto.groupId, dto.divisionId);
    const records = participants.map(userId => this.participantRepo.create({
      meetingId: saved.id,
      userId,
      attendanceStatus: AttendanceStatus.PENDING,
    }));
    await this.participantRepo.save(records);

    return saved;
  }

  findAll() {
    return this.meetingRepo.find({ order: { startTime: 'DESC' } });
  }

  findByUser(userId: string) {
    return this.participantRepo.find({ where: { userId } })
      .then(async (parts) => {
        if (!parts.length) return [];
        const ids = parts.map(p => p.meetingId);
        return this.meetingRepo.createQueryBuilder('m')
          .where('m.id IN (:...ids)', { ids })
          .orderBy('m.start_time', 'DESC')
          .getMany();
      });
  }

  async findById(id: string) {
    const meeting = await this.meetingRepo.findOne({ where: { id } });
    if (!meeting) throw new NotFoundException('会议不存在');
    return meeting;
  }

  async startMeeting(id: string, organizerId: string) {
    const meeting = await this.findById(id);
    if (meeting.organizerId !== organizerId) throw new ForbiddenException('只有组织者可以开启会议');
    meeting.status = MeetingStatus.IN_PROGRESS;
    return this.meetingRepo.save(meeting);
  }

  async endMeeting(id: string, organizerId: string) {
    const meeting = await this.findById(id);
    if (meeting.organizerId !== organizerId) throw new ForbiddenException('只有组织者可以结束会议');
    meeting.status = MeetingStatus.ENDED;

    const now = new Date();
    await this.participantRepo
      .createQueryBuilder()
      .update(MeetingParticipant)
      .set({ attendanceStatus: AttendanceStatus.ABSENT })
      .where('meeting_id = :id', { id })
      .andWhere('attendance_status = :status', { status: AttendanceStatus.PENDING })
      .execute();

    return this.meetingRepo.save(meeting);
  }

  async cancelMeeting(id: string, organizerId: string) {
    const meeting = await this.findById(id);
    if (meeting.organizerId !== organizerId) throw new ForbiddenException('只有组织者可以取消会议');
    meeting.status = MeetingStatus.CANCELLED;
    return this.meetingRepo.save(meeting);
  }

  async checkIn(meetingId: string, userId: string) {
    const meeting = await this.findById(meetingId);
    if (meeting.status !== MeetingStatus.IN_PROGRESS) {
      throw new ForbiddenException('会议未开始，无法签到');
    }

    const participant = await this.participantRepo.findOne({
      where: { meetingId, userId },
    });
    if (!participant) throw new ForbiddenException('你不是该会议的参与者');
    if (participant.attendanceStatus !== AttendanceStatus.PENDING) {
      throw new ForbiddenException('已签到');
    }

    const now = new Date();
    participant.checkInTime = now;
    participant.attendanceStatus = now > meeting.startTime
      ? AttendanceStatus.LATE
      : AttendanceStatus.PRESENT;

    return this.participantRepo.save(participant);
  }

  getParticipants(meetingId: string) {
    return this.participantRepo.find({ where: { meetingId } });
  }

  async saveMinutes(meetingId: string, recorderId: string, content: string) {
    const existing = await this.minutesRepo.findOne({ where: { meetingId } });
    if (existing) {
      existing.content = content;
      existing.updatedAt = new Date();
      return this.minutesRepo.save(existing);
    }
    const minutes = this.minutesRepo.create({ meetingId, recorderId, content });
    return this.minutesRepo.save(minutes);
  }

  getMinutes(meetingId: string) {
    return this.minutesRepo.findOne({ where: { meetingId } });
  }

  private async getParticipantsByScope(scope: MeetingScope, groupId?: string, divisionId?: string): Promise<string[]> {
    let users: User[];
    if (scope === MeetingScope.GROUP && groupId) {
      users = await this.userRepo
        .createQueryBuilder('u')
        .where('u.group_ids LIKE :gid', { gid: `%${groupId}%` })
        .getMany();
    } else if (scope === MeetingScope.DIVISION && divisionId) {
      users = await this.userRepo
        .createQueryBuilder('u')
        .where('u.division_ids LIKE :div', { div: `%${divisionId}%` })
        .getMany();
    } else {
      users = await this.userRepo.find();
    }
    return users.map(u => u.id);
  }
}