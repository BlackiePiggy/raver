import React from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { appEnv } from '../../app/config/env';
import { useTheme } from '../theme/ThemeProvider';

export function BootstrapScreen(): React.JSX.Element {
  const theme = useTheme();

  return (
    <View style={[styles.container, { backgroundColor: theme.colors.background }]}>
      <Text style={[styles.title, { color: theme.colors.textPrimary }]}>
        Raver RN
      </Text>
      <Text style={[styles.subtitle, { color: theme.colors.textSecondary }]}>
        {appEnv.runtimeMode} · {appEnv.bffBaseURL}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    flex: 1,
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  subtitle: {
    fontSize: 14,
    marginTop: 8,
  },
  title: {
    fontSize: 32,
    fontWeight: '700',
  },
});
