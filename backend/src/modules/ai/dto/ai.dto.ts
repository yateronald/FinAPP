import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export class AskAiDto {
  @ApiProperty({ example: 'Can I afford to buy a new laptop this month?' })
  @IsString()
  @MaxLength(1000)
  question: string;
}

export class ChatMessageDto {
  @ApiProperty({ enum: ['user', 'assistant'] })
  @IsIn(['user', 'assistant'])
  role: 'user' | 'assistant';

  @ApiProperty()
  @IsString()
  @MaxLength(4000)
  content: string;
}

export class ChatDto {
  @ApiProperty({ example: 'How much did I spend on food last month?' })
  @IsString()
  @MaxLength(2000)
  message: string;

  @ApiPropertyOptional({ type: [ChatMessageDto], description: 'Prior conversation turns' })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ChatMessageDto)
  history?: ChatMessageDto[];
}

export class GenerateInsightsDto {
  @ApiPropertyOptional({ example: 7 })
  @IsOptional()
  @IsInt()
  @Min(1)
  month?: number;

  @ApiPropertyOptional({ example: 2026 })
  @IsOptional()
  @IsInt()
  @Min(2000)
  year?: number;
}
