import { ForbiddenException } from '@nestjs/common';
import { AI_CONSENT_VERSION } from '../../common/constants/ai-consent';
import { AiEnabledGuard } from './ai-enabled.guard';

describe('AiEnabledGuard', () => {
  const findUnique = jest.fn();
  const guard = new AiEnabledGuard({
    userSettings: { findUnique },
  } as any);
  const context = {
    switchToHttp: () => ({
      getRequest: () => ({ user: { userId: 'user-1' } }),
    }),
  } as any;

  beforeEach(() => findUnique.mockReset());

  it('allows AI only with enabled current consent', async () => {
    findUnique.mockResolvedValue({
      aiEnabled: true,
      aiConsentAt: new Date(),
      aiConsentVersion: AI_CONSENT_VERSION,
    });

    await expect(guard.canActivate(context)).resolves.toBe(true);
  });

  it.each([
    null,
    { aiEnabled: false, aiConsentAt: null, aiConsentVersion: null },
    { aiEnabled: true, aiConsentAt: null, aiConsentVersion: AI_CONSENT_VERSION },
    { aiEnabled: true, aiConsentAt: new Date(), aiConsentVersion: 'old' },
  ])('rejects disabled or invalid consent state', async (settings) => {
    findUnique.mockResolvedValue(settings);

    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });
});
