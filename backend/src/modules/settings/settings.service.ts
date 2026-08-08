import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';
import { AI_CONSENT_VERSION } from '../../common/constants/ai-consent';
import { AuditService } from '../audit/audit.service';
import { UpdateSettingsDto } from './dto/settings.dto';

@Injectable()
export class SettingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async get(userId: string) {
    return this.prisma.userSettings.upsert({
      where: { userId },
      create: { userId },
      update: {},
    });
  }

  async update(userId: string, dto: UpdateSettingsDto) {
    const { aiConsentConfirmed, ...requested } = dto;
    const data: Record<string, unknown> = { ...requested };
    let consentGranted = false;

    if (dto.aiEnabled === true) {
      const existing = await this.prisma.userSettings.findUnique({
        where: { userId },
        select: {
          aiEnabled: true,
          aiConsentAt: true,
          aiConsentVersion: true,
        },
      });
      const alreadyConsented =
        existing?.aiEnabled === true &&
        existing.aiConsentAt !== null &&
        existing.aiConsentVersion === AI_CONSENT_VERSION;

      if (!alreadyConsented && aiConsentConfirmed !== true) {
        throw new BadRequestException({
          code: 'AI_CONSENT_REQUIRED',
          message: 'Confirm the AI data-use disclosure before enabling AI features.',
        });
      }
      if (!alreadyConsented) {
        data.aiConsentAt = new Date();
        data.aiConsentVersion = AI_CONSENT_VERSION;
        consentGranted = true;
      }
    }

    const updated = await this.prisma.userSettings.upsert({
      where: { userId },
      create: { userId, ...data },
      update: data,
    });

    if (consentGranted || dto.aiEnabled === false) {
      await this.audit.log({
        userId,
        action: consentGranted ? 'AI_CONSENT_GRANTED' : 'AI_DISABLED',
        entity: 'UserSettings',
        entityId: updated.id,
        metadata: consentGranted
          ? { consentVersion: AI_CONSENT_VERSION }
          : { disabledAt: new Date().toISOString() },
      });
    }

    return updated;
  }

  async exportData(userId: string) {
    const [user, categories, incomes, expenses, budgets] = await Promise.all([
      this.prisma.user.findUnique({
        where: { id: userId },
        select: { email: true, firstName: true, lastName: true, createdAt: true, settings: true },
      }),
      this.prisma.category.findMany({ where: { userId, deletedAt: null } }),
      this.prisma.income.findMany({ where: { userId, deletedAt: null } }),
      this.prisma.expense.findMany({ where: { userId, deletedAt: null } }),
      this.prisma.monthlyBudget.findMany({ where: { userId, deletedAt: null } }),
    ]);
    return { user, categories, incomes, expenses, budgets, exportedAt: new Date().toISOString() };
  }
}
