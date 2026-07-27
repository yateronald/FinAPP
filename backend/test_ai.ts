import { ConfigService } from '@nestjs/config';
import { GeminiClient } from './src/modules/ai/gemini.client';
import { AgentRouterClient } from './src/modules/ai/agentrouter.client';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.join(__dirname, '.env') });

const configMap: Record<string, any> = {
  'gemini.apiKeys': [
    process.env.GEMINI_API_KEY,
    process.env.GEMINI_API_KEY1,
    process.env.GEMINI_API_KEY2,
    process.env.GEMINI_API_KEY3,
    process.env.GEMINI_API_KEY4,
    process.env.GEMINI_API_KEY5,
  ].filter(Boolean),
  'gemini.model': process.env.GEMINI_MODEL || 'gemini-2.5-flash',
  'agentRouter.apiKey': process.env.AGENTROUTER_API_KEY,
  'agentRouter.baseUrl': process.env.AGENTROUTER_BASE_URL || 'https://agentrouter.org/v1',
  'agentRouter.model': process.env.AGENTROUTER_MODEL || 'claude-3-5-sonnet-20241022',
};

const mockConfigService = {
  get: (key: string) => configMap[key],
} as unknown as ConfigService;

async function runTests() {
  console.log('====================================================');
  console.log('🤖 AI ENDPOINTS & PROVIDER INTEGRATION TEST');
  console.log('====================================================\n');

  // 1. Test Gemini Provider
  console.log('----------------------------------------------------');
  console.log('1. Testing Google Gemini Client (Model: gemini-2.5-flash)...');
  const gemini = new GeminiClient(mockConfigService);

  console.log(`Is Gemini Configured? ${gemini.isConfigured ? 'YES ✅' : 'NO ❌'}`);
  if (gemini.isConfigured) {
    try {
      const prompt = 'Fais-moi un conseil rapide sur la gestion de budget personnel en 2 phrases.';
      console.log(`Sending Prompt to Gemini: "${prompt}"`);
      const response = await gemini.generate(prompt, 'You are a financial advisor.', [], {
        model: 'gemini-2.5-flash',
      });
      console.log('\n🟢 Gemini Response Received:');
      console.log(response);
    } catch (err: any) {
      console.error('🔴 Gemini Error:', err?.message || err);
    }
  }

  // 2. Test AgentRouter Provider
  console.log('\n----------------------------------------------------');
  console.log('2. Testing AgentRouter Client...');
  const agentRouter = new AgentRouterClient(mockConfigService);

  console.log(`Is AgentRouter Configured? ${agentRouter.isConfigured ? 'YES ✅' : 'NO ❌'}`);
  if (agentRouter.isConfigured) {
    const candidateModels = ['claude-3-5-sonnet-20241022', 'gpt-4o-mini', 'gpt-4o', 'claude-3-haiku-20240307', 'deepseek-chat'];
    for (const m of candidateModels) {
      try {
        console.log(`\nTesting AgentRouter Model: "${m}"...`);
        const response = await agentRouter.generate('Give 1 quick saving tip in 1 sentence.', 'You are a financial advisor.', [], {
          model: m,
        });
        if (response && !response.includes('not available')) {
          console.log(`🟢 Model "${m}" SUCCESS:`);
          console.log(response);
          break;
        } else {
          console.log(`🟡 Model "${m}" was unavailable.`);
        }
      } catch (err: any) {
        console.error(`🔴 AgentRouter (${m}) Error:`, err?.message || err);
      }
    }
  }

  // 3. Test Full HTTP API Endpoint with Authentication
  console.log('\n----------------------------------------------------');
  console.log('3. Testing Authenticated NestJS AI Endpoints...');
  try {
    // Register/login test user
    const loginRes = await fetch('http://localhost:4000/api/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'test@finapp.local', password: 'Password123!' }),
    });

    let token = '';
    if (loginRes.ok) {
      const loginData = await loginRes.json();
      token = loginData.data?.accessToken;
    } else {
      // Try register if user doesn't exist
      const regRes = await fetch('http://localhost:4000/api/v1/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'test@finapp.local', password: 'Password123!', name: 'Test User' }),
      });
      if (regRes.ok) {
        const regData = await regRes.json();
        token = regData.data?.accessToken;
      }
    }

    if (token) {
      console.log('🔑 Auth Token acquired successfully!');
      
      // Test AI Ask Endpoint
      console.log('\nTesting POST /api/v1/ai/ask ...');
      const askRes = await fetch('http://localhost:4000/api/v1/ai/ask', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ question: 'Comment réduire mes dépenses mensuelles ?' }),
      });
      
      if (askRes.ok) {
        const askData = await askRes.json();
        console.log('🟢 POST /api/v1/ai/ask SUCCESS:');
        console.log(JSON.stringify(askData.data, null, 2));
      } else {
        const errTxt = await askRes.text();
        console.log(`🔴 /api/v1/ai/ask failed (${askRes.status}):`, errTxt);
      }

      // Test AI Generate Insights Endpoint
      console.log('\nTesting POST /api/v1/ai/insights/generate ...');
      const insRes = await fetch('http://localhost:4000/api/v1/ai/insights/generate?month=7&year=2026', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
      });

      if (insRes.ok) {
        const insData = await insRes.json();
        console.log('🟢 POST /api/v1/ai/insights/generate SUCCESS:');
        console.log(JSON.stringify(insData.data, null, 2));
      } else {
        const errTxt = await insRes.text();
        console.log(`🔴 /api/v1/ai/insights/generate failed (${insRes.status}):`, errTxt);
      }
    } else {
      console.log('🟡 Could not obtain auth token for endpoint testing.');
    }
  } catch (err: any) {
    console.error('🔴 HTTP Endpoint Test Error:', err?.message || err);
  }

  console.log('\n====================================================');
  console.log('✅ TEST COMPLETED');
  console.log('====================================================');
}

runTests();
