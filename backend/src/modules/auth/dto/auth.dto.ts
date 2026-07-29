import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEmail,
  IsEnum,
  IsIn,
  IsOptional,
  IsString,
  Length,
  MaxLength,
  MinLength,
  IsBoolean,
  Equals,
} from 'class-validator';
import { Language } from '@prisma/client';

export class RegisterDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'StrongP@ssw0rd', minLength: 8 })
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password: string;

  @ApiProperty({ example: 'Yate', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  firstName?: string;

  @ApiProperty({ example: 'Ronald', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  lastName?: string;

  @ApiProperty({ enum: Language, required: false, default: Language.EN })
  @IsOptional()
  @IsEnum(Language)
  language?: Language;

  @ApiProperty({ required: false, example: 'Côte d’Ivoire' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  country?: string;

  @ApiProperty({ required: false, example: 'XOF' })
  @IsOptional()
  @IsString()
  @MaxLength(8)
  currency?: string;

  @ApiProperty({
    description:
      'Must be true. The user has read and accepted the Terms of Use and Privacy Policy.',
    example: true,
  })
  @IsBoolean()
  @Equals(true, {
    message: 'You must accept the Terms of Use and Privacy Policy to create an account',
  })
  acceptedTerms!: boolean;
}

export class LoginDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'StrongP@ssw0rd' })
  @IsString()
  password: string;
}

export class VerifyOtpDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: '123456' })
  @IsString()
  @Length(6, 6)
  code: string;
}

export class ResendOtpDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  email: string;
}

export class ForgotPasswordDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  email: string;
}

export class ResetPasswordDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: '123456' })
  @IsString()
  @Length(6, 6)
  code: string;

  @ApiProperty({ example: 'NewStrongP@ssw0rd', minLength: 8 })
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  newPassword: string;
}

export class RefreshTokenDto {
  @ApiProperty({ required: false, description: 'Refresh token (if not sent via cookie)' })
  @IsOptional()
  @IsString()
  refreshToken?: string;
}

export class ChangePasswordDto {
  @ApiPropertyOptional({
    description:
      'Required when the account already has a password. Omit when setting the first one (Google-created accounts).',
  })
  @IsOptional()
  @IsString()
  currentPassword?: string;

  @ApiProperty({ minLength: 8 })
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  newPassword: string;
}

export class GoogleTokenDto {
  @ApiProperty({ description: 'Google ID token obtained on-device by google_sign_in' })
  @IsString()
  idToken: string;

  @ApiPropertyOptional({
    enum: ['signin', 'signup'],
    default: 'signin',
    description:
      'signin fails when no account exists; signup fails when one already does.',
  })
  @IsOptional()
  @IsIn(['signin', 'signup'])
  intent?: 'signin' | 'signup';
}
