import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean, IsInt, IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';

export class UpsertBudgetDto {
  @ApiProperty()
  @IsString()
  categoryId: string;

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

  @ApiProperty({ required: false, default: false })
  @IsOptional()
  @IsBoolean()
  rollover?: boolean;
}
