import { Body, Controller, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AiService } from './ai.service';
import { AiChatService } from './ai-chat.service';
import { ForecastService } from './forecast.service';
import { AskAiDto, ChatDto } from './dto/ai.dto';
import { AI_MODELS } from './ai-models';

@ApiTags('ai')
@ApiBearerAuth()
@Controller('ai')
export class AiController {
  constructor(
    private readonly ai: AiService,
    private readonly aiChat: AiChatService,
    private readonly forecast: ForecastService,
  ) {}

  @Get('models')
  @ApiOperation({ summary: 'Available AI models per provider' })
  models() {
    return AI_MODELS;
  }

  @Get('forecast')
  @ApiOperation({ summary: 'Cash-flow forecast (Holt smoothing) for the next horizon' })
  getForecast(@CurrentUser('userId') userId: string, @Query('horizon') horizon?: string) {
    const days = horizon ? Math.min(90, Math.max(7, parseInt(horizon, 10))) : 30;
    return this.forecast.forecast(userId, days);
  }

  private period(month?: string, year?: string) {
    const now = new Date();
    return {
      month: month ? parseInt(month, 10) : now.getUTCMonth() + 1,
      year: year ? parseInt(year, 10) : now.getUTCFullYear(),
    };
  }

  @Post('chat')
  @ApiOperation({ summary: 'Conversational AI assistant with data-query tools' })
  chat(@CurrentUser('userId') userId: string, @Body() dto: ChatDto) {
    return this.aiChat.chat(userId, dto.message, dto.history ?? []);
  }

  @Post('ask')
  @ApiOperation({ summary: 'Ask the AI finance assistant a question' })
  ask(
    @CurrentUser('userId') userId: string,
    @Body() dto: AskAiDto,
    @Query('month') month?: string,
    @Query('year') year?: string,
  ) {
    const { month: m, year: y } = this.period(month, year);
    return this.ai.ask(userId, dto.question, m, y);
  }

  @Post('insights/generate')
  @ApiOperation({ summary: 'Generate AI insights for a period and specific scope' })
  @ApiQuery({ name: 'month', required: false, type: Number })
  @ApiQuery({ name: 'year', required: false, type: Number })
  @ApiQuery({ name: 'scope', required: false, enum: ['GLOBAL', 'BUDGET', 'EXPENSE', 'INCOME'] })
  generate(
    @CurrentUser('userId') userId: string,
    @Query('month') month?: string,
    @Query('year') year?: string,
    @Query('scope') scope?: 'GLOBAL' | 'BUDGET' | 'EXPENSE' | 'INCOME',
  ) {
    const { month: m, year: y } = this.period(month, year);
    return this.ai.generateInsights(userId, m, y, scope ?? 'GLOBAL');
  }

  @Get('insights')
  @ApiOperation({ summary: 'List saved AI insights' })
  list(@CurrentUser('userId') userId: string) {
    return this.ai.listInsights(userId);
  }

  @Patch('insights/:id/read')
  @ApiOperation({ summary: 'Mark an insight as read' })
  markRead(@CurrentUser('userId') userId: string, @Param('id') id: string) {
    return this.ai.markInsightRead(userId, id);
  }

  @Get('monthly-summary')
  @ApiOperation({ summary: 'AI-generated monthly summary' })
  monthlySummary(
    @CurrentUser('userId') userId: string,
    @Query('month') month?: string,
    @Query('year') year?: string,
  ) {
    const { month: m, year: y } = this.period(month, year);
    return this.ai.monthlySummary(userId, m, y);
  }
}
