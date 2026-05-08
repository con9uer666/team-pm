import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { Notification, NotificationType, User } from '../../entities';
import { WechatService } from '../wechat/wechat.service';

type PushOptions = {
  pushWechat?: boolean;
  wechatUrl?: string;
  wechatContent?: string;
};

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    @InjectRepository(Notification)
    private readonly repo: Repository<Notification>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    private readonly wechatService: WechatService,
  ) {}

  async create(
    userId: string,
    type: NotificationType,
    title: string,
    content?: string,
    relatedId?: string,
    opts: PushOptions = { pushWechat: true },
  ) {
    const notification = this.repo.create({
      userId,
      type,
      title,
      content: content || null,
      relatedId: relatedId || null,
    });
    const saved = await this.repo.save(notification);

    if (opts.pushWechat !== false) {
      this.pushWechat([userId], title, opts.wechatContent || content || title, opts.wechatUrl).catch(e =>
        this.logger.error(`pushWechat error: ${e.message}`),
      );
    }

    return saved;
  }

  async createBatch(
    userIds: string[],
    type: NotificationType,
    title: string,
    content?: string,
    relatedId?: string,
    opts: PushOptions = { pushWechat: true },
  ) {
    if (!userIds.length) return [];
    const notifications = userIds.map(userId => this.repo.create({
      userId,
      type,
      title,
      content: content || null,
      relatedId: relatedId || null,
    }));
    const saved = await this.repo.save(notifications);

    if (opts.pushWechat !== false) {
      this.pushWechat(userIds, title, opts.wechatContent || content || title, opts.wechatUrl).catch(e =>
        this.logger.error(`pushWechat batch error: ${e.message}`),
      );
    }

    return saved;
  }

  private async pushWechat(userIds: string[], title: string, content: string, url?: string) {
    const users = await this.userRepo.find({ where: { id: In(userIds) } });
    const markdown = `## ${title}\n\n${content}`;
    await Promise.all(
      users
        .filter(u => !!u.wechatWorkId)
        .map(u => this.wechatService.sendMessage(u.wechatWorkId, title, markdown, url)),
    );
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
