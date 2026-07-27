import { Module } from '@nestjs/common';
import { DashboardModule } from '../dashboard/dashboard.module';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';
import { AiChatService } from './ai-chat.service';
import { ForecastService } from './forecast.service';
import { GeminiClient } from './gemini.client';
import { AgentRouterClient } from './agentrouter.client';
import { LlmService } from './llm.service';

@Module({
  imports: [DashboardModule],
  controllers: [AiController],
  providers: [
    AiService,
    AiChatService,
    ForecastService,
    GeminiClient,
    AgentRouterClient,
    LlmService,
  ],
  exports: [AiService],
})
export class AiModule {}
