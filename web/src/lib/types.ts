export interface Category {
  id: string;
  name: string;
  type: 'INCOME' | 'EXPENSE';
  icon: string | null;
  color: string | null;
  isDefault: boolean;
  isArchived: boolean;
  sortOrder: number;
}

export interface Transaction {
  id: string;
  title: string;
  amount: number;
  date: string;
  description: string | null;
  category: Category;
  isRecurring?: boolean;
  paymentMethod?: string | null;
  tags?: string[];
}

export interface Paginated<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
  totalAmount: number;
}

export interface DashboardSummary {
  totalIncome: number;
  totalExpenses: number;
  netSavings: number;
  savingsRate: number;
  hasComparison: boolean;
  comparison: { income: number; expenses: number; savings: number };
  trends: { income: number; expenses: number; savings: number };
  financialScore: number;
}

export interface ExpenseSlice {
  categoryId: string;
  name: string;
  color: string;
  icon: string;
  amount: number;
  percentage: number;
}

export interface TrendPoint {
  month: number;
  year: number;
  label: string;
  income: number;
  expenses: number;
}

export interface BudgetStatus {
  id: string;
  categoryId: string;
  categoryName: string;
  icon: string | null;
  color: string | null;
  budget: number;
  spent: number;
  remaining: number;
  progress: number;
  status: 'ok' | 'warning' | 'danger' | 'exceeded';
  month: number;
  year: number;
}

export interface RecentTransaction {
  id: string;
  type: 'INCOME' | 'EXPENSE';
  title: string;
  amount: number;
  date: string;
  category: string;
  color: string | null;
  icon: string | null;
}

export interface DailyExpenses {
  days: { day: number; amount: number }[];
  dailyObjective: number | null;
  averageSpent: number;
}

export interface DashboardData {
  summary: DashboardSummary;
  range: { from: string; to: string };
  comparedTo: { from: string; to: string } | null;
  expenseDistribution: ExpenseSlice[];
  incomeDistribution: ExpenseSlice[];
  incomeVsExpenses: TrendPoint[];
  budgets: BudgetStatus[];
  recentTransactions: RecentTransaction[];
  dailyExpenses: DailyExpenses;
}

export interface AiInsight {
  type: string;
  title: string;
  content: string;
  severity?: 'info' | 'warning' | 'critical';
}

export interface StoredInsight extends AiInsight {
  id: string;
  isRead: boolean;
  createdAt: string;
}

export interface ReportCategoryRow {
  category: string;
  color?: string | null;
  amount: number;
}

export interface IncomeOverview {
  total: number;
  count: number;
  average: number;
  totalTrend: number;
  averageTrend: number;
  recurring: { amount: number; percentage: number };
  oneTime: { amount: number; percentage: number };
  max: { amount: number; title: string; category: string; date: string } | null;
  distribution: ExpenseSlice[];
  trend: { label: string; income: number }[];
}

export interface ForecastModelInfo {
  name: string; // technical id, e.g. "damped-holt(a=0.5,b=0.1,phi=0.95)"
  label: string;
  mae: number | null; // backtested one-step mean absolute error (monthly units)
}

export interface Forecast {
  horizonDays: number;
  generatedAt: string;
  models: { income: ForecastModelInfo; expenses: ForecastModelInfo };
  overview: {
    projectedIncome: number;
    incomeTrend: number;
    projectedExpenses: number;
    expenseTrend: number;
    projectedSavings: number;
    savingsTrend: number;
    projectedBalance: number;
    balanceDate: string;
  };
  cashflow: {
    date: string;
    actual: number | null;
    forecast: number | null;
    lower: number | null;
    upper: number | null;
  }[];
  byCategory: {
    categoryId: string;
    name: string;
    color: string;
    projected: number;
    evolution: number;
    percentage: number;
  }[];
  totalProjected: number;
  alerts: { type: 'warning' | 'good'; title: string; detail: string }[];
  suggestions: { text: string; cta: string }[];
  objectives: {
    name: string;
    current: number;
    target: number;
    percentage: number;
    etaDate: string | null;
  }[];
}

export interface ExpenseOverview {
  total: number;
  count: number;
  avgPerDay: number;
  totalTrend: number;
  countDiff: number;
  topCategory: ExpenseSlice | null;
  fixed: { amount: number; percentage: number };
  variable: { amount: number; percentage: number };
  categoryCount: number;
  distribution: ExpenseSlice[];
  trend: { label: string; expenses: number }[];
}

export interface ReportOverview {
  period: string;
  from: string;
  to: string;
  summary: {
    income: number;
    incomeTrend: number;
    incomeSeries: number[];
    expenses: number;
    expenseTrend: number;
    expenseSeries: number[];
    savings: number;
    savingsTrend: number;
    savingsSeries: number[];
    savingsRate: number;
    savingsRateTrend: number;
    rateSeries: number[];
  };
  incomeVsExpenses: { label: string; income: number; expenses: number }[];
  expenseByCategory: ExpenseSlice[];
  monthlyEvolution: {
    month: number;
    year: number;
    label: string;
    income: number;
    expenses: number;
    savings: number;
    savingsRate: number;
  }[];
  budgets: {
    respectedPct: number;
    respectedCount: number;
    totalCount: number;
    items: {
      category: string;
      color: string | null;
      icon: string | null;
      budget: number;
      spent: number;
      progress: number;
      status: 'ok' | 'warning' | 'danger' | 'exceeded';
    }[];
  };
  aiSummary: string;
}

export interface ReportData {
  period: string;
  from: string;
  to: string;
  totals: {
    income: number;
    expenses: number;
    net: number;
    incomeCount: number;
    expenseCount: number;
  };
  incomeByCategory: ReportCategoryRow[];
  expenseByCategory: ReportCategoryRow[];
}
