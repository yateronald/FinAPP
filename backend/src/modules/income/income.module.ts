import { Module } from '@nestjs/common';
import { DashboardModule } from '../dashboard/dashboard.module';
import { IncomeController } from './income.controller';
import { IncomeService } from './income.service';

@Module({
  imports: [DashboardModule],
  controllers: [IncomeController],
  providers: [IncomeService],
  exports: [IncomeService],
})
export class IncomeModule {}
