import { BadRequestException } from '@nestjs/common';
import { AI_CONSENT_VERSION } from '../../common/constants/ai-consent';
import { SettingsService } from './settings.service';

describe('SettingsService AI consent', () => {
  const findUnique = jest.fn();
  const upsert = jest.fn();
  const log = jest.fn();
  const service = new SettingsService(
    { userSettings: { findUnique, upsert } } as any,
    { log } as any,
  );

  beforeEach(() => {
    findUnique.mockReset();
    findUnique.mockResolvedValue(null);
    upsert.mockReset();
    log.mockReset();
  });

  it('refuses to enable AI without explicit confirmation', async () => {
    await expect(service.update('user-1', { aiEnabled: true })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(upsert).not.toHaveBeenCalled();
  });

  it('records timestamp, version and audit event when enabled', async () => {
    upsert.mockImplementation(({ create }) => Promise.resolve({ id: 'settings-1', ...create }));

    const result = await service.update('user-1', {
      aiEnabled: true,
      aiConsentConfirmed: true,
    });

    expect(result.aiEnabled).toBe(true);
    expect(result.aiConsentAt).toBeInstanceOf(Date);
    expect(result.aiConsentVersion).toBe(AI_CONSENT_VERSION);
    expect(log).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'AI_CONSENT_GRANTED', userId: 'user-1' }),
    );
  });

  it('does not demand consent again when valid AI consent is already active', async () => {
    findUnique.mockResolvedValue({
      aiEnabled: true,
      aiConsentAt: new Date('2026-08-08T12:00:00.000Z'),
      aiConsentVersion: AI_CONSENT_VERSION,
    });
    upsert.mockResolvedValue({ id: 'settings-1', aiEnabled: true });

    await expect(
      service.update('user-1', { aiEnabled: true, language: 'EN' as any }),
    ).resolves.toEqual(expect.objectContaining({ aiEnabled: true }));
    expect(log).not.toHaveBeenCalled();
  });
});
