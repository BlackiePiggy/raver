import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

import { BootstrapScreen } from '../shared/screens/BootstrapScreen';
import { useSessionStore } from '../store/sessionStore';
import { RootStackParamList } from './routeTypes';

const RootStack = createNativeStackNavigator<RootStackParamList>();

export function RootNavigator(): React.JSX.Element {
  const isLoggedIn = useSessionStore(state => state.isLoggedIn);

  return (
    <NavigationContainer>
      <RootStack.Navigator screenOptions={{ headerShown: false }}>
        <RootStack.Screen
          name={isLoggedIn ? 'Main' : 'Auth'}
          component={BootstrapScreen}
        />
      </RootStack.Navigator>
    </NavigationContainer>
  );
}
