import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { NotificationsService } from './notifications.service';
import { RegisterTokenDto } from './dto/register-token.dto';

@ApiTags('notifications')
@ApiBearerAuth()
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  @ApiOperation({ summary: 'List notifications' })
  @ApiQuery({ name: 'unreadOnly', required: false, type: Boolean })
  list(@CurrentUser('userId') userId: string, @Query('unreadOnly') unreadOnly?: string) {
    return this.notifications.list(userId, unreadOnly === 'true');
  }

  @Post('fcm-token')
  @ApiOperation({ summary: 'Register device FCM token for push notifications' })
  registerFcmToken(@CurrentUser('userId') userId: string, @Body() dto: RegisterTokenDto) {
    return this.notifications.registerFcmToken(userId, dto.token, dto.deviceType ?? 'android');
  }

  @Post('fcm-token/remove')
  @ApiOperation({ summary: 'Unregister a device token (disable push on this device)' })
  unregisterFcmToken(@CurrentUser('userId') userId: string, @Body() dto: RegisterTokenDto) {
    return this.notifications.unregisterFcmToken(userId, dto.token);
  }

  @Post('test')
  @ApiOperation({ summary: 'Send a test push to your own registered devices' })
  sendTest(@CurrentUser('userId') userId: string) {
    return this.notifications.sendTestPush(userId);
  }

  @Get('unread-count')
  @ApiOperation({ summary: 'Get unread notification count' })
  unreadCount(@CurrentUser('userId') userId: string) {
    return this.notifications.unreadCount(userId);
  }

  @Patch('read-all')
  @ApiOperation({ summary: 'Mark all as read' })
  markAllRead(@CurrentUser('userId') userId: string) {
    return this.notifications.markAllRead(userId);
  }

  @Patch(':id/read')
  @ApiOperation({ summary: 'Mark one as read' })
  markRead(@CurrentUser('userId') userId: string, @Param('id') id: string) {
    return this.notifications.markRead(userId, id);
  }

  // Declared before ':id' so the literal route is never swallowed by the param.
  @Delete('all')
  @ApiOperation({ summary: 'Delete every notification of the current user' })
  removeAll(@CurrentUser('userId') userId: string) {
    return this.notifications.removeAll(userId);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a notification' })
  remove(@CurrentUser('userId') userId: string, @Param('id') id: string) {
    return this.notifications.remove(userId, id);
  }
}
