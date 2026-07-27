import { Controller, Get, Query, Res } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Response } from 'express';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ReportsService } from './reports.service';
import { ReportQueryDto } from './dto/report.dto';

@ApiTags('reports')
@ApiBearerAuth()
@Controller('reports')
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  @Get()
  @ApiOperation({ summary: 'Generate a report (daily/weekly/monthly/yearly/custom)' })
  generate(@CurrentUser('userId') userId: string, @Query() query: ReportQueryDto) {
    return this.reports.generate(userId, query);
  }

  @Get('overview')
  @ApiOperation({ summary: 'Rich report overview: cards, charts, evolution, budgets' })
  overview(@CurrentUser('userId') userId: string, @Query() query: ReportQueryDto) {
    return this.reports.overview(userId, query);
  }

  @Get('export/csv')
  @ApiOperation({ summary: 'Export report transactions as CSV' })
  async exportCsv(
    @CurrentUser('userId') userId: string,
    @Query() query: ReportQueryDto,
    @Res() res: Response,
  ) {
    const csv = await this.reports.toCsv(userId, query);
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="finapp-report.csv"`);
    res.send(csv);
  }
}
