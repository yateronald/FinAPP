import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';
import { UpdateSettingsDto } from './dto/settings.dto';

@Injectable()
export class SettingsService {
  constructor(private readonly prisma: PrismaService) {}

  async get(userId: string) {
    return this.prisma.userSettings.upsert({
      where: { userId },
      create: { userId },
      update: {},
    });
  }

  async update(userId: string, dto: UpdateSettingsDto) {
    return this.prisma.userSettings.upsert({
      where: { userId },
      create: { userId, ...dto },
      update: { ...dto },
    });
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
