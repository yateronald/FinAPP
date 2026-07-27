import { ApiProperty } from '@nestjs/swagger';
import { CategoryType } from '@prisma/client';
import {
  IsArray,
  IsEnum,
  IsHexColor,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateCategoryDto {
  @ApiProperty({ example: 'Groceries' })
  @IsString()
  @MaxLength(50)
  name: string;

  @ApiProperty({ enum: CategoryType })
  @IsEnum(CategoryType)
  type: CategoryType;

  @ApiProperty({ required: false, example: 'shopping-cart' })
  @IsOptional()
  @IsString()
  icon?: string;

  @ApiProperty({ required: false, example: '#22c55e' })
  @IsOptional()
  @IsHexColor()
  color?: string;
}

export class UpdateCategoryDto {
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  name?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  icon?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsHexColor()
  color?: string;
}

export class ReorderItemDto {
  @ApiProperty()
  @IsString()
  id: string;

  @ApiProperty()
  sortOrder: number;
}

export class ReorderCategoriesDto {
  @ApiProperty({ type: [ReorderItemDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ReorderItemDto)
  items: ReorderItemDto[];
}
