import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { GoogleGenAI } from '@google/genai';
import type { LlmProvider } from './llm.interface';

export interface GeminiPart {
  text?: string;
  functionCall?: { name: string; args: Record<string, any> };
  functionResponse?: { name: string; response: Record<string, any> };
}

export interface GeminiContent {
  role: 'user' | 'model' | 'function';
  parts: GeminiPart[];
}

export interface FunctionDeclaration {
  name: string;
  description: string;
  parameters: Record<string, any>;
}

/**
 * Thin wrapper around the official @google/genai SDK.
 * Adds: multi-key rotation (exhausted/failed key → next), transient-error retry
 * with backoff, and rate-limit detection — all preserved from the REST version.
 */
@Injectable()
export class GeminiClient implements LlmProvider {
  private readonly logger = new Logger(GeminiClient.name);
  private readonly clients = new Map<string, GoogleGenAI>();

  constructor(private readonly config: ConfigService) {}

  /** Valid, de-duplicated keys in priority order (primary, then fallbacks). */
  private get apiKeys(): string[] {
    const keys = this.config.get<string[]>('gemini.apiKeys') ?? [];
    const seen = new Set<string>();
    const result: string[] = [];
    for (const k of keys) {
      if (!k || k.startsWith('your_') || seen.has(k)) continue;
      // Google AI Studio API keys start with "AIza". Skip OAuth-token values
      // (e.g. "AQ.*") — they can't authenticate as an apiKey and only add
      // latency/failures to the rotation.
      if (!k.startsWith('AIza')) {
        this.logger.warn(`Skipping non-API-key Gemini credential (starts with "${k.slice(0, 3)}…").`);
        continue;
      }
      seen.add(k);
      result.push(k);
    }
    return result;
  }

  get isConfigured(): boolean {
    return this.apiKeys.length > 0;
  }

  readonly supportsToolChat = true;

  private get model(): string {
    return this.config.get<string>('gemini.model') || 'gemini-3.5-flash';
  }

  private clientFor(key: string): GoogleGenAI {
    let client = this.clients.get(key);
    if (!client) {
      client = new GoogleGenAI({ apiKey: key });
      this.clients.set(key, client);
    }
    return client;
  }

  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  private statusOf(err: any): number {
    return Number(err?.status ?? err?.code ?? err?.response?.status ?? 0);
  }
  private isRateLimit(err: any): boolean {
    return this.statusOf(err) === 429 || /RESOURCE_EXHAUSTED|quota|rate.?limit|429/i.test(String(err?.message ?? ''));
  }
  private isTransient(err: any): boolean {
    return (
      [429, 500, 503].includes(this.statusOf(err)) ||
      /RESOURCE_EXHAUSTED|unavailable|overloaded|internal|500|503/i.test(String(err?.message ?? ''))
    );
  }

  /**
   * Core call runner: rotate keys, retry transient errors per key.
   * Returns the SDK response (with `.candidates`) or null.
   */
  private async run(req: {
    contents: any;
    config: Record<string, any>;
    model?: string;
  }): Promise<{ data: any | null; rateLimited: boolean }> {
    const keys = this.apiKeys;
    if (keys.length === 0) return { data: null, rateLimited: false };
    const maxAttemptsPerKey = 2;
    let sawRateLimit = false;

    for (let i = 0; i < keys.length; i++) {
      const client = this.clientFor(keys[i]);
      for (let attempt = 1; attempt <= maxAttemptsPerKey; attempt++) {
        try {
          const response = await client.models.generateContent({
            model: req.model || this.model,
            contents: req.contents,
            config: req.config,
          } as any);
          return { data: response, rateLimited: false };
        } catch (err) {
          const rateLimited = this.isRateLimit(err);
          if (rateLimited) sawRateLimit = true;
          this.logger.error(
            `Gemini error (key #${i + 1}): ${String((err as any)?.message ?? err).slice(0, 200)}`,
          );
          // Only retry transient *overload* errors (500/503). A 429 quota won't
          // clear in a few hundred ms, so move straight to the next key — this
          // keeps the whole call fast enough to beat the client timeout.
          if (this.isTransient(err) && !rateLimited && attempt < maxAttemptsPerKey) {
            await this.delay(300 * attempt);
            continue;
          }
          break; // next key
        }
      }
      if (i < keys.length - 1) {
        this.logger.warn(`Gemini key #${i + 1} failed — falling back to key #${i + 2}.`);
      }
    }
    this.logger.error('All Gemini keys failed.');
    return { data: null, rateLimited: sawRateLimit };
  }

