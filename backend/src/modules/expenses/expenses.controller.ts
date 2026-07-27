import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ExpensesService } from './expenses.service';
import { CreateExpenseDto, QueryExpenseDto, UpdateExpenseDto } from './dto/expense.dto';

@ApiTags('expenses')
@ApiBearerAuth()
@Controller('expenses')
export class ExpensesController {
  constructor(private readonly expenses: ExpensesService) {}

  @Post()
  @ApiOperation({ summary: 'Record an expense' })
  create(@CurrentUser('userId') userId: string, @Body() dto: CreateExpenseDto) {
    return this.expenses.create(userId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List / filter expenses' })
  list(@CurrentUser('userId') userId: string, @Query() query: QueryExpenseDto) {
    return this.expenses.list(userId, query);
  }

  @Get('overview')
  @ApiOperation({ summary: 'Expense overview: totals, split, distribution, trend' })
  overview(
    @CurrentUser('userId') userId: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('categoryId') categoryId?: string,
    @Query('categoryIds') categoryIds?: string,
  ) {
    const now = new Date();
    const start = from
      ? new Date(from)
      : new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
    const end = to
      ? new Date(new Date(to).getTime() + 24 * 60 * 60 * 1000) // inclusive `to`
      : new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));
    return this.expenses.overview(userId, start, end, categoryIds ?? categoryId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get one expense' })
  findOne(@CurrentUser('userId') userId: string, @Param('id') id: string) {
    return this.expenses.findOne(userId, id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update expense' })
  update(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Body() dto: UpdateExpenseDto,
  ) {
    return this.expenses.update(userId, id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete expense' })
  remove(@CurrentUser('userId') userId: string, @Param('id') id: string) {
    return this.expenses.remove(userId, id);
  }
}
