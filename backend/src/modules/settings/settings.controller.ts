import { Body, Controller, Get, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SettingsService } from './settings.service';
import { UpdateSettingsDto } from './dto/settings.dto';

@ApiTags('settings')
@ApiBearerAuth()
@Controller('settings')
export class SettingsController {
  constructor(private readonly settings: SettingsService) {}

  @Get()
  @ApiOperation({ summary: 'Get user settings' })
  get(@CurrentUser('userId') userId: string) {
    return this.settings.get(userId);
  }

  @Patch()
  @ApiOperation({ summary: 'Update user settings' })
  update(@CurrentUser('userId') userId: string, @Body() dto: UpdateSettingsDto) {
    return this.settings.update(userId, dto);
  }

  @Get('export')
  @ApiOperation({ summary: 'Export all user data (GDPR)' })
  export(@CurrentUser('userId') userId: string) {
    return this.settings.exportData(userId);
  }
}
