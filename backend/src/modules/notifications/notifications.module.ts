import { Global, Module } from '@nestjs/common';
import { AiModule } from '../ai/ai.module';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { NotificationsCronService } from './notifications-cron.service';
import { EngagementService } from './engagement.service';

@Global()
@Module({
  imports: [AiModule],
  controllers: [NotificationsController],
  providers: [NotificationsService, NotificationsCronService, EngagementService],
  // AuthService sends the first-sign-in welcome.
  exports: [NotificationsService, EngagementService],
})
export class NotificationsModule {}
