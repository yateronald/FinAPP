import { ApiProperty } from '@nestjs/swagger';
import { AiProvider, Language, Theme } from '@prisma/client';
import { IsBoolean, IsEnum, IsIn, IsInt, IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';
import { AGENTROUTER_MODEL_IDS, GEMINI_MODEL_IDS } from '../../ai/ai-models';

export class UpdateSettingsDto {
  @ApiProperty({ enum: Language, required: false })
  @IsOptional()
  @IsEnum(Language)
  language?: Language;

  @ApiProperty({ required: false, example: 'XOF' })
  @IsOptional()
  @IsString()
  currency?: string;

  @ApiProperty({ enum: Theme, required: false })
  @IsOptional()
  @IsEnum(Theme)
  theme?: Theme;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsBoolean()
  notificationsEnabled?: boolean;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsBoolean()
  emailNotifications?: boolean;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsBoolean()
  aiEnabled?: boolean;

  @ApiProperty({ enum: AiProvider, required: false })
  @IsOptional()
  @IsEnum(AiProvider)
  aiProvider?: AiProvider;

  @ApiProperty({ required: false, enum: GEMINI_MODEL_IDS })
  @IsOptional()
  @IsIn(GEMINI_MODEL_IDS)
  geminiModel?: string;

  @ApiProperty({ required: false, enum: AGENTROUTER_MODEL_IDS })
  @IsOptional()
  @IsIn(AGENTROUTER_MODEL_IDS)
  agentRouterModel?: string;

  @ApiProperty({ required: false, minimum: 50, maximum: 100 })
  @IsOptional()
  @IsInt()
  @Min(50)
  @Max(100)
  budgetAlertThreshold?: number;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsNumber()
  @Min(0)
  largeExpenseThreshold?: number;
}
