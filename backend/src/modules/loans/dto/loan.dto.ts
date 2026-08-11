import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { LoanDirection, LoanStatus } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  IsDateString,
  IsEnum,
  IsNumber,
  IsOptional,
  Length,
  IsPositive,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateLoanDto {
  @ApiPropertyOptional({
    enum: LoanDirection,
    default: LoanDirection.BORROWED,
    description:
      'BORROWED = money you owe, settled by an expense. LENT = money owed to ' +
      'you, settled by an income.',
  })
  @IsOptional()
  @IsEnum(LoanDirection)
  direction?: LoanDirection;

  @ApiProperty({ example: 'Car loan' })
  @IsString()
  @MaxLength(80)
  name!: string;

  @ApiPropertyOptional({ example: 'Bank loan for the family car' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @ApiPropertyOptional({ example: 'Ecobank' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  lender?: string;

  @ApiProperty({ example: 2500000, description: 'Total amount borrowed' })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  principalAmount!: number;

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

  @ApiPropertyOptional({
    example: 500000,
    default: 0,
    description: 'Amount already repaid before tracking started.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  initialPaidAmount?: number;

  @ApiProperty({ example: '2026-01-15T00:00:00.000Z' })
  @IsDateString()
  startDate!: string;

  @ApiPropertyOptional({ example: '2028-01-15T00:00:00.000Z' })
  @IsOptional()
  @IsDateString()
  expectedEndDate?: string;
}

export class UpdateLoanDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(80)
  name?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(80)
  lender?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  principalAmount?: number;

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
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  initialPaidAmount?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  startDate?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  expectedEndDate?: string;

  @ApiPropertyOptional({ enum: LoanStatus })
  @IsOptional()
  @IsEnum(LoanStatus)
  status?: LoanStatus;
}

export class ListLoansQueryDto {
  @ApiPropertyOptional({ enum: LoanDirection })
  @IsOptional()
  @IsEnum(LoanDirection)
  direction?: LoanDirection;

  @ApiPropertyOptional({ enum: LoanStatus })
  @IsOptional()
  @IsEnum(LoanStatus)
  status?: LoanStatus;

  @ApiPropertyOptional({
    default: false,
    description: 'Include archived and fully repaid loans.',
  })
  @IsOptional()
  @IsString()
  includeClosed?: string;
}

export class SelectableLoansQueryDto {
  @ApiPropertyOptional({
    enum: LoanDirection,
    default: LoanDirection.BORROWED,
    description:
      'Which side to offer: BORROWED for the expense form, LENT for the income form.',
  })
  @IsOptional()
  @IsEnum(LoanDirection)
  direction?: LoanDirection;
}
