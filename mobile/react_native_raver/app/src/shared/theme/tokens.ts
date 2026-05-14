export type RaverTheme = {
  colors: {
    background: string;
    surface: string;
    textPrimary: string;
    textSecondary: string;
    accent: string;
    border: string;
  };
  spacing: {
    xs: number;
    sm: number;
    md: number;
    lg: number;
    xl: number;
  };
  radius: {
    sm: number;
    md: number;
    lg: number;
  };
};

const sharedTokens = {
  spacing: {
    xs: 4,
    sm: 8,
    md: 12,
    lg: 16,
    xl: 24,
  },
  radius: {
    sm: 4,
    md: 8,
    lg: 12,
  },
};

export const lightTheme: RaverTheme = {
  ...sharedTokens,
  colors: {
    background: '#F6F7FB',
    surface: '#FFFFFF',
    textPrimary: '#111318',
    textSecondary: '#5D6472',
    accent: '#E94B6A',
    border: '#E1E4EA',
  },
};

export const darkTheme: RaverTheme = {
  ...sharedTokens,
  colors: {
    background: '#070A0F',
    surface: '#111722',
    textPrimary: '#F6F7FB',
    textSecondary: '#AAB2C0',
    accent: '#FF5B7D',
    border: '#273142',
  },
};
