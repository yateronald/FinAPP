import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { CategoryType } from '@prisma/client';
import { PrismaService } from '../../common/prisma/prisma.service';
import { BudgetEngineService } from './budget-engine.service';
import { UpsertBudgetDto } from './dto/budget.dto';

@Injectable()
export class BudgetsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly engine: BudgetEngineService,
  ) {}

  async upsert(userId: string, dto: UpsertBudgetDto) {
    const category = await this.prisma.category.findFirst({
      where: { id: dto.categoryId, userId, deletedAt: null },
    });
    if (!category) throw new NotFoundException('Category not found');
    if (category.type !== CategoryType.EXPENSE) {
      throw new BadRequestException('Budgets can only be set for expense categories');
    }

    return this.prisma.monthlyBudget.upsert({
      where: {
        userId_categoryId_month_year: {
          userId,
          categoryId: dto.categoryId,
          month: dto.month,
          year: dto.year,
        },
      },
      create: {
        userId,
        categoryId: dto.categoryId,
        amount: dto.amount,
        month: dto.month,
        year: dto.year,
        rollover: dto.rollover ?? false,
      },
      update: { amount: dto.amount, rollover: dto.rollover ?? false, deletedAt: null },
    });
  }

  async getStatuses(userId: string, month: number, year: number) {
    return this.engine.getStatuses(userId, month, year);
  }

  async remove(userId: string, id: string) {
    const budget = await this.prisma.monthlyBudget.findFirst({ where: { id, userId } });
    if (!budget) throw new NotFoundException('Budget not found');
    await this.prisma.monthlyBudget.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
    return { message: 'Budget removed' };
  }
}
