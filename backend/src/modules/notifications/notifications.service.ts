import { existsSync, readFileSync } from 'fs';
import { join } from 'path';
import { Injectable, Logger } from '@nestjs/common';
import { NotificationType, Prisma } from '@prisma/client';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging, MulticastMessage } from 'firebase-admin/messaging';
import { PrismaService } from '../../common/prisma/prisma.service';

/** Android notification channel id — MUST match the channel the mobile app
 *  creates and the `default_notification_channel_id` in its manifest. */
export const FCM_CHANNEL_ID = 'fynexa_alerts';

export interface CreateNotificationInput {
  userId: string;
  type: NotificationType;
  title: string;
  message: string;
  metadata?: Record<string, any>;
}

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private firebaseInitialized = false;

  constructor(private readonly prisma: PrismaService) {
    this.initFirebase();
  }

  private initFirebase() {
    try {
      if (getApps().length > 0) {
        this.firebaseInitialized = true;
        return;
      }

      // Credentials are REQUIRED to send FCM — a bare projectId cannot mint the
      // OAuth token, so sends would fail silently. We look, in order, for:
      //  1. FIREBASE_SERVICE_ACCOUNT env (raw JSON or base64),
      //  2. a JSON file: FIREBASE_SERVICE_ACCOUNT_PATH, GOOGLE_APPLICATION_CREDENTIALS,
      //     or a `serviceAccount.json` dropped in the backend folder.
      // None of these are committed to git.
      const inline = process.env.FIREBASE_SERVICE_ACCOUNT?.trim();

      // Resolve a service-account file path from env, or the default location.
      const candidatePaths = [
        process.env.FIREBASE_SERVICE_ACCOUNT_PATH?.trim(),
        process.env.GOOGLE_APPLICATION_CREDENTIALS?.trim(),
        join(process.cwd(), 'serviceAccount.json'),
      ].filter(Boolean) as string[];
      const filePath = candidatePaths.find((p) => existsSync(p));

      let serviceAccount: Record<string, any> | null = null;
      if (inline) {
        const json = inline.startsWith('{')
          ? inline
          : Buffer.from(inline, 'base64').toString('utf8');
        serviceAccount = JSON.parse(json);
      } else if (filePath) {
        serviceAccount = JSON.parse(readFileSync(filePath, 'utf8'));
        this.logger.log(`Loading Firebase service account from ${filePath}`);
      }

      if (serviceAccount) {
        initializeApp({
          credential: cert(serviceAccount),
          projectId: serviceAccount.project_id ?? process.env.FIREBASE_PROJECT_ID,
        });
        this.firebaseInitialized = true;
        this.logger.log(
          `Firebase Admin initialized for project "${serviceAccount.project_id}".`,
        );
      } else {
        this.logger.warn(
          'Push notifications DISABLED: drop your Firebase service-account JSON at ' +
            `${join(process.cwd(), 'serviceAccount.json')} (or set FIREBASE_SERVICE_ACCOUNT) to enable FCM.`,
        );
      }
    } catch (e) {
      this.logger.error('Firebase Admin initialization failed:', (e as Error).message);
    }
  }

  async registerFcmToken(userId: string, token: string, deviceType = 'android') {
    return this.prisma.fcmToken.upsert({
      where: { token },
      create: { userId, token, deviceType },
      update: { userId, deviceType, updatedAt: new Date() },
    });
  }

  /** Remove a device token (called when the user turns notifications off). */
  async unregisterFcmToken(userId: string, token: string) {
    await this.prisma.fcmToken.deleteMany({ where: { userId, token } });
    return { ok: true };
  }

  async create(input: CreateNotificationInput) {
    const notification = await this.prisma.notification.create({
      data: {
        userId: input.userId,
        type: input.type,
        title: input.title,
        message: input.message,
        metadata: (input.metadata as Prisma.InputJsonValue) ?? undefined,
      },
    });

    // Fire-and-forget FCM push send
    void this.sendPush(input.userId, input.title, input.message, {
      type: input.type,
      notificationId: notification.id,
      ...(input.metadata ? { metadata: JSON.stringify(input.metadata) } : {}),
    });

    return notification;
  }

  private async sendPush(
    userId: string,
    title: string,
    body: string,
    data: Record<string, string> = {},
  ) {
    if (!this.firebaseInitialized) return;

    try {
      const tokens = await this.prisma.fcmToken.findMany({
        where: { userId },
        select: { token: true },
      });

      if (!tokens.length) return;
      const targetTokens = tokens.map((t) => t.token);

      const message: MulticastMessage = {
        tokens: targetTokens,
        notification: {
          title,
          body,
        },
        android: {
          priority: 'high',
          notification: {
            icon: 'ic_stat_notification', // monochrome status-bar icon
            color: '#6366F1', // brand accent
            sound: 'default',
            channelId: FCM_CHANNEL_ID,
            defaultSound: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
        data,
      };

      const res = await getMessaging().sendEachForMulticast(message);
      this.logger.log(`FCM push sent: ${res.successCount} succeeded, ${res.failureCount} failed.`);

      // Clean up invalid / unregistered tokens
      if (res.failureCount > 0) {
        const failedTokens: string[] = [];
        res.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const errCode = resp.error?.code;
            if (
              errCode === 'messaging/invalid-registration-token' ||
              errCode === 'messaging/registration-token-not-registered'
            ) {
              failedTokens.push(targetTokens[idx]);
            }
          }
        });
        if (failedTokens.length > 0) {
          await this.prisma.fcmToken.deleteMany({
            where: { token: { in: failedTokens } },
          });
        }
      }
    } catch (e) {
      this.logger.error('Failed to send FCM push notification:', (e as Error).message);
    }
  }

  /** Send a test push to the caller's own devices (safe: self-only). */
  async sendTestPush(userId: string) {
    const tokens = await this.prisma.fcmToken.count({ where: { userId } });
    if (!this.firebaseInitialized) {
      return { ok: false, reason: 'Firebase not configured on the server', devices: tokens };
    }
    if (tokens === 0) {
      return { ok: false, reason: 'No registered devices for this user', devices: 0 };
    }
    await this.create({
      userId,
      type: 'SYSTEM' as NotificationType,
      title: '🔔 Fynexa',
      message: 'Test notification — push is working!',
      metadata: { test: true },
    });
    return { ok: true, devices: tokens };
  }

  async list(userId: string, unreadOnly = false, take = 50) {
    return this.prisma.notification.findMany({
      where: { userId, ...(unreadOnly ? { isRead: false } : {}) },
      orderBy: { createdAt: 'desc' },
      take,
    });
  }

  async unreadCount(userId: string) {
    const count = await this.prisma.notification.count({ where: { userId, isRead: false } });
    return { count };
  }

  async markRead(userId: string, id: string) {
    await this.prisma.notification.updateMany({
      where: { id, userId },
      data: { isRead: true },
    });
    return { message: 'Marked read' };
  }

  async markAllRead(userId: string) {
    await this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true },
    });
    return { message: 'All marked read' };
  }

  async remove(userId: string, id: string) {
    await this.prisma.notification.deleteMany({ where: { id, userId } });
    return { message: 'Deleted' };
  }
}
