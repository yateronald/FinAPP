import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsInt, IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';

/** Shared by both budget kinds: how much, from when, and for how long. */
class BudgetPeriodDto {
  @ApiProperty({ example: 3000 })
  @IsNumber()
  @Min(0)
  amount: number;

  @ApiProperty({ example: 7, minimum: 1, maximum: 12 })
  @IsInt()
  @Min(1)
  @Max(12)
  month: number;

  @ApiProperty({ example: 2026 })
  @IsInt()
  @Min(2000)
  year: number;

  @ApiPropertyOptional({
    default: 1,
    minimum: 1,
    maximum: 24,
    description:
      'How many consecutive months this budget applies to, starting at ' +
      'month/year. Each month is written as its own independent row, so a ' +
      'later edit or an overspend never rewrites a past month.',
  })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(24)
  repeatMonths?: number;
}

export class UpsertBudgetDto extends BudgetPeriodDto {
  @ApiProperty()
  @IsString()
  categoryId: string;

  @ApiProperty({ required: false, default: false })
  @IsOptional()
  @IsBoolean()
  rollover?: boolean;
}

/** The month-wide cap that every expense counts against. */
export class UpsertOverallBudgetDto extends BudgetPeriodDto {}
