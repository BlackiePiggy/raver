export const comingSoonEvent = 'ravehub:coming-soon';

export const showComingSoon = (event?: { preventDefault?: () => void }) => {
  event?.preventDefault?.();
  window.dispatchEvent(new CustomEvent(comingSoonEvent));
};
