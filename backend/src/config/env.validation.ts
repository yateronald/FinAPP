import { plainToInstance } from 'class-transformer';
import { IsEnum, IsNumber, IsOptional, IsString, MinLength, validateSync } from 'class-validator';

enum NodeEnv {
  Development = 'development',
  Production = 'production',
  Test = 'test',
}

class EnvironmentVariables {
  @IsEnum(NodeEnv)
  @IsOptional()
  NODE_ENV: NodeEnv;

  @IsNumber()
  @IsOptional()
  PORT: number;

  @IsString()
  DATABASE_URL: string;

  @IsString()
  @MinLength(16)
  JWT_ACCESS_SECRET: string;

  @IsString()
  @MinLength(16)
  JWT_REFRESH_SECRET: string;

  @IsString()
  @MinLength(16)
  COOKIE_SECRET: string;

  @IsString()
  @IsOptional()
  GEMINI_API_KEY: string;
}

export function validateEnv(config: Record<string, unknown>) {
  const validatedConfig = plainToInstance(EnvironmentVariables, config, {
    enableImplicitConversion: true,
  });
  const errors = validateSync(validatedConfig, { skipMissingProperties: false });

  if (errors.length > 0) {
    const messages = errors
      .map((e) => Object.values(e.constraints || {}).join(', '))
      .join('\n');
    throw new Error(`Environment validation failed:\n${messages}`);
  }
  return validatedConfig;
}
