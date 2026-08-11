import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsOptional, IsString, Length } from 'class-validator';
import { Type } from 'class-transformer';
import { IsNumber } from 'class-validator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { BaseCurrencyService } from './base-currency.service';
import { FxService } from './fx.service';
import { CURRENCIES } from './currencies';

class ConvertQueryDto {
  @IsString() @Length(3, 5) from!: string;
  @IsString() @Length(3, 5) to!: string;
  @Type(() => Number) @IsNumber({ maxDecimalPlaces: 6 }) amount!: number;
}

class ChangeBaseDto {
  @IsString() @Length(3, 5) currency!: string;
}

class CurrencyQueryDto {
  @IsOptional() @IsString() search?: string;
}

@ApiTags('currency')
@ApiBearerAuth()
@Controller('currency')
export class FxController {
  constructor(
    private readonly fx: FxService,
    private readonly baseCurrency: BaseCurrencyService,
  ) {}

  @Get('list')
  @ApiOperation({
    summary: 'Currencies the app can offer',
    description:
      'The static ISO 4217 catalogue, each marked with whether a live rate is ' +
      'currently available. A currency without a rate can still be chosen — it ' +
      'simply will not be converted until rates return.',
  })
  async list(@Query() query: CurrencyQueryDto) {
    const supported = new Set(await this.fx.supportedCodes());
    const term = query.search?.trim().toLowerCase();
    return CURRENCIES.filter(
      (c) =>
        !term ||
        c.code.toLowerCase().includes(term) ||
        c.name.toLowerCase().includes(term),
    ).map((c) => ({ ...c, convertible: supported.has(c.code) }));
  }

  @Get('status')
  @ApiOperation({
    summary: 'How fresh the exchange rates are',
    description:
      'quality is live | stale | unavailable. The client uses it to decide ' +
      'whether to caveat a converted figure. It never means the app should ' +
      'stop working.',
  })
  status() {
    return this.fx.status();
  }

  @Get('convert')
  @ApiOperation({
    summary: 'Convert an amount between two currencies',
    description:
      'Used for the live preview while entering a transaction. Never fails ' +
      'because of missing rates: if none are available the amount is returned ' +
      'unchanged with quality "unavailable".',
  })
  convert(@Query() query: ConvertQueryDto) {
    return this.fx.convert(query.amount, query.from, query.to);
  }

  @Get('base/preview')
  @ApiOperation({
    summary: 'What changing the base currency would do',
    description:
      'Returns the rate, how many rows would be rewritten and a worked example. ' +
      'Nothing is modified. The client must show this before asking to confirm: ' +
      'the change is not exactly reversible, because every amount is rounded to ' +
      'two decimals and the rate back will differ.',
  })
  previewBase(@CurrentUser('userId') userId: string, @Query() q: ChangeBaseDto) {
    return this.baseCurrency.preview(userId, q.currency);
  }

  @Post('base')
  @ApiOperation({
    summary: 'Change the base currency and convert everything',
    description:
      'Multiplies every stored amount by a single rate, in one transaction, and ' +
      'records the change. Original amounts are left untouched. Fails cleanly ' +
      'and changes nothing if rates are unavailable.',
  })
  changeBase(@CurrentUser('userId') userId: string, @Body() dto: ChangeBaseDto) {
    return this.baseCurrency.change(userId, dto.currency);
  }

  @Get('base/history')
  @ApiOperation({ summary: 'Previous base-currency changes' })
  baseHistory(@CurrentUser('userId') userId: string) {
    return this.baseCurrency.history(userId);
  }
}
