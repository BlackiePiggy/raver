import React, { useState, useEffect } from 'react';
import { Router, Route, Switch, useLocation } from './router';
import { motion, AnimatePresence } from 'motion/react';
import { Hero } from './components/Hero';
import { About } from './components/About';
import { Services } from './components/Services';
import { FigmaCommunitySection } from './components/FigmaCommunitySection';
import { Download } from './components/Download';
import { Footer } from './components/Footer';
import { Navbar } from './components/Navbar';
import { Work } from './components/Work';
import { ProjectDetail } from './components/ProjectDetail';
import { ScrollIndicator } from './components/ScrollIndicator';
import { ResourceAdmin } from './components/ResourceAdmin';
import { comingSoonEvent } from './utils/comingSoon';

const pageSectionIds = ['hero', 'services', 'community', 'about', 'download', 'contact'];

const FullPageScrollController = () => {
  const [pathname] = useLocation();
  const [isTransitioning, setIsTransitioning] = useState(false);

  useEffect(() => {
    if (pathname !== '/') {
      return;
    }

    const desktopViewport = window.matchMedia('(min-width: 768px)');
    if (!desktopViewport.matches) {
      return;
    }

    let isJumping = false;
    let lastJumpAt = 0;
    let gestureLocked = false;
    let wheelGestureConsumed = false;
    let touchConsumedInternalScroll = false;
    let gestureUnlockTimer: ReturnType<typeof window.setTimeout> | undefined;
    let wheelGestureUnlockTimer: ReturnType<typeof window.setTimeout> | undefined;
    let touchStartX: number | null = null;
    let touchStartY: number | null = null;
    let touchLastX: number | null = null;
    let touchLastY: number | null = null;

    const scheduleGestureUnlock = () => {
      if (gestureUnlockTimer) {
        window.clearTimeout(gestureUnlockTimer);
      }

      gestureUnlockTimer = window.setTimeout(() => {
        gestureLocked = false;
      }, 320);
    };

    const lockCurrentGesture = () => {
      gestureLocked = true;
      scheduleGestureUnlock();
    };

    const scheduleWheelGestureUnlock = () => {
      if (wheelGestureUnlockTimer) {
        window.clearTimeout(wheelGestureUnlockTimer);
      }

      wheelGestureUnlockTimer = window.setTimeout(() => {
        wheelGestureConsumed = false;
      }, 160);
    };

    const getCurrentSectionIndex = () => {
      const viewportCenter = window.scrollY + window.innerHeight / 2;

      return pageSectionIds.reduce((activeIndex, id, index) => {
        const section = document.getElementById(id);

        if (!section) {
          return activeIndex;
        }

        return section.offsetTop <= viewportCenter ? index : activeIndex;
      }, 0);
    };

    const canScrollSectionInternally = (section: HTMLElement | null, direction: number) => {
      if (!section?.matches('[data-section-scroll="true"]')) {
        return false;
      }

      const maxScrollTop = section.scrollHeight - section.clientHeight;
      if (maxScrollTop <= 2) {
        return false;
      }

      if (direction > 0) {
        return section.scrollTop < maxScrollTop - 2;
      }

      return section.scrollTop > 2;
    };

    const scrollSectionInternally = (section: HTMLElement, deltaY: number) => {
      const maxScrollTop = section.scrollHeight - section.clientHeight;
      const nextScrollTop = Math.max(0, Math.min(maxScrollTop, section.scrollTop + deltaY));
      section.scrollTop = nextScrollTop;
    };

    const setSectionEntryPosition = (section: HTMLElement, direction: number) => {
      if (!section.matches('[data-section-scroll="true"]')) {
        return;
      }

      const maxScrollTop = section.scrollHeight - section.clientHeight;
      section.scrollTop = direction < 0 ? Math.max(0, maxScrollTop) : 0;
    };

    const jumpToSection = (index: number, direction: number) => {
      const nextIndex = Math.max(0, Math.min(pageSectionIds.length - 1, index));
      const section = document.getElementById(pageSectionIds[nextIndex]);

      if (!section) {
        return;
      }

      if (Math.abs(window.scrollY - section.offsetTop) < 2) {
        return;
      }

      isJumping = true;
      lockCurrentGesture();
      setIsTransitioning(true);

      window.setTimeout(() => {
        section.scrollIntoView({ behavior: 'auto', block: 'start' });
        setSectionEntryPosition(section, direction);

        window.setTimeout(() => {
          setIsTransitioning(false);

          window.setTimeout(() => {
            isJumping = false;
          }, 260);
        }, 170);
      }, 220);
    };

    const processVerticalIntent = (deltaY: number, source: 'wheel' | 'keyboard' | 'touch' = 'wheel') => {
      if (gestureLocked) {
        return 'locked';
      }

      if (isJumping) {
        return 'jumping';
      }

      const currentIndex = getCurrentSectionIndex();
      const currentSection = document.getElementById(pageSectionIds[currentIndex]);
      const direction = deltaY > 0 ? 1 : -1;

      const internalEvent = new CustomEvent('ravehub:section-wheel', {
        bubbles: true,
        cancelable: true,
        detail: {
          deltaY,
          direction,
          sectionId: pageSectionIds[currentIndex],
        },
      });

      currentSection?.dispatchEvent(internalEvent);

      if (internalEvent.defaultPrevented) {
        return 'section';
      }

      if (canScrollSectionInternally(currentSection, direction)) {
        scrollSectionInternally(currentSection as HTMLElement, deltaY);
        return 'internal';
      }

      if (source === 'touch' && touchConsumedInternalScroll) {
        return 'boundary';
      }

      const now = Date.now();
      if (now - lastJumpAt < 360) {
        return 'cooldown';
      }
      lastJumpAt = now;

      jumpToSection(currentIndex + direction, direction);
      return 'jump';
    };

    const handleWheel = (event: WheelEvent) => {
      const target = event.target as HTMLElement | null;

      if (target?.closest('[data-native-scroll="true"], input, textarea, select, [contenteditable="true"]')) {
        return;
      }

      event.preventDefault();

      if (wheelGestureConsumed) {
        scheduleWheelGestureUnlock();
        return;
      }

      const result = processVerticalIntent(event.deltaY, 'wheel');
      if (['jump', 'jumping', 'locked', 'cooldown'].includes(result)) {
        wheelGestureConsumed = true;
        scheduleWheelGestureUnlock();
      }
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (!['ArrowDown', 'PageDown', ' ', 'ArrowUp', 'PageUp'].includes(event.key)) {
        return;
      }

      if (event.repeat || gestureLocked) {
        event.preventDefault();
        return;
      }

      const target = event.target as HTMLElement | null;
      if (target?.closest('[data-native-scroll="true"], input, textarea, select, [contenteditable="true"]')) {
        return;
      }

      const direction = event.key === 'ArrowUp' || event.key === 'PageUp' ? -1 : 1;
      event.preventDefault();

      processVerticalIntent(direction * 120, 'keyboard');
    };

    const handleTouchStart = (event: TouchEvent) => {
      const target = event.target as HTMLElement | null;
      if (target?.closest('[data-native-scroll="true"], input, textarea, select, [contenteditable="true"]')) {
        touchStartX = null;
        touchStartY = null;
        touchLastX = null;
        touchLastY = null;
        return;
      }

      const x = event.touches[0]?.clientX ?? null;
      const y = event.touches[0]?.clientY ?? null;
      touchStartX = x;
      touchStartY = y;
      touchLastX = x;
      touchLastY = y;
    };

    const handleTouchMove = (event: TouchEvent) => {
      const target = event.target as HTMLElement | null;
      if (target?.closest('[data-native-scroll="true"], input, textarea, select, [contenteditable="true"]')) {
        return;
      }

      if (touchLastY === null || touchLastX === null) {
        touchLastX = event.touches[0]?.clientX ?? null;
        touchLastY = event.touches[0]?.clientY ?? null;
        return;
      }

      const currentX = event.touches[0]?.clientX ?? touchLastX;
      const currentY = event.touches[0]?.clientY ?? touchLastY;
      const deltaX = touchLastX - currentX;
      const deltaY = touchLastY - currentY;
      const totalX = touchStartX === null ? deltaX : touchStartX - currentX;
      const totalY = touchStartY === null ? deltaY : touchStartY - currentY;

      if (Math.abs(totalX) > 10 && Math.abs(totalX) > Math.abs(totalY) + 8) {
        touchLastX = currentX;
        touchLastY = currentY;
        return;
      }

      if (Math.abs(deltaY) < 2) {
        return;
      }

      event.preventDefault();
      const result = processVerticalIntent(deltaY, 'touch');
      if (result === 'internal') {
        touchConsumedInternalScroll = true;
      }
      touchLastX = currentX;
      touchLastY = currentY;
    };

    const handleTouchEnd = () => {
      touchStartX = null;
      touchStartY = null;
      touchLastX = null;
      touchLastY = null;
      touchConsumedInternalScroll = false;
      scheduleGestureUnlock();
    };

    window.addEventListener('wheel', handleWheel, { passive: false });
    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('touchstart', handleTouchStart, { passive: false });
    window.addEventListener('touchmove', handleTouchMove, { passive: false });
    window.addEventListener('touchend', handleTouchEnd);

    return () => {
      if (gestureUnlockTimer) {
        window.clearTimeout(gestureUnlockTimer);
      }
      if (wheelGestureUnlockTimer) {
        window.clearTimeout(wheelGestureUnlockTimer);
      }

      window.removeEventListener('wheel', handleWheel);
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('touchstart', handleTouchStart);
      window.removeEventListener('touchmove', handleTouchMove);
      window.removeEventListener('touchend', handleTouchEnd);
    };
  }, [pathname]);

  return (
    <AnimatePresence>
      {isTransitioning && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.24, ease: 'easeInOut' }}
          className="fixed inset-0 z-[90] pointer-events-none bg-black"
        >
          <motion.div
            initial={{ opacity: 0, scale: 0.96 }}
            animate={{ opacity: 0.42, scale: 1 }}
            exit={{ opacity: 0, scale: 1.04 }}
            transition={{ duration: 0.36, ease: [0.22, 1, 0.36, 1] }}
            className="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(118,255,85,0.18),transparent_34%),radial-gradient(circle_at_20%_80%,rgba(155,92,255,0.16),transparent_34%)] blur-2xl"
          />
        </motion.div>
      )}
    </AnimatePresence>
  );
};

