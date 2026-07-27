import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { NotificationType } from '@prisma/client';
import { PrismaService } from '../../common/prisma/prisma.service';
import { AiService } from '../ai/ai.service';
import { NotificationsService } from './notifications.service';

@Injectable()
export class NotificationsCronService {
  private readonly logger = new Logger(NotificationsCronService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly ai: AiService,
    private readonly notifications: NotificationsService,
  ) {}

  /**
   * Run at 09:00 AM on the 1st day of every month:
   * Generates a concise AI monthly summary push notification for every active user.
   */
  @Cron('0 9 1 * *')
  async handleMonthlyAiSummaryCron() {
    this.logger.log('Starting Monthly AI Summary Notification Cron Job...');
    const users = await this.prisma.user.findMany({
      where: { isActive: true, deletedAt: null },
      select: { id: true },
    });

    const now = new Date();
    // Previous month calculation
    const prevMonthDate = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const m = prevMonthDate.getMonth() + 1;
    const y = prevMonthDate.getFullYear();

    for (const u of users) {
      try {
        const { summary } = await this.ai.monthlySummary(u.id, m, y);
        if (summary) {
          await this.notifications.create({
            userId: u.id,
            type: NotificationType.MONTHLY_SUMMARY,
            title: `Bilan Financier IA (${m}/${y})`,
            message: summary.length > 120 ? `${summary.substring(0, 117)}...` : summary,
            metadata: { month: m, year: y },
          });
        }
      } catch (err) {
        this.logger.error(`Failed monthly AI summary notification for user ${u.id}:`, (err as Error).message);
      }
    }
    this.logger.log('Completed Monthly AI Summary Notification Cron Job.');
  }

  /**
   * Run at 09:00 AM every Monday:
   * Generates a weekly AI financial tip for every active user.
   */
  @Cron('0 9 * * 1')
  async handleWeeklyAiTipCron() {
    this.logger.log('Starting Weekly AI Tip Notification Cron Job...');
    const users = await this.prisma.user.findMany({
      where: { isActive: true, deletedAt: null },
      select: { id: true },
    });

    for (const u of users) {
      try {
        const insightsObj = await this.ai.generateInsights(u.id, new Date().getMonth() + 1, new Date().getFullYear(), 'GLOBAL');
        const tip = insightsObj.insights?.[0];
        if (tip) {
          await this.notifications.create({
            userId: u.id,
            type: NotificationType.AI_ALERT,
            title: `Conseil IA Semaine: ${tip.title}`,
            message: tip.content,
            metadata: { type: tip.type },
          });
        }
      } catch (err) {
        this.logger.error(`Failed weekly AI tip notification for user ${u.id}:`, (err as Error).message);
      }
    }
    this.logger.log('Completed Weekly AI Tip Notification Cron Job.');
  }
}
