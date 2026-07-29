import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString, IsUrl, MaxLength, Matches } from 'class-validator';

export class UpdateProfileDto {
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  firstName?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  lastName?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsUrl()
  avatarUrl?: string;
}

/**
 * Typed confirmation for account erasure.
 *
 * Validated server-side as well as in the UI: a destructive, irreversible
 * endpoint must not be reachable by an accidental or scripted DELETE.
 */
export class DeleteAccountDto {
  @ApiProperty({
    description: 'Must be the literal word DELETE (English) or SUPPRIMER (French).',
    example: 'DELETE',
  })
  @IsString()
  @Matches(/^(DELETE|SUPPRIMER)$/i, {
    message: 'Type DELETE or SUPPRIMER to confirm permanent deletion',
  })
  confirmation!: string;
}