// Preloader Component
const Preloader = () => (
  <motion.div
    initial={{ opacity: 0 }}
    animate={{ opacity: 1 }}
    exit={{ opacity: 0, transition: { duration: 0.8, ease: "easeInOut" } }}
    className="fixed inset-0 z-[999] bg-white flex items-center justify-center text-black"
  >
    <motion.div
      initial={{ opacity: 0, scale: 0.8, filter: "blur(10px)" }}
      animate={{ opacity: 1, scale: 1, filter: "blur(0px)" }}
      transition={{ duration: 1, ease: [0.22, 1, 0.36, 1] }}
      className="flex flex-col items-center gap-4"
    >
      <h1 className="text-4xl md:text-6xl font-bold tracking-tighter">
        Ravehub
      </h1>
      <motion.div 
        initial={{ width: 0 }}
        animate={{ width: "100%" }}
        transition={{ delay: 0.5, duration: 1.5, ease: "easeInOut" }}
        className="h-px bg-black/20 w-32"
      />
    </motion.div>
  </motion.div>
);

// Enhanced ScrollToTop to handle both routes and hash anchors
const ScrollToTop = () => {
  const [pathname] = useLocation();

  useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);

  return null;
};

const getOrCreateVisitorId = () => {
  const storageKey = 'ravehub_visitor_id';
  const visitorId = window.crypto?.randomUUID?.() || `${Date.now()}-${Math.random().toString(36).slice(2)}`;

  try {
    const existing = window.localStorage.getItem(storageKey);
    if (existing) {
      return existing;
    }

    window.localStorage.setItem(storageKey, visitorId);
  } catch {
    return visitorId;
  }

  return visitorId;
};

