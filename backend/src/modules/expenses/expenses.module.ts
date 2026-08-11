import { Module } from '@nestjs/common';
import { FxModule } from '../fx/fx.module';
import { DashboardModule } from '../dashboard/dashboard.module';
import { LoansModule } from '../loans/loans.module';
import { ExpensesController } from './expenses.controller';
import { ExpensesService } from './expenses.service';

@Module({
  imports: [FxModule, DashboardModule, LoansModule],
  controllers: [ExpensesController],
  providers: [ExpensesService],
  exports: [ExpensesService],
})
export class ExpensesModule {}
