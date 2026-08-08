import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { NotificationType } from '@prisma/client';
import { PrismaService } from '../../common/prisma/prisma.service';
import { NotificationsService } from './notifications.service';
import {
  expenseReminder,
  incomeReminder,
  verificationReminder,
  welcomeMessage,
} from './engagement-copy';

/** Discriminates our notifications inside the generic SYSTEM type. */
export const ENGAGEMENT_KINDS = {
  welcome: 'welcome',
  expenseReminder: 'expense_reminder',
  incomeReminder: 'income_reminder',
  verification: 'verification_countdown',
} as const;

/**
 * Welcome and inactivity nudges.
 *
 * Deliberately conservative about how often it speaks: unsolicited
 * notifications are the fastest way to get an app uninstalled, so every send
 * passes a grace period, a frequency cap and a hard stop.
 */
@Injectable()
export class EngagementService {
  private readonly logger = new Logger(EngagementService.name);

  /** Nothing is sent during a user's first days — they have no history yet. */
  private readonly GRACE_DAYS = 3;

  /** Expenses are daily-ish; 48h avoids scolding someone for a quiet weekend. */
  private readonly EXPENSE_IDLE_HOURS = 48;

  /** Income is monthly for most people. */
  private readonly INCOME_IDLE_DAYS = 30;

  /** After this many unheeded reminders we go quiet until they record again. */
  private readonly MAX_CONSECUTIVE = 5;

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  private lang(settingsLanguage?: string | null): 'FR' | 'EN' {
    return settingsLanguage === 'EN' ? 'EN' : 'FR';
  }

  // ------------------------------------------------------------- Welcome
  async sendWelcome(userId: string, firstName: string | null) {
    const settings = await this.prisma.userSettings.findUnique({
      where: { userId },
      select: { language: true, notificationsEnabled: true },
    });
    if (settings?.notificationsEnabled === false) return;

    // Guard against a duplicate if lastLoginAt were ever cleared.
    const already = await this.prisma.notification.findFirst({
      where: {
        userId,
        type: NotificationType.SYSTEM,
        metadata: { path: ['kind'], equals: ENGAGEMENT_KINDS.welcome },
      },
      select: { id: true },
    });
    if (already) return;

    const copy = welcomeMessage(this.lang(settings?.language), firstName);
    await this.notifications.create({
      userId,
      type: NotificationType.SYSTEM,
      title: copy.title,
      message: copy.message,
      metadata: { kind: ENGAGEMENT_KINDS.welcome },
    });
  }

  // --------------------------------------------------------- Daily nudges
  /**
   * 19:00 UTC — roughly evening across West Africa and Europe. No timezone is
   * stored per user, so this is the same wall-clock moment for everyone.
   */
  @Cron('0 19 * * *')
  async handleInactivityReminders() {
    this.logger.log('Starting inactivity reminder cron…');
    const graceCutoff = new Date(Date.now() - this.GRACE_DAYS * 86_400_000);

    const users = await this.prisma.user.findMany({
      where: {
        isActive: true,
        deletedAt: null,
        role: 'USER',
        // Brand-new accounts are left alone.
        createdAt: { lt: graceCutoff },
        settings: { notificationsEnabled: true },
      },
      select: { id: true, createdAt: true, settings: { select: { language: true } } },
    });

    let expenseSent = 0;
    let incomeSent = 0;
    for (const user of users) {
      try {
        if (await this.maybeRemindExpense(user)) expenseSent++;
        if (await this.maybeRemindIncome(user)) incomeSent++;
      } catch (e) {
        this.logger.error(`Reminder failed for ${user.id}: ${(e as Error).message}`);
      }
    }
    this.logger.log(
      `Inactivity reminders done — ${expenseSent} expense, ${incomeSent} income, ${users.length} users scanned.`,
    );
  }

  /** Reminders of one kind sent since the user last recorded something. */
  private countRemindersSince(userId: string, kind: string, since: Date) {
    return this.prisma.notification.count({
      where: {
        userId,
        type: NotificationType.SYSTEM,
        createdAt: { gte: since },
        metadata: { path: ['kind'], equals: kind },
      },
    });
  }

  private async lastReminderAt(userId: string, kind: string): Promise<Date | null> {
    const last = await this.prisma.notification.findFirst({
      where: {
        userId,
        type: NotificationType.SYSTEM,
        metadata: { path: ['kind'], equals: kind },
      },
      orderBy: { createdAt: 'desc' },
      select: { createdAt: true },
    });
    return last?.createdAt ?? null;
  }

