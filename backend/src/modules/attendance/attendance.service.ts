import {
  Injectable,
  ForbiddenException,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan, MoreThanOrEqual, LessThanOrEqual, Between, In } from 'typeorm';
import { Cron, CronExpression } from '@nestjs/schedule';
import {
  AttendanceFence,
  AttendanceSession,
  AttendanceSessionStatus,
  User,
  Group,
  Division,
} from '../../entities';

interface ClockDto {
  lat: number;
  lng: number;
  accuracy?: number;
  address?: string;
}

interface FenceDto {
  name: string;
  centerLat: number;
  centerLng: number;
  radius: number;
  enabled?: boolean;
}

const MAX_SESSION_HOURS = 20;

@Injectable()
export class AttendanceService {
  constructor(
    @InjectRepository(AttendanceFence)
    private readonly fenceRepo: Repository<AttendanceFence>,
    @InjectRepository(AttendanceSession)
    private readonly sessionRepo: Repository<AttendanceSession>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Group)
    private readonly groupRepo: Repository<Group>,
    @InjectRepository(Division)
    private readonly divisionRepo: Repository<Division>,
  ) {}

  // ------- 距离 -------
  private haversine(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const R = 6371000;
    const toRad = (v: number) => (v * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
    return 2 * R * Math.asin(Math.sqrt(a));
  }

  // ------- session -------
  async findActiveSession(userId: string) {
    return this.sessionRepo.findOne({
      where: { userId, status: AttendanceSessionStatus.ACTIVE },
    });
  }

  async clockIn(userId: string, dto: ClockDto) {
    if (typeof dto.lat !== 'number' || typeof dto.lng !== 'number') {
      throw new BadRequestException('缺少经纬度');
    }
    const existing = await this.findActiveSession(userId);
    if (existing) throw new ConflictException('你已上工，请先下工');

    const fences = await this.fenceRepo.find({ where: { enabled: true } });
    if (!fences.length) throw new ForbiddenException('尚未配置打卡地点，请联系管理员');

    const hit = fences.find(
      (f) => this.haversine(dto.lat, dto.lng, f.centerLat, f.centerLng) <= f.radius,
    );
    if (!hit) throw new ForbiddenException('不在打卡范围内');

    const session = this.sessionRepo.create({
      userId,
      clockInAt: new Date(),
      clockInLat: dto.lat,
      clockInLng: dto.lng,
      clockInAddress: dto.address || null,
      clockInFenceId: hit.id,
      status: AttendanceSessionStatus.ACTIVE,
      durationMinutes: 0,
    });
    return this.sessionRepo.save(session);
  }

  async clockOut(userId: string, dto: ClockDto) {
    if (typeof dto.lat !== 'number' || typeof dto.lng !== 'number') {
      throw new BadRequestException('缺少经纬度');
    }
    const session = await this.findActiveSession(userId);
    if (!session) throw new BadRequestException('没有进行中的上工记录');

    const now = new Date();
    const durationMs = now.getTime() - new Date(session.clockInAt).getTime();
    const durationMinutes = Math.max(0, Math.floor(durationMs / 60000));

    session.clockOutAt = now;
    session.clockOutLat = dto.lat;
    session.clockOutLng = dto.lng;
    session.clockOutAddress = dto.address || null;
    session.status = AttendanceSessionStatus.CLOSED;
    session.durationMinutes = durationMinutes;
    return this.sessionRepo.save(session);
  }

  async getMySessions(userId: string, params: { from?: string; to?: string; limit?: number }) {
    const where: any = { userId };
    if (params.from && params.to) {
      where.clockInAt = Between(new Date(params.from), new Date(params.to));
    } else if (params.from) {
      where.clockInAt = MoreThanOrEqual(new Date(params.from));
    } else if (params.to) {
      where.clockInAt = LessThanOrEqual(new Date(params.to));
    }
    return this.sessionRepo.find({
      where,
      order: { clockInAt: 'DESC' },
      take: params.limit && params.limit > 0 ? Math.min(params.limit, 200) : 50,
    });
  }

  async getUserSessions(userId: string, params: { from?: string; to?: string; limit?: number }) {
    return this.getMySessions(userId, params);
  }

  async getStats(params: { scope?: 'week' | 'month' | 'all'; groupId?: string; divisionId?: string }) {
    const scope = params.scope || 'week';
    const now = new Date();
    let from: Date | null = null;
    if (scope === 'week') {
      // 本周一 00:00 本地时区
      const d = new Date(now);
      const day = (d.getDay() + 6) % 7; // 周一=0
      d.setDate(d.getDate() - day);
      d.setHours(0, 0, 0, 0);
      from = d;
    } else if (scope === 'month') {
      from = new Date(now.getFullYear(), now.getMonth(), 1);
    }

    // 拉已关闭 session（CLOSED 才计工时）
    const where: any = { status: AttendanceSessionStatus.CLOSED };
    if (from) {
      where.clockInAt = MoreThanOrEqual(from);
    }
    const sessions = await this.sessionRepo.find({ where });

    // 限定用户集合
    let userFilter: Set<string> | null = null;
    if (params.groupId) {
      const users = await this.userRepo.find();
      userFilter = new Set(
        users.filter((u) => (u.groupIds || []).includes(params.groupId!)).map((u) => u.id),
      );
    } else if (params.divisionId) {
      const users = await this.userRepo.find();
      userFilter = new Set(
        users.filter((u) => (u.divisionIds || []).includes(params.divisionId!)).map((u) => u.id),
      );
    }

    const totals = new Map<string, { totalMinutes: number; sessionCount: number }>();
    for (const s of sessions) {
      if (userFilter && !userFilter.has(s.userId)) continue;
      const cur = totals.get(s.userId) || { totalMinutes: 0, sessionCount: 0 };
      cur.totalMinutes += s.durationMinutes || 0;
      cur.sessionCount += 1;
      totals.set(s.userId, cur);
    }

    const userIds = Array.from(totals.keys());
    if (!userIds.length) return [];
    const users = await this.userRepo.find({ where: { id: In(userIds) } });
    const userById = new Map(users.map((u) => [u.id, u]));

    const rows = userIds.map((uid) => {
      const u = userById.get(uid);
      const t = totals.get(uid)!;
      return {
        userId: uid,
        realName: u?.realName || '未知',
        username: u?.username || '',
        totalMinutes: t.totalMinutes,
        sessionCount: t.sessionCount,
      };
    });
    rows.sort((a, b) => b.totalMinutes - a.totalMinutes);
    return rows;
  }

  // ------- fence crud -------
  private async assertSuperAdmin(userId: string) {
    const u = await this.userRepo.findOne({ where: { id: userId } });
    if (!u || !u.isSuperAdmin) throw new ForbiddenException('仅超级管理员可操作');
    return u;
  }

  async listFences() {
    return this.fenceRepo.find({ order: { createdAt: 'DESC' } });
  }

  async createFence(userId: string, dto: FenceDto) {
    await this.assertSuperAdmin(userId);
    if (!dto.name || typeof dto.centerLat !== 'number' || typeof dto.centerLng !== 'number' || !dto.radius) {
      throw new BadRequestException('围栏参数不完整');
    }
    if (dto.radius < 10 || dto.radius > 5000) {
      throw new BadRequestException('半径应在 10m 到 5000m 之间');
    }
    const fence = this.fenceRepo.create({
      name: dto.name,
      centerLat: dto.centerLat,
      centerLng: dto.centerLng,
      radius: Math.round(dto.radius),
      enabled: dto.enabled ?? true,
    });
    return this.fenceRepo.save(fence);
  }

  async updateFence(userId: string, id: string, dto: Partial<FenceDto>) {
    await this.assertSuperAdmin(userId);
    const fence = await this.fenceRepo.findOne({ where: { id } });
    if (!fence) throw new NotFoundException('围栏不存在');
    if (dto.name !== undefined) fence.name = dto.name;
    if (dto.centerLat !== undefined) fence.centerLat = dto.centerLat;
    if (dto.centerLng !== undefined) fence.centerLng = dto.centerLng;
    if (dto.radius !== undefined) {
      if (dto.radius < 10 || dto.radius > 5000) {
        throw new BadRequestException('半径应在 10m 到 5000m 之间');
      }
      fence.radius = Math.round(dto.radius);
    }
    if (dto.enabled !== undefined) fence.enabled = dto.enabled;
    return this.fenceRepo.save(fence);
  }

  async removeFence(userId: string, id: string) {
    await this.assertSuperAdmin(userId);
    const fence = await this.fenceRepo.findOne({ where: { id } });
    if (!fence) throw new NotFoundException('围栏不存在');
    await this.fenceRepo.remove(fence);
    return { ok: true };
  }

  // ------- cron -------
  @Cron(CronExpression.EVERY_HOUR)
  async autoCloseStaleSessions() {
    const threshold = new Date(Date.now() - MAX_SESSION_HOURS * 3600 * 1000);
    await this.sessionRepo.update(
      { status: AttendanceSessionStatus.ACTIVE, clockInAt: LessThan(threshold) as any },
      { status: AttendanceSessionStatus.AUTO_CLOSED, durationMinutes: 0 },
    );
  }
}
