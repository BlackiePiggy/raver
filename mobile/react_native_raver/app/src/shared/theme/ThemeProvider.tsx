import React, { createContext, PropsWithChildren, useContext, useMemo } from 'react';
import { ColorSchemeName } from 'react-native';

import { darkTheme, lightTheme, RaverTheme } from './tokens';

const ThemeContext = createContext<RaverTheme>(lightTheme);

type ThemeProviderProps = PropsWithChildren<{
  colorScheme: ColorSchemeName;
}>;

export function ThemeProvider({
  children,
  colorScheme,
}: ThemeProviderProps): React.JSX.Element {
  const theme = useMemo(
    () => (colorScheme === 'dark' ? darkTheme : lightTheme),
    [colorScheme],
  );

  return <ThemeContext.Provider value={theme}>{children}</ThemeContext.Provider>;
}

export function useTheme(): RaverTheme {
  return useContext(ThemeContext);
}
