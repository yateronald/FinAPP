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

  async remove(userId: string, id: string) {
    const category = await this.getOwned(userId, id);
    if (category.isDefault) {
      throw new BadRequestException('Default categories cannot be deleted, only archived');
    }
    const inUse = await this.prisma.expense.count({ where: { categoryId: id, deletedAt: null } });
    const incomeUse = await this.prisma.income.count({
      where: { categoryId: id, deletedAt: null },
    });
    if (inUse + incomeUse > 0) {
      // Soft delete to preserve historical transactions.
      return this.prisma.category.update({
        where: { id },
        data: { deletedAt: new Date(), isArchived: true },
      });
    }
    return this.prisma.category.update({ where: { id }, data: { deletedAt: new Date() } });
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