  private extractText(data: any): string {
    const fromParts = data?.candidates?.[0]?.content?.parts
      ?.map((p: GeminiPart) => p.text)
      .filter(Boolean)
      .join('')
      .trim();
    return fromParts || (typeof data?.text === 'string' ? data.text.trim() : '');
  }

  /** Simple text generation with optional history / system / JSON mode. */
  async generate(
    prompt: string,
    system?: string,
    history: GeminiContent[] = [],
    opts: { json?: boolean; maxOutputTokens?: number; model?: string } = {},
  ): Promise<string> {
    if (!this.isConfigured) return this.fallback();
    const contents = [...history, { role: 'user', parts: [{ text: prompt }] }];
    const config: Record<string, any> = {
      temperature: 0.6,
      maxOutputTokens: opts.maxOutputTokens ?? 4096,
    };
    if (opts.json) config.responseMimeType = 'application/json';
    if (system) config.systemInstruction = system;

    const { data } = await this.run({ contents, config, model: opts.model });
    return this.extractText(data) || this.fallback();
  }

  /** Multi-part generation supporting function/tool calling + optional thinking. */
  async generateContent(
    contents: GeminiContent[],
    opts: {
      system?: string;
      tools?: FunctionDeclaration[];
      maxOutputTokens?: number;
      thinking?: boolean;
      thinkingLevel?: 'low' | 'medium' | 'high';
      model?: string;
    } = {},
  ): Promise<{ content: GeminiContent | null; rateLimited: boolean }> {
    if (!this.isConfigured) return { content: null, rateLimited: false };
    const config: Record<string, any> = {
      temperature: 0.4,
      maxOutputTokens: opts.maxOutputTokens ?? 4096,
    };
    if (opts.system) config.systemInstruction = opts.system;
    if (opts.tools?.length) config.tools = [{ functionDeclarations: opts.tools }];
    // Thinking improves multi-step reasoning / tool choice, but the config shape
    // is model-dependent: only Gemini 3.x accepts `thinkingLevel`. Sending it to
    // 2.5/2.0/1.5 models returns 400 "Thinking level is not supported", so we
    // gate it by model family (older models simply run without explicit thinking).
    const effectiveModel = opts.model || this.model;
    if (opts.thinking && /gemini-3/i.test(effectiveModel)) {
      config.thinkingConfig = { thinkingLevel: opts.thinkingLevel ?? 'high' };
    }

    const { data, rateLimited } = await this.run({ contents, config, model: opts.model });
    const content = data?.candidates?.[0]?.content;
    if (!content) return { content: null, rateLimited };
    return { content: { role: 'model', parts: content.parts ?? [] }, rateLimited };
  }

  /** Ask Gemini to return JSON. Robust to prose/fences around the JSON. */
  async generateJson<T>(prompt: string, system?: string, model?: string): Promise<T | null> {
    const raw = await this.generate(prompt, system, [], { json: true, maxOutputTokens: 8192, model });
    const cleaned = raw.replace(/```json/gi, '').replace(/```/g, '').trim();
    const candidates = [cleaned];
    const fa = cleaned.indexOf('[');
    const la = cleaned.lastIndexOf(']');
    if (fa !== -1 && la > fa) candidates.push(cleaned.slice(fa, la + 1));
    const fo = cleaned.indexOf('{');
    const lo = cleaned.lastIndexOf('}');
    if (fo !== -1 && lo > fo) candidates.push(cleaned.slice(fo, lo + 1));
    for (const c of candidates) {
      try {
        return JSON.parse(c) as T;
      } catch {
        /* try next */
      }
    }
    return null;
  }

  private fallback(): string {
    return 'AI insights are not available right now. Please make sure the Gemini API key is configured.';
  }
}
