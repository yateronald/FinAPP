import { Body, Controller, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AdminService } from './admin.service';
import {
  AuditLogQueryDto,
  CreateAdminDto,
  DisableUserDto,
  ListUsersQueryDto,
} from './dto/admin.dto';

@ApiTags('admin')
@ApiBearerAuth()
@Roles(Role.ADMIN) // every route below is admin-only (global RolesGuard)
@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get('stats')
  @ApiOperation({ summary: 'Platform monitoring KPIs (aggregates only)' })
  stats() {
    return this.admin.stats();
  }

  @Get('users')
  @ApiOperation({ summary: 'List/search users' })
  listUsers(@Query() query: ListUsersQueryDto) {
    return this.admin.listUsers(query);
  }

  @Get('users/:id')
  @ApiOperation({ summary: 'User detail with activity counters (no financial content)' })
  userDetail(@Param('id') id: string) {
    return this.admin.userDetail(id);
  }

  @Patch('users/:id/disable')
  @ApiOperation({ summary: 'Disable an account — blocks login and kills all sessions' })
  disable(
    @CurrentUser('userId') actorId: string,
    @Param('id') id: string,
    @Body() dto: DisableUserDto,
  ) {
    return this.admin.setActive(actorId, id, false, dto);
  }

  @Patch('users/:id/enable')
  @ApiOperation({ summary: 'Re-enable a disabled account' })
  enable(@CurrentUser('userId') actorId: string, @Param('id') id: string) {
    return this.admin.setActive(actorId, id, true);
  }

  @Post('users/:id/reset-password')
  @ApiOperation({
    summary: 'Reset a password — returns a one-time temporary password',
  })
  resetPassword(@CurrentUser('userId') actorId: string, @Param('id') id: string) {
    return this.admin.resetPassword(actorId, id);
  }

  @Get('admins')
  @ApiOperation({ summary: 'List admin accounts' })
  listAdmins() {
    return this.admin.listAdmins();
  }

  @Post('admins')
  @ApiOperation({ summary: 'Create an admin account' })
  createAdmin(@CurrentUser('userId') actorId: string, @Body() dto: CreateAdminDto) {
    return this.admin.createAdmin(actorId, dto);
  }

  @Get('audit-stats')
  @ApiOperation({ summary: 'Audit KPIs + sparklines for a date range' })
  auditStats(@Query('from') from?: string, @Query('to') to?: string) {
    return this.admin.auditStats(from, to);
  }

  @Get('audit-logs')
  @ApiOperation({ summary: 'Admin action trail' })
  auditLogs(@Query() query: AuditLogQueryDto) {
    return this.admin.auditLogs(query);
  }
}
