import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { CategoryType } from '@prisma/client';
import { PrismaService } from '../../common/prisma/prisma.service';
import {
  CreateCategoryDto,
  ReorderCategoriesDto,
  UpdateCategoryDto,
} from './dto/category.dto';

@Injectable()
export class CategoriesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string, type?: CategoryType, includeArchived = false) {
    return this.prisma.category.findMany({
      where: {
        userId,
        deletedAt: null,
        ...(type ? { type } : {}),
        ...(includeArchived ? {} : { isArchived: false }),
      },
      orderBy: [{ type: 'asc' }, { sortOrder: 'asc' }, { name: 'asc' }],
    });
  }

  async create(userId: string, dto: CreateCategoryDto) {
    const existing = await this.prisma.category.findFirst({
      where: { userId, name: dto.name, type: dto.type, deletedAt: null },
    });
    if (existing) throw new BadRequestException('Category already exists');

    const count = await this.prisma.category.count({ where: { userId, type: dto.type } });
    return this.prisma.category.create({
      data: {
        userId,
        name: dto.name,
        type: dto.type,
        icon: dto.icon,
        color: dto.color,
        sortOrder: count,
      },
    });
  }

  async update(userId: string, id: string, dto: UpdateCategoryDto) {
    await this.getOwned(userId, id);
    return this.prisma.category.update({ where: { id }, data: dto });
  }

  async archive(userId: string, id: string, archived: boolean) {
    await this.getOwned(userId, id);
    return this.prisma.category.update({ where: { id }, data: { isArchived: archived } });
  }

  /**
   * What deleting this category would destroy. The client shows these exact
   * numbers in the confirmation dialog, so a user is never surprised by how
   * much history disappears with a single tap.
   */
  async impact(userId: string, id: string) {
    const category = await this.getOwned(userId, id);

    const [expenses, incomes, budgets, recurring, expenseSum, incomeSum] = await Promise.all([
      this.prisma.expense.count({ where: { userId, categoryId: id, deletedAt: null } }),
      this.prisma.income.count({ where: { userId, categoryId: id, deletedAt: null } }),
      this.prisma.monthlyBudget.count({ where: { userId, categoryId: id } }),
      this.prisma.recurringTransaction.count({
        where: { userId, categoryId: id, deletedAt: null },
      }),
      this.prisma.expense.aggregate({
        where: { userId, categoryId: id, deletedAt: null },
        _sum: { amount: true },
      }),
      this.prisma.income.aggregate({
        where: { userId, categoryId: id, deletedAt: null },
        _sum: { amount: true },
      }),
    ]);

    return {
      category: {
        id: category.id,
        name: category.name,
        type: category.type,
        isDefault: category.isDefault,
      },
      expenses,
      incomes,
      budgets,
      recurring,
      totalRecords: expenses + incomes + budgets + recurring,
      expenseAmount: Number(expenseSum._sum.amount ?? 0),
      incomeAmount: Number(incomeSum._sum.amount ?? 0),
    };
  }

  /**
   * Permanently deletes a category AND every record filed under it.
   *
   * Default categories are deletable too: they are only a starting point, and
   * a user who never uses "Transport" should be able to remove it. The cascade
   * is explicit rather than relying on database FKs, because
   * RecurringTransaction references categoryId without a Prisma relation and
   * would otherwise be left orphaned.
   *
   * This is irreversible — callers must confirm against `impact()` first.
   */
  async remove(userId: string, id: string) {
    await this.getOwned(userId, id);
    const before = await this.impact(userId, id);

    await this.prisma.$transaction([
      this.prisma.expense.deleteMany({ where: { userId, categoryId: id } }),
      this.prisma.income.deleteMany({ where: { userId, categoryId: id } }),
      this.prisma.monthlyBudget.deleteMany({ where: { userId, categoryId: id } }),
      this.prisma.recurringTransaction.deleteMany({ where: { userId, categoryId: id } }),
      this.prisma.category.delete({ where: { id } }),
    ]);

    return {
      message: 'Category and all of its records were deleted',
      deleted: {
        category: before.category.name,
        expenses: before.expenses,
        incomes: before.incomes,
        budgets: before.budgets,
        recurring: before.recurring,
      },
    };
  }

  async reorder(userId: string, dto: ReorderCategoriesDto) {
    await this.prisma.$transaction(
      dto.items.map((item) =>
        this.prisma.category.updateMany({
          where: { id: item.id, userId },
          data: { sortOrder: item.sortOrder },
        }),
      ),
    );
    return { message: 'Reordered' };
  }

  private async getOwned(userId: string, id: string) {
    const category = await this.prisma.category.findFirst({
      where: { id, userId, deletedAt: null },
    });
    if (!category) throw new NotFoundException('Category not found');
    return category;
  }
}