  private async maybeRemindExpense(user: {
    id: string;
    createdAt: Date;
    settings: { language: string } | null;
  }): Promise<boolean> {
    const idleSince = new Date(Date.now() - this.EXPENSE_IDLE_HOURS * 3_600_000);

    const recent = await this.prisma.expense.findFirst({
      where: { userId: user.id, deletedAt: null, createdAt: { gte: idleSince } },
      select: { id: true },
    });
    if (recent) return false; // They are active — nothing to nudge.

    // Anchor the count to their last real activity so the cap resets whenever
    // they come back, rather than being a lifetime limit.
    const lastExpense = await this.prisma.expense.findFirst({
      where: { userId: user.id, deletedAt: null },
      orderBy: { createdAt: 'desc' },
      select: { createdAt: true },
    });
    const anchor = lastExpense?.createdAt ?? user.createdAt;

    const sent = await this.countRemindersSince(user.id, ENGAGEMENT_KINDS.expenseReminder, anchor);
    if (sent >= this.MAX_CONSECUTIVE) return false;

    // Never twice in one day, even if the cron is retried or double-scheduled.
    const last = await this.lastReminderAt(user.id, ENGAGEMENT_KINDS.expenseReminder);
    if (last && Date.now() - last.getTime() < 20 * 3_600_000) return false;

    const copy = expenseReminder(this.lang(user.settings?.language), sent);
    await this.notifications.create({
      userId: user.id,
      type: NotificationType.SYSTEM,
      title: copy.title,
      message: copy.message,
      metadata: { kind: ENGAGEMENT_KINDS.expenseReminder },
    });
    return true;
  }

  private async maybeRemindIncome(user: {
    id: string;
    createdAt: Date;
    settings: { language: string } | null;
  }): Promise<boolean> {
    const idleSince = new Date(Date.now() - this.INCOME_IDLE_DAYS * 86_400_000);

    const recent = await this.prisma.income.findFirst({
      where: { userId: user.id, deletedAt: null, createdAt: { gte: idleSince } },
      select: { id: true },
    });
    if (recent) return false;

    const lastIncome = await this.prisma.income.findFirst({
      where: { userId: user.id, deletedAt: null },
      orderBy: { createdAt: 'desc' },
      select: { createdAt: true },
    });
    const anchor = lastIncome?.createdAt ?? user.createdAt;

    const sent = await this.countRemindersSince(user.id, ENGAGEMENT_KINDS.incomeReminder, anchor);
    if (sent >= this.MAX_CONSECUTIVE) return false;

    // Income is monthly — reminding more often than every 30 days is noise.
    const last = await this.lastReminderAt(user.id, ENGAGEMENT_KINDS.incomeReminder);
    if (last && Date.now() - last.getTime() < this.INCOME_IDLE_DAYS * 86_400_000) return false;

    const copy = incomeReminder(this.lang(user.settings?.language));
    await this.notifications.create({
      userId: user.id,
      type: NotificationType.SYSTEM,
      title: copy.title,
      message: copy.message,
      metadata: { kind: ENGAGEMENT_KINDS.incomeReminder },
    });
    return true;
  }

  /**
   * Once a day, remind accounts that predate mandatory verification how long
   * they have left. Runs an hour after the inactivity sweep so the two never
   * arrive together.
   */
  @Cron('0 20 * * *')
  async handleVerificationReminders() {
    const now = new Date();
    const dayAgo = new Date(now.getTime() - 23 * 60 * 60 * 1000);

    const pending = await this.prisma.user.findMany({
      where: {
        deletedAt: null,
        isActive: true,
        emailVerified: false,
        verificationDeadline: { gt: now },
        // At most one a day, whatever else happens.
        OR: [
          { verificationRemindedAt: null },
          { verificationRemindedAt: { lt: dayAgo } },
        ],
      },
      select: {
        id: true,
        firstName: true,
        verificationDeadline: true,
        settings: { select: { language: true, notificationsEnabled: true } },
      },
      take: 500,
    });

    let sent = 0;
    for (const user of pending) {
      if (user.settings?.notificationsEnabled === false) continue;
      const daysLeft = Math.max(
        1,
        Math.ceil((user.verificationDeadline!.getTime() - now.getTime()) / 86_400_000),
      );
      const copy = verificationReminder(
        this.lang(user.settings?.language),
        daysLeft,
        user.firstName,
      );
      try {
        await this.notifications.create({
          userId: user.id,
          type: NotificationType.SYSTEM,
          title: copy.title,
          message: copy.message,
          metadata: { kind: ENGAGEMENT_KINDS.verification, daysLeft },
        });
        await this.prisma.user.update({
          where: { id: user.id },
          data: { verificationRemindedAt: now },
        });
        sent++;
      } catch (err) {
        this.logger.error(
          `Verification reminder failed for ${user.id}`,
          (err as Error).message,
        );
      }
    }
    if (sent) this.logger.log(`Verification reminders sent: ${sent}`);
  }
}
