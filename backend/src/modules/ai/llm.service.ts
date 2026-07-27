import { Injectable } from '@nestjs/common';
import { AgentRouterClient } from './agentrouter.client';
import { GeminiClient } from './gemini.client';
import { LlmProvider } from './llm.interface';

export type AiProviderName = 'GEMINI' | 'AGENTROUTER';

/**
 * Selects the AI provider for a request based on the user's `settings.aiProvider`
 * choice, with graceful fallback to whichever provider is actually configured.
 */
@Injectable()
export class LlmService {
  constructor(
    private readonly gemini: GeminiClient,
    private readonly agentRouter: AgentRouterClient,
  ) {}

  provider(choice?: string | null): { provider: LlmProvider; name: AiProviderName } {
    const c = (choice ?? 'GEMINI').toUpperCase();
    if (c === 'AGENTROUTER' && this.agentRouter.isConfigured) {
      return { provider: this.agentRouter, name: 'AGENTROUTER' };
    }
    if (this.gemini.isConfigured) return { provider: this.gemini, name: 'GEMINI' };
    if (this.agentRouter.isConfigured) return { provider: this.agentRouter, name: 'AGENTROUTER' };
    return { provider: this.gemini, name: 'GEMINI' };
  }

  get anyConfigured(): boolean {
    return this.gemini.isConfigured || this.agentRouter.isConfigured;
  }
}