const VisitorTracker = () => {
  const [pathname] = useLocation();

  useEffect(() => {
    const payload = {
      visitorId: getOrCreateVisitorId(),
      path: `${pathname}${window.location.hash || ''}`,
      referrer: document.referrer || null,
      language: navigator.language || null,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || null,
      screen: {
        width: window.screen.width,
        height: window.screen.height,
        viewportWidth: window.innerWidth,
        viewportHeight: window.innerHeight,
        devicePixelRatio: window.devicePixelRatio,
      },
    };
    const body = JSON.stringify(payload);

    if (navigator.sendBeacon) {
      const blob = new Blob([body], { type: 'application/json' });
      navigator.sendBeacon('/api/analytics/visit', blob);
      return;
    }

    fetch('/api/analytics/visit', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
      keepalive: true,
    }).catch(() => {
      // Analytics must never interrupt the public site.
    });
  }, [pathname]);

  return null;
};

const HomePage = () => (
  <>
    <Hero />
    <Services />
    <FigmaCommunitySection />
    <About />
    <Download />
    <Footer />
  </>
);

const ComingSoonToast = () => {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    let timer: ReturnType<typeof window.setTimeout> | undefined;

    const handleComingSoon = () => {
      setVisible(true);
      if (timer) {
        window.clearTimeout(timer);
      }
      timer = window.setTimeout(() => setVisible(false), 1800);
    };

    window.addEventListener(comingSoonEvent, handleComingSoon);

    return () => {
      if (timer) {
        window.clearTimeout(timer);
      }
      window.removeEventListener(comingSoonEvent, handleComingSoon);
    };
  }, []);

  return (
    <AnimatePresence>
      {visible && (
        <motion.div
          initial={{ opacity: 0, y: -16, scale: 0.96 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: -12, scale: 0.98 }}
          transition={{ duration: 0.22, ease: [0.22, 1, 0.36, 1] }}
          className="fixed left-1/2 top-24 z-[150] -translate-x-1/2 rounded-full border border-white/12 bg-white px-5 py-2.5 text-sm font-medium text-black shadow-2xl shadow-black/30"
          role="status"
          aria-live="polite"
        >
          敬请期待
        </motion.div>
      )}
    </AnimatePresence>
  );
};

