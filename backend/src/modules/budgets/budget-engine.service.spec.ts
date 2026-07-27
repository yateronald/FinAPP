import { Test } from '@nestjs/testing';
import { PrismaService } from '../../common/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { BudgetEngineService } from './budget-engine.service';

describe('BudgetEngineService', () => {
  let engine: BudgetEngineService;
  const prismaMock = {
    expense: { aggregate: jest.fn() },
    monthlyBudget: { findMany: jest.fn() },
  };
  const notificationsMock = { create: jest.fn() };

  beforeEach(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        BudgetEngineService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: NotificationsService, useValue: notificationsMock },
      ],
    }).compile();
    engine = moduleRef.get(BudgetEngineService);
    jest.clearAllMocks();
  });

  it('computes spent amount for a category', async () => {
    prismaMock.expense.aggregate.mockResolvedValue({ _sum: { amount: 1500 } });
    const spent = await engine.spentForCategory('u1', 'c1', 7, 2026);
    expect(spent).toBe(1500);
  });

  it('classifies budget statuses via getStatuses', async () => {
    prismaMock.monthlyBudget.findMany.mockResolvedValue([
      {
        categoryId: 'c1',
        amount: 3000,
        category: { name: 'Transport', icon: 'car', color: '#f59e0b' },
      },
    ]);
    prismaMock.expense.aggregate.mockResolvedValue({ _sum: { amount: 3200 } });

    const statuses = await engine.getStatuses('u1', 7, 2026);
    expect(statuses).toHaveLength(1);
    expect(statuses[0].status).toBe('exceeded');
    expect(statuses[0].progress).toBeCloseTo(106.7, 1);
    expect(statuses[0].remaining).toBe(-200);
  });
});
