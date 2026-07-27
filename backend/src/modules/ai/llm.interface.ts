import { FunctionDeclaration, GeminiContent } from './gemini.client';

export interface GenerateContentOpts {
  system?: string;
  tools?: FunctionDeclaration[];
  maxOutputTokens?: number;
  thinking?: boolean;
  thinkingLevel?: 'low' | 'medium' | 'high';
  /** Override the provider's default model (per user selection). */
  model?: string;
}

/**
 * Common contract every AI provider implements, so the chat/insight services
 * can swap between Gemini, AgentRouter (and future providers) transparently.
 * The Gemini "contents" shape is used as the internal lingua franca; providers
 * translate it to/from their own wire format.
 */
export interface LlmProvider {
  readonly isConfigured: boolean;
  /**
   * Whether the provider can run the SQL function-calling chat loop. Some
   * gateways (AgentRouter's WAF) reject requests containing SQL — for those we
   * fall back to a pre-computed data snapshot instead of the query tool.
   */
  readonly supportsToolChat: boolean;
  generate(
    prompt: string,
    system?: string,
    history?: GeminiContent[],
    opts?: { json?: boolean; maxOutputTokens?: number; model?: string },
  ): Promise<string>;
  generateContent(
    contents: GeminiContent[],
    opts?: GenerateContentOpts,
  ): Promise<{ content: GeminiContent | null; rateLimited: boolean }>;
  generateJson<T>(prompt: string, system?: string, model?: string): Promise<T | null>;
}
