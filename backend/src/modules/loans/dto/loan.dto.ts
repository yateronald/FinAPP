import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { LoanStatus } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  IsDateString,
  IsEnum,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateLoanDto {
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
  @IsNumber()
  @IsPositive()
  principalAmount!: number;

  @ApiPropertyOptional({
    example: 500000,
    default: 0,
    description: 'Amount already repaid before tracking started.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
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
  @IsNumber()
  @IsPositive()
  principalAmount?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
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
