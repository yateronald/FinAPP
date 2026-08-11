import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsInt,
  IsNumber,
  IsOptional,
  Length,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateIncomeDto {
  @ApiPropertyOptional({
    description:
      'Set when this income is someone repaying a loan you granted. The loan ' +
      'must be one of yours and must be a LENT loan.',
  })
  @IsOptional()
  @IsString()
  loanId?: string;

  @ApiProperty({ example: 'Salary - July' })
  @IsString()
  @MaxLength(120)
  title: string;

  @ApiProperty()
  @IsString()
  categoryId: string;

  @ApiProperty({ example: 1000000 })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  amount: number;

  @ApiPropertyOptional({
    description:
      'Currency the amount was entered in, when it is not the base currency. ' +
      'The server converts it and freezes the rate on the row; `amount` is ' +
      'always stored in the base currency.',
    example: 'EUR',
  })
  @IsOptional()
  @IsString()
  @Length(3, 5)
  originalCurrency?: string;

  @ApiProperty({ example: '2026-07-01' })
  @IsDateString()
  date: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isRecurring?: boolean;
}

export class UpdateIncomeDto {
  @ApiPropertyOptional({
    description:
      'Set when this income is someone repaying a loan you granted. The loan ' +
      'must be one of yours and must be a LENT loan.',
  })
  @IsOptional()
  @IsString()
  loanId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(120)
  title?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  categoryId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  amount?: number;

  @ApiPropertyOptional({
    description:
      'Currency the amount was entered in, when it is not the base currency. ' +
      'The server converts it and freezes the rate on the row; `amount` is ' +
      'always stored in the base currency.',
    example: 'EUR',
  })
  @IsOptional()
  @IsString()
  @Length(3, 5)
  originalCurrency?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  date?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isRecurring?: boolean;
}

export class QueryIncomeDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  categoryId?: string;

  @ApiPropertyOptional({ description: 'Comma-separated category ids (multi-select filter)' })
  @IsOptional()
  @IsString()
  categoryIds?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  from?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  to?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  search?: string;

  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({ default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 20;
}
