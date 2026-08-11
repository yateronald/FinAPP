import { Module } from '@nestjs/common';
import { FxModule } from '../fx/fx.module';
import { LoansController } from './loans.controller';
import { LoansService } from './loans.service';

@Module({
  imports: [FxModule],
  controllers: [LoansController],
  providers: [LoansService],
  // ExpensesService validates loanId before linking a payment.
  exports: [LoansService],
})
export class LoansModule {}