const AppContent = () => {
  const [pathname] = useLocation();
  const isAdminRoute = pathname.startsWith('/admin');
  const [loading, setLoading] = useState(() => !window.location.pathname.startsWith('/admin'));

  useEffect(() => {
    if (isAdminRoute) {
      setLoading(false);
      return;
    }

    // Intro animation duration
    const timer = setTimeout(() => {
      setLoading(false);
    }, 2000);
    return () => clearTimeout(timer);
  }, [isAdminRoute]);

  return (
    <>
      <ScrollToTop />
      <VisitorTracker />

      <AnimatePresence mode="wait">
        {loading && <Preloader key="preloader" />}
      </AnimatePresence>

      {!loading && (
        <div className="ravehub-snap-page bg-neutral-950 min-h-screen text-white selection:bg-white/20">
          {!isAdminRoute && <FullPageScrollController />}
          {!isAdminRoute && <Navbar />}
          <Switch>
            <Route path="/admin/resources" component={ResourceAdmin} />
            <Route path="/work/:slug" component={ProjectDetail} />
            <Route path="/work" component={Work} />
            <Route path="/" component={HomePage} />
          </Switch>
          {!isAdminRoute && <ScrollIndicator />}
          {!isAdminRoute && <ComingSoonToast />}
        </div>
      )}
    </>
  );
};

function App() {
  return (
    <Router>
      <AppContent />
    </Router>
  );
}

export default App;
