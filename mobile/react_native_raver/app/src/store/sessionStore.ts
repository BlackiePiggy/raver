import { create } from 'zustand';

type SessionState = {
  isBootstrapping: boolean;
  isLoggedIn: boolean;
  currentUserId: string | null;
  finishBootstrapping: () => void;
  setLoggedIn: (userId: string) => void;
  clearSession: () => void;
};

export const useSessionStore = create<SessionState>(set => ({
  isBootstrapping: false,
  isLoggedIn: false,
  currentUserId: null,
  finishBootstrapping: () => set({ isBootstrapping: false }),
  setLoggedIn: userId =>
    set({
      currentUserId: userId,
      isBootstrapping: false,
      isLoggedIn: true,
    }),
  clearSession: () =>
    set({
      currentUserId: null,
      isBootstrapping: false,
      isLoggedIn: false,
    }),
}));
