import { Global, Module } from '@nestjs/common';
import { AiModule } from '../ai/ai.module';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { NotificationsCronService } from './notifications-cron.service';

@Global()
@Module({
  imports: [AiModule],
  controllers: [NotificationsController],
  providers: [NotificationsService, NotificationsCronService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
