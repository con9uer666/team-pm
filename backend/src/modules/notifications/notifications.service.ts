import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Notification, NotificationType } from '../../entities';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectRepository(Notification)
    private readonly repo: Repository<Notification>,
  ) {}

  async create(userId: string, type: NotificationType, title: string, content?: string, relatedId?: string) {
    const notification = this.repo.create({
      userId,
      type,
      title,
      content: content || null,
      relatedId: relatedId || null,
    });
    return this.repo.save(notification);
  }

  async createBatch(userIds: string[], type: NotificationType, title: string, content?: string, relatedId?: string) {
    const notifications = userIds.map(userId => this.repo.create({
      userId,
      type,
      title,
      content: content || null,
      relatedId: relatedId || null,
    }));
    return this.repo.save(notifications);
  }

  findByUser(userId: string) {
    return this.repo.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: 50,
    });
  }

  countUnread(userId: string) {
    return this.repo.count({ where: { userId, isRead: false } });
  }

  async markRead(id: string, userId: string) {
    await this.repo.update({ id, userId }, { isRead: true });
  }

  async markAllRead(userId: string) {
    await this.repo.update({ userId, isRead: false }, { isRead: true });
  }
}
