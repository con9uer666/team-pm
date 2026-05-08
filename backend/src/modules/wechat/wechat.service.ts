import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

interface WxPusherSendResult {
  code: number;
  msg?: string;
  data?: any;
}

interface WxPusherQrcodeResult {
  code: number;
  msg?: string;
  data?: {
    code?: string;
    shortUrl?: string;
    url?: string;
  };
}

@Injectable()
export class WechatService {
  private readonly logger = new Logger(WechatService.name);
  private readonly endpoint = 'https://wxpusher.zjiecode.com';

  constructor(private readonly config: ConfigService) {}

  private get appToken(): string | undefined {
    return this.config.get<string>('WXPUSHER_APP_TOKEN');
  }

  private get publicUrl(): string {
    return this.config.get<string>('APP_PUBLIC_URL') || 'http://localhost:8080';
  }

  async sendMessage(uid: string, title: string, content: string, url?: string): Promise<void> {
    if (!this.appToken || !uid) return;

    const body = {
      appToken: this.appToken,
      content,
      summary: title.slice(0, 20),
      contentType: 3,
      uids: [uid],
      url: url || undefined,
      verifyPay: false,
    };

    try {
      const res = await fetch(`${this.endpoint}/api/send/message`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      const data = (await res.json()) as WxPusherSendResult;
      if (data.code !== 1000) {
        this.logger.warn(`WxPusher send failed: ${data.code} ${data.msg}`);
      }
    } catch (e: any) {
      this.logger.error(`WxPusher send error: ${e.message}`);
    }
  }

  async createBindQrcode(userId: string): Promise<string | null> {
    if (!this.appToken) return null;

    const body = {
      appToken: this.appToken,
      extra: userId,
      validTime: 1800,
    };

    try {
      const res = await fetch(`${this.endpoint}/api/fun/create/qrcode`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      const data = (await res.json()) as WxPusherQrcodeResult;
      if (data.code !== 1000) {
        this.logger.warn(`WxPusher qrcode failed: ${data.code} ${data.msg}`);
        return null;
      }
      return data.data?.url || data.data?.shortUrl || null;
    } catch (e: any) {
      this.logger.error(`WxPusher qrcode error: ${e.message}`);
      return null;
    }
  }

  buildTaskUrl(taskId: string): string {
    return `${this.publicUrl}/tasks?id=${taskId}`;
  }

  buildMeetingUrl(meetingId: string): string {
    return `${this.publicUrl}/meetings?id=${meetingId}`;
  }
}
