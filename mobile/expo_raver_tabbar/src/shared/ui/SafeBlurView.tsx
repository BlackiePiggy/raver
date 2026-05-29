import { BlurView } from 'expo-blur';
import React from 'react';
import {
  Platform,
  type StyleProp,
  View,
  type ViewProps,
  type ViewStyle,
} from 'react-native';

type SafeBlurViewProps = ViewProps & {
  intensity?: number;
  tint?: 'light' | 'dark' | 'default' | 'systemChromeMaterial';
  style?: StyleProp<ViewStyle>;
};

export function SafeBlurView({
  children,
  intensity = 20,
  tint = 'default',
  style,
  ...rest
}: SafeBlurViewProps) {
  if (Platform.OS === 'android') {
    return (
      <View style={style} {...rest}>
        {children}
      </View>
    );
  }

  return (
    <BlurView intensity={intensity} tint={tint} style={style} {...rest}>
      {children}
    </BlurView>
  );
}
