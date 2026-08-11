import { Module } from '@nestjs/common';
import { FxController } from './fx.controller';
import { AuditModule } from '../audit/audit.module';
import { BaseCurrencyService } from './base-currency.service';
import { FxService } from './fx.service';
import { MoneyWriterService } from './money-writer.service';
import { ExchangeRateFunProvider } from './providers/exchangerate-fun.provider';

/**
 * Exported so transaction writes can freeze a rate onto each row, without any
 * of them knowing which provider produced it.
 */
@Module({
  imports: [AuditModule],
  controllers: [FxController],
  providers: [FxService, MoneyWriterService, BaseCurrencyService, ExchangeRateFunProvider],
  exports: [FxService, MoneyWriterService, BaseCurrencyService],
})
export class FxModule {}
