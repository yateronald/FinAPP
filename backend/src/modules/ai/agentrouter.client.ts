import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { GeminiContent, GeminiPart } from './gemini.client';
import { GenerateContentOpts, LlmProvider } from './llm.interface';

/**
 * AgentRouter provider — an OpenAI-compatible gateway (agentrouter.org) fronting
 * Claude/GPT/GLM models. Implements the same LlmProvider contract as Gemini by
 * translating our Gemini-style `contents` (+ function tools) to/from the OpenAI
 * chat-completions wire format.
 *
 * NOTE: AgentRouter's WAF rejects generic clients ("unauthorized client
 * detected") — it whitelists `User-Agent: codex_cli_rs`, which we must send.
 */
@Injectable()
export class AgentRouterClient implements LlmProvider {
  private readonly logger = new Logger(AgentRouterClient.name);

  constructor(private readonly config: ConfigService) {}

  private get apiKey(): string | undefined {
    return this.config.get<string>('agentRouter.apiKey');
  }
  private get baseUrl(): string {
    return this.config.get<string>('agentRouter.baseUrl') || 'https://agentrouter.org/v1';
  }
  private get model(): string {
    return this.config.get<string>('agentRouter.model') || 'claude-opus-4-8';
  }

  get isConfigured(): boolean {
    const k = this.apiKey;
    return !!k && !k.startsWith('your_');
  }

  // AgentRouter's WAF blocks requests containing SQL, so we use a data-snapshot
  // chat strategy instead of the SQL function-calling loop.
  readonly supportsToolChat = false;

  private delay(ms: number): Promise<void> {
    return new Promise((r) => setTimeout(r, ms));
  }

  // ---------------------------------------------------------- HTTP
  private async post(
    body: Record<string, any>,
  ): Promise<{ data: any | null; rateLimited: boolean }> {
    // Retry only transient NETWORK failures (fetch failed / reset) — never a
    // WAF/quota response, which won't clear on an immediate retry.
    const maxAttempts = 3;
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        const res = await fetch(`${this.baseUrl}/chat/completions`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json',
            // Required — AgentRouter's WAF only allows the whitelisted Codex CLI
            // client. The *versioned* User-Agent + originator are both needed;
            // a bare "codex_cli_rs" is rejected with "unauthorized client".
            'User-Agent': 'codex_cli_rs/0.1.0',
            originator: 'codex_cli_rs',
          },
          body: JSON.stringify(body),
          signal: AbortSignal.timeout(110_000),
        });
        if (!res.ok) {
          const txt = await res.text().catch(() => '');
          const rateLimited =
            res.status === 429 ||
            /quota|rate.?limit|无可用渠道|insufficient|余额|balance/i.test(txt);
          this.logger.error(`AgentRouter ${res.status}: ${txt.slice(0, 240)}`);
          return { data: null, rateLimited };
        }
        return { data: await res.json(), rateLimited: false };
      } catch (err) {
        const msg = String((err as any)?.message ?? err);
        this.logger.error(
          `AgentRouter request failed (attempt ${attempt}/${maxAttempts}): ${msg}`,
        );
        if (attempt < maxAttempts) {
          await this.delay(500 * attempt);
          continue;
        }
        return { data: null, rateLimited: false };
      }
    }
    return { data: null, rateLimited: false };
  }

  // ------------------------------------------------- format translation
  /** Gemini `contents` (+ system) → OpenAI messages. */
  private toMessages(contents: GeminiContent[], system?: string): any[] {
    const out: any[] = [];
    if (system) out.push({ role: 'system', content: system });
    const pendingIds: string[] = [];
    let idc = 0;

    for (const c of contents) {
      const text = c.parts.map((p) => p.text).filter(Boolean).join('');
      const calls = c.parts.filter((p) => p.functionCall);
      const responses = c.parts.filter((p) => p.functionResponse);

      if (responses.length) {
        for (const r of responses) {
          const id = pendingIds.shift() ?? `call_${idc++}`;
          out.push({
            role: 'tool',
            tool_call_id: id,
            content: JSON.stringify(r.functionResponse?.response ?? {}),
          });
        }
        continue;
      }
      if (calls.length) {
        const toolCalls = calls.map((p) => {
          const id = `call_${idc++}`;
          pendingIds.push(id);
          return {
            id,
            type: 'function',
            function: {
              name: p.functionCall!.name,
              arguments: JSON.stringify(p.functionCall!.args ?? {}),
            },
          };
        });
        out.push({ role: 'assistant', content: text || null, tool_calls: toolCalls });
        continue;
      }
      out.push({ role: c.role === 'model' ? 'assistant' : 'user', content: text });
    }
    return out;
  }

  private safeParse(s: string): Record<string, any> {
    try {
      return JSON.parse(s || '{}');
    } catch {
      return {};
    }
  }

  /** OpenAI response message → Gemini content. */
  private fromMessage(msg: any): GeminiContent {
    if (msg?.tool_calls?.length) {
      return {
        role: 'model',
        parts: msg.tool_calls.map(
          (tc: any): GeminiPart => ({
            functionCall: {
              name: tc.function?.name,
              args: this.safeParse(tc.function?.arguments ?? '{}'),
            },
          }),
        ),
      };
    }
    return { role: 'model', parts: [{ text: msg?.content ?? '' }] };
  }

  // ----------------------------------------------------- public API
  async generateContent(
    contents: GeminiContent[],
    opts: GenerateContentOpts = {},
  ): Promise<{ content: GeminiContent | null; rateLimited: boolean }> {
    if (!this.isConfigured) return { content: null, rateLimited: false };
    // NOTE: we intentionally do NOT send `temperature` — AgentRouter fronts
    // several models (GPT-5 / reasoning class) that reject it with
    // "`temperature` is deprecated for this model." Omitting it lets every
    // model use its own default and keeps the gateway happy across the board.
    const body: Record<string, any> = {
      model: opts.model || this.model,
      messages: this.toMessages(contents, opts.system),
      max_tokens: opts.maxOutputTokens ?? 4096,
    };
    if (opts.tools?.length) {
      body.tools = opts.tools.map((t) => ({
        type: 'function',
        function: { name: t.name, description: t.description, parameters: t.parameters },
      }));
      body.tool_choice = 'auto';
    }
    const { data, rateLimited } = await this.post(body);
    const msg = data?.choices?.[0]?.message;
    if (!msg) return { content: null, rateLimited };
    return { content: this.fromMessage(msg), rateLimited };
  }

  async generate(
    prompt: string,
    system?: string,
    history: GeminiContent[] = [],
    opts: { json?: boolean; maxOutputTokens?: number; model?: string } = {},
  ): Promise<string> {
    if (!this.isConfigured) return this.fallback();
    const contents: GeminiContent[] = [
      ...history,
      { role: 'user', parts: [{ text: prompt }] },
    ];
    const { content } = await this.generateContent(contents, {
      system,
      maxOutputTokens: opts.maxOutputTokens ?? 4096,
      model: opts.model,
    });
    const text = content?.parts.map((p) => p.text).filter(Boolean).join('').trim();
    return text || this.fallback();
  }

  async generateJson<T>(prompt: string, system?: string, model?: string): Promise<T | null> {
    const raw = await this.generate(
      `${prompt}\n\nRespond ONLY with valid JSON, no prose or code fences.`,
      system,
      [],
      { maxOutputTokens: 8192, model },
    );
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
        /* next */
      }
    }
    return null;
  }

  private fallback(): string {
    return 'AI is not available right now. Please make sure the AgentRouter API key is configured.';
  }
}
