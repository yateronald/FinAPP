import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class RegisterTokenDto {
  @ApiProperty({ description: 'FCM registration token' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(4096)
  token!: string;

  @ApiProperty({ required: false, enum: ['android', 'ios', 'web'] })
  @IsOptional()
  @IsIn(['android', 'ios', 'web'])
  deviceType?: string;
}
