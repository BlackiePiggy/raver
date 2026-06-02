import fs from 'node:fs';
import path from 'node:path';

import {
  EventAdminContractGuardrailError,
  validateEventAdminContractPayload,
} from '../services/event-admin-contract-guardrail.service';

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const expectGuardrailError = (label: string, run: () => void): void => {
  try {
    run();
  } catch (error) {
    if (error instanceof EventAdminContractGuardrailError) {
      return;
    }
    throw error;
  }
  throw new Error(`${label}: expected EventAdminContractGuardrailError`);
};

const fixtureDir = path.resolve(__dirname, '../../../contracts/fixtures/event/golden');

const loadFixture = (name: string): Record<string, unknown> =>
  JSON.parse(fs.readFileSync(path.join(fixtureDir, name), 'utf8')) as Record<string, unknown>;

const baseUpdatePayload = loadFixture('update-clear-location.json');

const validateGoldenFixtures = (): void => {
  const names = fs.readdirSync(fixtureDir).filter((name) => name.endsWith('.json')).sort();
  assert(names.length === 6, 'unexpected golden event fixture count');

  names.forEach((name) => {
    const payload = loadFixture(name);
    const mode = name.startsWith('create-') ? 'create' : 'update';
    const validated = validateEventAdminContractPayload(payload, mode);
    assert(typeof validated.name === 'string' && validated.name.length > 0, `${name} should validate`);
  });
};

const main = (): void => {
  validateGoldenFixtures();

  expectGuardrailError('update should reject missing schedule', () => {
    const payload = { ...baseUpdatePayload };
    delete (payload as Partial<typeof payload>).schedule;
    validateEventAdminContractPayload(payload, 'update');
  });

  expectGuardrailError('update should reject missing clear flag', () => {
    const payload = { ...baseUpdatePayload };
    delete (payload as Partial<typeof payload>).clearManualLocation;
    validateEventAdminContractPayload(payload, 'update');
  });

  expectGuardrailError('update should reject partial patch omission for locationPoint', () => {
    const payload: Record<string, unknown> = {
      ...baseUpdatePayload,
      clearLocationPoint: false,
    };
    delete payload.locationPoint;
    validateEventAdminContractPayload(payload, 'update');
  });

  expectGuardrailError('update should reject partial patch omission for socialLinks', () => {
    const payload: Record<string, unknown> = {
      ...baseUpdatePayload,
      clearSocialLinks: false,
    };
    delete payload.socialLinks;
    validateEventAdminContractPayload(payload, 'update');
  });

  expectGuardrailError('update should reject clear/socialLinks conflict', () => {
    validateEventAdminContractPayload(
      {
        ...baseUpdatePayload,
        clearSocialLinks: true,
        socialLinks: [{ type: 'instagram', url: 'https://instagram.com/future-rave' }],
      },
      'update'
    );
  });

  expectGuardrailError('update should reject clear/manualLocation conflict', () => {
    validateEventAdminContractPayload(
      {
        ...baseUpdatePayload,
        clearManualLocation: true,
        manualLocation: {
          detailAddressI18n: { en: '88 Xuhui', zh: 'Xuhui 88' },
          formattedAddressI18n: { en: 'China · Shanghai · 88 Xuhui', zh: 'China · Shanghai · 88 Xuhui' },
          selectedAt: '2099-12-01T12:00:00.000Z',
        },
      },
      'update'
    );
  });

  console.log('[event-admin-contract-guardrails] ok');
};

main();
