import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';

export type EnvironmentConfigField = {
  key: string;
  label: string;
  value: string;
  displayValue: string;
  placeholder?: string;
  secret?: boolean;
  multiline?: boolean;
  description?: string;
  effectiveScope: 'server_runtime' | 'web_runtime';
  envFile: 'server/.env' | 'web/.env.local';
  immediateEffect: boolean;
};

export type EnvironmentConfigSection = {
  id: string;
  title: string;
  description: string;
  fields: EnvironmentConfigField[];
};

export type EnvironmentConfigResponse = {
  sections: EnvironmentConfigSection[];
  summary: {
    saveWritesTo: Array<'server/.env' | 'web/.env.local'>;
    immediateEffect: string[];
    restartRecommended: string[];
  };
};

export type EnvironmentConfigSectionTestResult = {
  sectionId: string;
  ok: boolean;
  checkedAt: string;
  message: string;
  checks: Array<{
    label: string;
    ok: boolean;
    detail: string;
  }>;
};

export const adminEnvironmentApi = {
  async fetchConfig(): Promise<EnvironmentConfigResponse> {
    return authenticatedJsonFetch<EnvironmentConfigResponse>('/api/admin/environment-config');
  },

  async saveConfig(input: {
    values: Record<string, string>;
  }): Promise<EnvironmentConfigResponse> {
    return authenticatedJsonFetch<EnvironmentConfigResponse>('/api/admin/environment-config', {
      method: 'PUT',
      body: JSON.stringify(input),
    });
  },

  async testSection(input: {
    sectionId: string;
    values: Record<string, string>;
  }): Promise<EnvironmentConfigSectionTestResult> {
    return authenticatedJsonFetch<EnvironmentConfigSectionTestResult>('/api/admin/environment-config/test', {
      method: 'POST',
      body: JSON.stringify(input),
    });
  },
};
