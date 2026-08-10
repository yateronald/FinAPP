import { Module } from '@nestjs/common';
import { DashboardModule } from '../dashboard/dashboard.module';
import { LoansModule } from '../loans/loans.module';
import { IncomeController } from './income.controller';
import { IncomeService } from './income.service';

@Module({
  imports: [DashboardModule, LoansModule],
  controllers: [IncomeController],
  providers: [IncomeService],
  exports: [IncomeService],
})
export class IncomeModule {}
