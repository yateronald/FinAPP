import { Body, Controller, Delete, Get, Param, Put, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { BudgetsService } from './budgets.service';
import { UpsertBudgetDto } from './dto/budget.dto';

@ApiTags('budgets')
@ApiBearerAuth()
@Controller('budgets')
export class BudgetsController {
  constructor(private readonly budgets: BudgetsService) {}

  @Put()
  @ApiOperation({ summary: 'Create or update a monthly budget objective' })
  upsert(@CurrentUser('userId') userId: string, @Body() dto: UpsertBudgetDto) {
    return this.budgets.upsert(userId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'Get budget statuses with progress for a month' })
  @ApiQuery({ name: 'month', required: false, type: Number })
  @ApiQuery({ name: 'year', required: false, type: Number })
  getStatuses(
    @CurrentUser('userId') userId: string,
    @Query('month') month?: string,
    @Query('year') year?: string,
  ) {
    const now = new Date();
    const m = month ? parseInt(month, 10) : now.getUTCMonth() + 1;
    const y = year ? parseInt(year, 10) : now.getUTCFullYear();
    return this.budgets.getStatuses(userId, m, y);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a budget objective' })
  remove(@CurrentUser('userId') userId: string, @Param('id') id: string) {
    return this.budgets.remove(userId, id);
  }
}
