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
import { IncomeService } from './income.service';
import { CreateIncomeDto, QueryIncomeDto, UpdateIncomeDto } from './dto/income.dto';

@ApiTags('income')
@ApiBearerAuth()
@Controller('income')
export class IncomeController {
  constructor(private readonly income: IncomeService) {}

  @Post()
  @ApiOperation({ summary: 'Record income' })
  create(@CurrentUser('userId') userId: string, @Body() dto: CreateIncomeDto) {
    return this.income.create(userId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List / filter income' })
  list(@CurrentUser('userId') userId: string, @Query() query: QueryIncomeDto) {
    return this.income.list(userId, query);
  }

  @Get('overview')
  @ApiOperation({ summary: 'Income overview: totals, split, distribution, trend' })
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
    return this.income.overview(userId, start, end, categoryIds ?? categoryId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get one income record' })
  findOne(@CurrentUser('userId') userId: string, @Param('id') id: string) {
    return this.income.findOne(userId, id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update income' })
  update(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Body() dto: UpdateIncomeDto,
  ) {
    return this.income.update(userId, id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete income' })
  remove(@CurrentUser('userId') userId: string, @Param('id') id: string) {
    return this.income.remove(userId, id);
  }
}
