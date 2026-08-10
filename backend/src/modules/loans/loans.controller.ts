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
import { LoansService } from './loans.service';
import {
  CreateLoanDto,
  ListLoansQueryDto,
  SelectableLoansQueryDto,
  UpdateLoanDto,
} from './dto/loan.dto';

@ApiTags('loans')
@ApiBearerAuth()
@Controller('loans')
export class LoansController {
  constructor(private readonly loans: LoansService) {}

  @Get()
  @ApiOperation({
    summary: 'List loans with repayment progress',
    description: 'Active only by default; pass includeClosed=true for the rest.',
  })
  list(@CurrentUser('userId') userId: string, @Query() query: ListLoansQueryDto) {
    return this.loans.list(userId, query);
  }

  @Get('selectable')
  @ApiOperation({
    summary: 'Active loans a transaction can be attached to',
    description:
      'Defaults to BORROWED (the expense form); pass direction=LENT for the ' +
      'income form. An empty array means none exist yet.',
  })
  selectable(
    @CurrentUser('userId') userId: string,
    @Query() query: SelectableLoansQueryDto,
  ) {
    return this.loans.selectable(userId, query.direction);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Loan detail with its payment history grouped by month' })
  detail(@CurrentUser('userId') userId: string, @Param('id') id: string) {
    return this.loans.detail(userId, id);
  }

  @Post()
  @ApiOperation({ summary: 'Create a loan' })
  create(@CurrentUser('userId') userId: string, @Body() dto: CreateLoanDto) {
    return this.loans.create(userId, dto);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update a loan' })
  update(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Body() dto: UpdateLoanDto,
  ) {
    return this.loans.update(userId, id, dto);
  }

  @Delete(':id')
  @ApiOperation({
    summary: 'Remove a loan',
    description:
      'Soft-deletes the loan and unlinks its payments. The expenses themselves ' +
      'are kept — they are real spending and must stay in the history.',
  })
  remove(@CurrentUser('userId') userId: string, @Param('id') id: string) {
    return this.loans.remove(userId, id);
  }
}
