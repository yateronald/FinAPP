import { BadRequestException, Controller, Get, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { DashboardService } from './dashboard.service';

@ApiTags('dashboard')
@ApiBearerAuth()
@Controller('dashboard')
export class DashboardController {
  constructor(private readonly dashboard: DashboardService) {}

  private parseDate(value: string | undefined, fallback: Date): Date {
    if (!value) return fallback;
    const d = new Date(value);
    if (isNaN(d.getTime())) throw new BadRequestException(`Invalid date: ${value}`);
    return d;
  }

  @Get()
  @ApiOperation({ summary: 'Dashboard payload for a date range with optional comparison' })
  @ApiQuery({ name: 'from', required: false, description: 'ISO start date (inclusive)' })
  @ApiQuery({ name: 'to', required: false, description: 'ISO end date (exclusive)' })
  @ApiQuery({ name: 'compareFrom', required: false })
  @ApiQuery({ name: 'compareTo', required: false })
  @ApiQuery({ name: 'anchorMonth', required: false, type: Number })
  @ApiQuery({ name: 'anchorYear', required: false, type: Number })
  getDashboard(
    @CurrentUser('userId') userId: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('compareFrom') compareFrom?: string,
    @Query('compareTo') compareTo?: string,
    @Query('anchorMonth') anchorMonth?: string,
    @Query('anchorYear') anchorYear?: string,
  ) {
    const now = new Date();
    const defaultStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
    const defaultEnd = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));

    const start = this.parseDate(from, defaultStart);
    const end = this.parseDate(to, defaultEnd);
    const compareStart = compareFrom ? this.parseDate(compareFrom, start) : undefined;
    const compareEnd = compareTo ? this.parseDate(compareTo, end) : undefined;

    // Anchor month for monthly widgets (budgets / daily). Defaults to the month
    // containing the last day of the selected range.
    const lastDay = new Date(end.getTime() - 1);
    const aMonth = anchorMonth ? parseInt(anchorMonth, 10) : lastDay.getUTCMonth() + 1;
    const aYear = anchorYear ? parseInt(anchorYear, 10) : lastDay.getUTCFullYear();

    return this.dashboard.getDashboard(userId, {
      start,
      end,
      compareStart,
      compareEnd,
      anchorMonth: aMonth,
      anchorYear: aYear,
    });
  }

  @Get('summary')
  @ApiOperation({ summary: 'Month-based summary (income, expenses, savings, score)' })
  getSummary(
    @CurrentUser('userId') userId: string,
    @Query('month') month?: string,
    @Query('year') year?: string,
    @Query('compareMonth') compareMonth?: string,
    @Query('compareYear') compareYear?: string,
  ) {
    const now = new Date();
    const m = month ? parseInt(month, 10) : now.getUTCMonth() + 1;
    const y = year ? parseInt(year, 10) : now.getUTCFullYear();
    const cm = compareMonth ? parseInt(compareMonth, 10) : undefined;
    const cy = compareYear ? parseInt(compareYear, 10) : undefined;
    return this.dashboard.getSummary(userId, m, y, cm, cy);
  }
}
