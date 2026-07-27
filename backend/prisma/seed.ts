import { CategoryType, PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';
import {
  DEFAULT_EXPENSE_CATEGORIES,
  DEFAULT_INCOME_CATEGORIES,
} from '../src/common/constants/default-categories';

const prisma = new PrismaClient();

async function main() {
  const email = 'demo@finapp.local';
  const password = 'Password123!';
  const passwordHash = await argon2.hash(password, { type: argon2.argon2id });

  // Clean up any previous demo user.
  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    await prisma.user.delete({ where: { id: existing.id } });
  }

  const allDefaults = [...DEFAULT_INCOME_CATEGORIES, ...DEFAULT_EXPENSE_CATEGORIES];

  const user = await prisma.user.create({
    data: {
      email,
      passwordHash,
      firstName: 'Yate',
      lastName: 'Ronald',
      emailVerified: true,
      settings: { create: { currency: 'XOF', language: 'FR' } },
      categories: {
        create: allDefaults.map((c, i) => ({
          name: c.name,
          type: c.type,
          icon: c.icon,
          color: c.color,
          isDefault: true,
          sortOrder: i,
        })),
      },
    },
    include: { categories: true },
  });

  const byName = (name: string, type: CategoryType) =>
    user.categories.find((c) => c.name === name && c.type === type)!;

  const now = new Date();
  const y = now.getUTCFullYear();
  const m = now.getUTCMonth();

  // Seed income for current month.
  await prisma.income.createMany({
    data: [
      {
        userId: user.id,
        categoryId: byName('Salary', CategoryType.INCOME).id,
        title: 'Monthly salary',
        amount: 1000000,
        date: new Date(Date.UTC(y, m, 1)),
        isRecurring: true,
      },
      {
        userId: user.id,
        categoryId: byName('Freelance', CategoryType.INCOME).id,
        title: 'Website project',
        amount: 850000,
        date: new Date(Date.UTC(y, m, 8)),
      },
      {
        userId: user.id,
        categoryId: byName('Bonus', CategoryType.INCOME).id,
        title: 'Performance bonus',
        amount: 300000,
        date: new Date(Date.UTC(y, m, 15)),
      },
    ],
  });

  // Seed expenses for current month.
  const expenseSeed: [string, string, number, number][] = [
    ['Housing', 'Rent - Apartment', 185000, 2],
    ['Food', 'Groceries at market', 75000, 5],
    ['Transport', 'Taxi rides', 31000, 6],
    ['Entertainment', 'Cinema & outings', 27000, 9],
    ['Utilities', 'Electricity bill', 22000, 10],
    ['Internet', 'Fiber subscription', 20000, 11],
    ['Healthcare', 'Pharmacy', 16500, 12],
    ['Shopping', 'Clothes', 45000, 14],
  ];

  await prisma.expense.createMany({
    data: expenseSeed.map(([cat, title, amount, day]) => ({
      userId: user.id,
      categoryId: byName(cat, CategoryType.EXPENSE).id,
      title,
      amount,
      date: new Date(Date.UTC(y, m, day)),
      paymentMethod: 'card',
    })),
  });

  // Seed budgets for current month.
  const budgetSeed: [string, number][] = [
    ['Housing', 600000],
    ['Food', 450000],
    ['Transport', 30000],
    ['Entertainment', 30000],
    ['Healthcare', 250000],
    ['Shopping', 40000],
  ];

  for (const [cat, amount] of budgetSeed) {
    await prisma.monthlyBudget.create({
      data: {
        userId: user.id,
        categoryId: byName(cat, CategoryType.EXPENSE).id,
        amount,
        month: m + 1,
        year: y,
      },
    });
  }

  // eslint-disable-next-line no-console
  console.log('✅ Seed complete.');
  console.log(`   Demo login: ${email} / ${password}`);
}

main()
  .catch((e) => {
    // eslint-disable-next-line no-console
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
