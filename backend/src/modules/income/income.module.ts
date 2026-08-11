import { Module } from '@nestjs/common';
import { FxModule } from '../fx/fx.module';
import { DashboardModule } from '../dashboard/dashboard.module';
import { LoansModule } from '../loans/loans.module';
import { IncomeController } from './income.controller';
import { IncomeService } from './income.service';

@Module({
  imports: [FxModule, DashboardModule, LoansModule],
  controllers: [IncomeController],
  providers: [IncomeService],
  exports: [IncomeService],
})
export class IncomeModule {}
