import { Body, Controller, Delete, Get, Param, Put, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { BudgetsService } from './budgets.service';
import { UpsertBudgetDto, UpsertOverallBudgetDto } from './dto/budget.dto';

@ApiTags('budgets')
@ApiBearerAuth()
@Controller('budgets')
export class BudgetsController {
  constructor(private readonly budgets: BudgetsService) {}

  /** Resolves month/year query params, defaulting to the current month. */
  private period(month?: string, year?: string) {
    const now = new Date();
    return {
      month: month ? parseInt(month, 10) : now.getUTCMonth() + 1,
      year: year ? parseInt(year, 10) : now.getUTCFullYear(),
    };
  }

  @Put()
  @ApiOperation({ summary: 'Create or update a category budget (optionally repeating)' })
  upsert(@CurrentUser('userId') userId: string, @Body() dto: UpsertBudgetDto) {
    return this.budgets.upsert(userId, dto);
  }

  // Declared before ':id' routes so the literal path is not read as an id.
  @Put('overall')
  @ApiOperation({ summary: "Set the month's overall spending cap (optionally repeating)" })
  upsertOverall(
    @CurrentUser('userId') userId: string,
    @Body() dto: UpsertOverallBudgetDto,
  ) {
    return this.budgets.upsertOverall(userId, dto);
  }

  @Get('overview')
  @ApiOperation({
    summary: 'Overall cap, category budgets and month totals for one month',
  })
  @ApiQuery({ name: 'month', required: false, type: Number })
  @ApiQuery({ name: 'year', required: false, type: Number })
  overview(
    @CurrentUser('userId') userId: string,
    @Query('month') month?: string,
    @Query('year') year?: string,
  ) {
    const { month: m, year: y } = this.period(month, year);
    return this.budgets.overview(userId, m, y);
  }

  @Get()
  @ApiOperation({ summary: 'Get category budget statuses with progress for a month' })
  @ApiQuery({ name: 'month', required: false, type: Number })
  @ApiQuery({ name: 'year', required: false, type: Number })
  getStatuses(
    @CurrentUser('userId') userId: string,
    @Query('month') month?: string,
    @Query('year') year?: string,
  ) {
    const { month: m, year: y } = this.period(month, year);
    return this.budgets.getStatuses(userId, m, y);
  }

  @Delete('overall/:id')
  @ApiOperation({ summary: 'Delete an overall budget' })
  @ApiQuery({
    name: 'series',
    required: false,
    type: Boolean,
    description: 'Also remove the remaining months of the repeat, keeping past months.',
  })
  removeOverall(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Query('series') series?: string,
  ) {
    return this.budgets.removeOverall(userId, id, series === 'true');
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a category budget' })
  @ApiQuery({
    name: 'series',
    required: false,
    type: Boolean,
    description: 'Also remove the remaining months of the repeat, keeping past months.',
  })
  remove(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Query('series') series?: string,
  ) {
    return this.budgets.remove(userId, id, series === 'true');
  }
}
