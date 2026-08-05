import { AiProvider } from '@prisma/client';

export interface AiModelOption {
  id: string;
  label: string;
}

/**
 * The models a user may pick per provider. IDs must match what the provider's
 * API expects (Gemini model names / AgentRouter model ids).
 *  - Gemini ids verified via the ListModels API (generateContent-capable).
 *  - AgentRouter ids are the ones available on our key.
 */
export const AI_MODELS: Record<AiProvider, AiModelOption[]> = {
  GEMINI: [
    { id: 'gemini-3.6-flash', label: 'Gemini 3.6 Flash' },
    { id: 'gemini-3.5-flash', label: 'Gemini 3.5 Flash' },
    { id: 'gemini-3.1-pro-preview', label: 'Gemini 3.1 Pro' },
    { id: 'gemini-3-flash-preview', label: 'Gemini 3 Flash' },
    { id: 'gemini-3-pro-preview', label: 'Gemini 3 Pro' },
  ],
  // Only what the AgentRouter account actually provisions. Offering a model
  // that is not on the key produced a 503 "无可用渠道" (no available channel),
  // which reached the user as an unexplained failure.
  AGENTROUTER: [
    { id: 'gpt-5.6-sol', label: 'GPT-5.6' },
    { id: 'claude-opus-5', label: 'Claude Opus 5' },
    { id: 'claude-opus-4-8', label: 'Claude Opus 4.8' },
  ],
};

export const DEFAULT_MODEL: Record<AiProvider, string> = {
  GEMINI: 'gemini-3.5-flash',
  // GPT-5.6 answers most reliably on this key; the Claude models hit
  // AgentRouter's shared token ceiling far more often.
  AGENTROUTER: 'gpt-5.6-sol',
};


export const GEMINI_MODEL_IDS = AI_MODELS.GEMINI.map((m) => m.id);
export const AGENTROUTER_MODEL_IDS = AI_MODELS.AGENTROUTER.map((m) => m.id);

/** Return the id if it is a valid choice for the provider, else the default. */
export function resolveModel(provider: AiProvider, id?: string | null): string {
  const ok = AI_MODELS[provider]?.some((m) => m.id === id);
  return ok ? (id as string) : DEFAULT_MODEL[provider];
}
