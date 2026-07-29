import { Body, Controller, Delete, Get, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UsersService } from './users.service';
import { DeleteAccountDto, UpdateProfileDto } from './dto/user.dto';

@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Get current user profile' })
  getMe(@CurrentUser('userId') userId: string) {
    return this.users.getProfile(userId);
  }

  @Patch('me')
  @ApiOperation({ summary: 'Update current user profile' })
  updateMe(@CurrentUser('userId') userId: string, @Body() dto: UpdateProfileDto) {
    return this.users.updateProfile(userId, dto);
  }

  @Get('me/deletion-impact')
  @ApiOperation({
    summary: 'What deleting this account would erase',
    description: 'Call before DELETE so the confirmation can state the real cost.',
  })
  deletionImpact(@CurrentUser('userId') userId: string) {
    return this.users.deletionImpact(userId);
  }

  @Delete('me')
  @ApiOperation({
    summary: 'Permanently erase the account and all of its data',
    description:
      'Irreversible. Requires `confirmation` to be the literal word DELETE or SUPPRIMER — ' +
      'enforced here as well as in the UI, so an accidental or scripted call cannot erase an account.',
  })
  deleteMe(@CurrentUser('userId') userId: string, @Body() dto: DeleteAccountDto) {
    return this.users.deleteAccount(userId);
  }
}
