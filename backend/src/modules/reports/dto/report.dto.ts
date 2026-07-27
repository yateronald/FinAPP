import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsEnum, IsOptional, IsString } from 'class-validator';

export enum ReportPeriod {
  DAILY = 'daily',
  WEEKLY = 'weekly',
  MONTHLY = 'monthly',
  YEARLY = 'yearly',
  CUSTOM = 'custom',
}

export class ReportQueryDto {
  @ApiPropertyOptional({ enum: ReportPeriod, default: ReportPeriod.MONTHLY })
  @IsOptional()
  @IsEnum(ReportPeriod)
  period?: ReportPeriod = ReportPeriod.MONTHLY;

  @ApiPropertyOptional({ description: 'Start date for custom range' })
  @IsOptional()
  @IsDateString()
  from?: string;

  @ApiPropertyOptional({ description: 'End date for custom range' })
  @IsOptional()
  @IsDateString()
  to?: string;

  @ApiPropertyOptional({ description: 'Filter the whole report to a single category' })
  @IsOptional()
  @IsString()
  categoryId?: string;
}
