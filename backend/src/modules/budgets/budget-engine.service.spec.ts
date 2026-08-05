import { Test } from '@nestjs/testing';
import { PrismaService } from '../../common/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { BudgetEngineService } from './budget-engine.service';

describe('BudgetEngineService', () => {
  let engine: BudgetEngineService;
  const prismaMock = {
    expense: { aggregate: jest.fn(), groupBy: jest.fn() },
    monthlyBudget: { findMany: jest.fn() },
    overallBudget: { findFirst: jest.fn() },
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
    prismaMock.expense.groupBy.mockResolvedValue([
      { categoryId: 'c1', _sum: { amount: 3200 } },
    ]);

    const statuses = await engine.getStatuses('u1', 7, 2026);
    expect(statuses).toHaveLength(1);
    expect(statuses[0].status).toBe('exceeded');
    expect(statuses[0].progress).toBeCloseTo(106.7, 1);
    expect(statuses[0].remaining).toBe(-200);
  });

  it('reads every expense of the month for the overall cap, not just budgeted ones', async () => {
    prismaMock.overallBudget.findFirst.mockResolvedValue({
      id: 'o1',
      amount: 10000,
      seriesId: null,
    });
    prismaMock.monthlyBudget.findMany.mockResolvedValue([{ categoryId: 'c1' }]);
    // 1st call: whole-month spend. 2nd: spend outside budgeted categories.
    prismaMock.expense.aggregate
      .mockResolvedValueOnce({ _sum: { amount: 9200 } })
      .mockResolvedValueOnce({ _sum: { amount: 4000 } });

    const overall = await engine.overallStatus('u1', 7, 2026);
    expect(overall).not.toBeNull();
    expect(overall!.spent).toBe(9200);
    expect(overall!.remaining).toBe(800);
    expect(overall!.progress).toBeCloseTo(92, 1);
    expect(overall!.status).toBe('danger');
    // Spending no category budget is watching.
    expect(overall!.uncategorisedSpend).toBe(4000);
  });

  it('returns no overall status when the month has no cap', async () => {
    prismaMock.overallBudget.findFirst.mockResolvedValue(null);
    expect(await engine.overallStatus('u1', 7, 2026)).toBeNull();
  });
});
