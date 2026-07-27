import { Global, Module } from '@nestjs/common';
import { BudgetsController } from './budgets.controller';
import { BudgetsService } from './budgets.service';
import { BudgetEngineService } from './budget-engine.service';

@Global()
@Module({
  controllers: [BudgetsController],
  providers: [BudgetsService, BudgetEngineService],
  exports: [BudgetsService, BudgetEngineService],
})
export class BudgetsModule {}
