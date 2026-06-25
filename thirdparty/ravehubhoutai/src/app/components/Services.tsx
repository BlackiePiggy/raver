import React, { useEffect, useRef, useState } from 'react';
import { motion, AnimatePresence, type PanInfo } from 'motion/react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { media } from '../data/media';
import {
  capabilitiesChangedEvent,
  loadCapabilities,
  type Capability,
} from '../data/capabilities';

const shouldPreloadNeighbor = (index: number, current: number) => Math.abs(index - current) === 1;

const VideoLoadingOverlay = () => (
  <div className="pointer-events-none absolute inset-0 z-10 flex flex-col items-center justify-center gap-3 bg-black/55 text-white backdrop-blur-[2px]">
    <div className="h-8 w-8 rounded-full border-2 border-white/25 border-t-white animate-spin" />
    <span className="text-[0.65rem] font-mono uppercase tracking-[0.22em] text-white/80">视频加载中</span>
  </div>
);

const SmartPhoneVideo = ({
  src,
  active,
}: {
  src: string;
  active: boolean;
}) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;

    setLoading(video.readyState < HTMLMediaElement.HAVE_CURRENT_DATA);

    if (!active) {
      video.pause();
      return;
    }

    const playPromise = video.play();
    playPromise?.catch(() => {
      // Autoplay can still be blocked in unusual browser states. The poster/first frame remains visible.
    });
  }, [active, src]);

  return (
    <>
      <video
        ref={videoRef}
        src={src}
        autoPlay={active}
        loop
        muted
        playsInline
        preload={active ? 'auto' : 'metadata'}
        onLoadStart={() => setLoading(true)}
        onWaiting={() => setLoading(true)}
        onStalled={() => setLoading(true)}
        onCanPlay={() => setLoading(false)}
        onLoadedData={() => setLoading(false)}
        onPlaying={() => setLoading(false)}
        className="absolute inset-0 h-full w-full object-cover"
      />
      {loading && <VideoLoadingOverlay />}
    </>
  );
};

const AdjacentCapabilityVideoPreloader = ({ capabilities, current }: { capabilities: Capability[]; current: number }) => {
  const adjacentVideoSources = capabilities
    .filter((capability, index) => capability.appScreenType === 'video' && capability.appScreen && shouldPreloadNeighbor(index, current))
    .map((capability) => capability.appScreen as string);

  if (adjacentVideoSources.length === 0) {
    return null;
  }

  return (
    <div aria-hidden="true" className="pointer-events-none fixed left-[-9999px] top-[-9999px] h-px w-px overflow-hidden">
      {adjacentVideoSources.map((src) => (
        <video key={src} src={src} muted playsInline preload="auto" />
      ))}
    </div>
  );
};

const getIsDesktopViewport = () => (
  typeof window !== 'undefined' && window.matchMedia('(min-width: 768px)').matches
);

const getPhoneFrameDropShadow = (glowColor: string) => [
  'drop-shadow(0 32px 48px rgba(0,0,0,0.58))',
  `drop-shadow(0 0 18px ${glowColor})`,
  `drop-shadow(0 0 42px ${glowColor})`,
].join(' ');

const getDesktopArrowButtonStyle = (accentColor: string) => ({
  background: 'linear-gradient(145deg, rgba(255,255,255,0.18), rgba(255,255,255,0.055))',
  border: '1px solid rgba(255,255,255,0.24)',
  backdropFilter: 'blur(18px) saturate(155%)',
  WebkitBackdropFilter: 'blur(18px) saturate(155%)',
  boxShadow: [
    '0 14px 38px rgba(0,0,0,0.46)',
    'inset 0 1px 0 rgba(255,255,255,0.32)',
    'inset 0 -10px 20px rgba(255,255,255,0.05)',
    `0 0 26px ${accentColor}30`,
  ].join(', '),
  color: 'rgba(255,255,255,0.88)',
});

// ── 手机框（可替换图片）──────────────────────────────────────────────────────
const PhoneMockup = ({
  item,
  active = true,
  width = 225,
  floating = true,
}: {
  item: Capability;
  active?: boolean;
  width?: number;
  floating?: boolean;
}) => {
  const [a, b, c] = item.accent;
  return (
    <div
      className="relative flex-shrink-0"
      style={{
        width,
        marginTop: floating ? -64 : 0,
        marginBottom: floating ? -64 : 0,
        zIndex: 20,
      }}
    >
      {/* 外层柔光 */}
      <div
        className="absolute -inset-6 rounded-[3rem] blur-3xl opacity-40 pointer-events-none"
        style={{ background: `radial-gradient(ellipse, ${a}99, transparent 70%)` }}
      />
      <div
        className="relative"
        style={{ aspectRatio: '1403 / 2862' }}
      >
        <div
          className="absolute overflow-hidden bg-black"
          style={{
            inset: '2.5% 5.1% 2.3%',
            borderRadius: '12% / 5.7%',
          }}
        >
          {item.appScreen && item.appScreenType === 'video' ? (
            <SmartPhoneVideo src={item.appScreen} active={active} />
          ) : item.appScreen ? (
            <img
              src={item.appScreen}
              alt={item.title}
              loading="lazy"
              decoding="async"
              className="absolute inset-0 w-full h-full object-cover"
            />
          ) : (
            <div
              className="absolute inset-0 flex flex-col items-center justify-center gap-3"
              style={{ background: `linear-gradient(160deg, ${a}, ${b}, ${c})` }}
            >
              <div className="absolute inset-0 bg-[radial-gradient(circle_at_30%_20%,rgba(255,255,255,0.2),transparent_60%)]" />
              <div className="absolute inset-0 bg-[radial-gradient(circle_at_70%_80%,rgba(0,0,0,0.2),transparent_60%)]" />
              <div className="relative z-10 w-10 h-10 rounded-2xl bg-white/15 border border-white/30 flex items-center justify-center backdrop-blur-sm">
                <div className="w-4 h-4 rounded-sm border-2 border-white/60" />
              </div>
              <span className="relative z-10 text-white/40 text-[0.48rem] font-mono tracking-[0.2em] uppercase">App Screen</span>
            </div>
          )}
        </div>

        <div
          className="pointer-events-none absolute"
          style={{
            inset: '2.5% 5.1% 2.3%',
            borderRadius: '12% / 5.7%',
            boxShadow: 'inset 0 0 34px rgba(255,255,255,0.08), inset 0 0 18px rgba(0,0,0,0.24)',
          }}
        />

        <img
          src={media.frames.iphone16ProPortrait}
          alt=""
          aria-hidden="true"
          loading="lazy"
          decoding="async"
          className="pointer-events-none absolute inset-0 z-20 h-full w-full select-none"
          style={{ filter: getPhoneFrameDropShadow(`${a}88`) }}
        />

        <div className="pointer-events-none absolute inset-x-[9%] top-[1.1%] z-30 h-[2.8%] rounded-full bg-white/20 blur-md opacity-45" />
      </div>
    </div>
  );
};

const getCapabilityGalleryImages = (item: Capability) => (
  item.galleryImages.length > 0
    ? item.galleryImages
    : item.appScreen
      ? [item.appScreen]
      : []
);

const GalleryShowcase = ({
  item,
  compact = false,
}: {
  item: Capability;
  compact?: boolean;
}) => {
  const [a, b] = item.accent;
  const images = getCapabilityGalleryImages(item).slice(0, 8);

  if (images.length === 0) {
    return (
      <div
        className="flex min-h-[22rem] w-full items-center justify-center rounded-2xl border border-white/10 bg-white/[0.04] px-8 text-center text-sm text-neutral-500"
        style={{ boxShadow: `0 0 42px ${item.glowColor}` }}
      >
        Gallery Screens
      </div>
    );
  }

  return (
    <div className={`relative w-full ${compact ? 'max-w-[24rem]' : 'max-w-[58rem]'}`}>
      <div
        className="pointer-events-none absolute -inset-10 opacity-35 blur-3xl"
        style={{ background: `radial-gradient(circle at 30% 20%, ${a}66, transparent 42%), radial-gradient(circle at 72% 80%, ${b}66, transparent 45%)` }}
      />
      <div className={`relative grid ${compact ? 'grid-cols-1 gap-3' : 'grid-cols-2 gap-3'}`}>
        {images.map((src, index) => (
          <motion.figure
            key={src}
            initial={{ opacity: 0, y: 18, scale: 0.96 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            transition={{ delay: index * 0.035, duration: 0.35 }}
            className="group relative overflow-hidden rounded-xl border border-white/12 bg-white/[0.035] shadow-[0_16px_38px_rgba(0,0,0,0.28)]"
          >
            <img
              src={src}
              alt={`${item.title} ${index + 1}`}
              loading="lazy"
              decoding="async"
              className={`${compact ? 'aspect-[16/10]' : 'aspect-[16/9]'} h-full w-full object-cover transition duration-500 group-hover:scale-[1.025]`}
            />
            <div className="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-inset ring-white/10" />
          </motion.figure>
        ))}
      </div>
    </div>
  );
};

const CapabilityVisual = ({
  item,
  active = true,
  mobile = false,
}: {
  item: Capability;
  active?: boolean;
  mobile?: boolean;
}) => {
  if (item.displayMode === 'gallery') {
    return <GalleryShowcase item={item} compact={mobile} />;
  }

  return <PhoneMockup item={item} active={active} width={mobile ? 176 : 225} floating={!mobile} />;
};

const MobileServicesCarousel = ({
  item,
  current,
  direction,
  total,
  onGo,
  onJump,
  onSwipeEnd,
  cardVariants,
  springTransition,
  capabilities,
}: {
  item: Capability;
  current: number;
  direction: number;
  total: number;
  onGo: (dir: number) => void;
  onJump: (index: number) => void;
  onSwipeEnd: (_event: MouseEvent | TouchEvent | PointerEvent, info: PanInfo) => void;
  cardVariants: {
    enter: (dir: number) => { x: number; opacity: number; scale: number; rotateY: number };
    center: { x: number; opacity: number; scale: number; rotateY: number };
    exit: (dir: number) => { x: number; opacity: number; scale: number; rotateY: number };
  };
  springTransition: { type: 'spring'; stiffness: number; damping: number; mass: number };
  capabilities: Capability[];
}) => {
  const [a, b] = item.accent;

  return (
    <div className="md:hidden">
      <div className="relative mx-auto max-w-[23rem]">
        <button
          type="button"
          onClick={() => current > 0 && onGo(-1)}
          aria-label="Previous capability"
          className="absolute left-0 top-[8.5rem] z-30 flex h-10 w-10 items-center justify-center rounded-full border border-white/12 bg-neutral-900/80 text-white/70 backdrop-blur-md disabled:opacity-25"
          disabled={current === 0}
        >
          <ChevronLeft className="h-5 w-5" />
        </button>
        <button
          type="button"
          onClick={() => current < total - 1 && onGo(1)}
          aria-label="Next capability"
          className="absolute right-0 top-[8.5rem] z-30 flex h-10 w-10 items-center justify-center rounded-full border border-white/12 bg-neutral-900/80 text-white/70 backdrop-blur-md disabled:opacity-25"
          disabled={current === total - 1}
        >
          <ChevronRight className="h-5 w-5" />
        </button>

        <div className={`relative overflow-visible ${item.displayMode === 'gallery' ? 'min-h-[88rem]' : 'min-h-[46rem]'}`}>
          <AnimatePresence mode="wait" custom={direction}>
            <motion.div
              key={item.id}
              custom={direction}
              variants={cardVariants}
              initial="enter"
              animate="center"
              exit="exit"
              transition={springTransition}
              drag="x"
              dragConstraints={{ left: 0, right: 0 }}
              dragElastic={0.12}
              dragMomentum={false}
              dragSnapToOrigin
              onDragEnd={onSwipeEnd}
              className="absolute inset-x-0 top-0 cursor-grab touch-pan-y select-none active:cursor-grabbing"
            >
              <div className="flex justify-center pb-8 pt-8">
                <CapabilityVisual item={item} active mobile />
              </div>

              <article
                className="relative overflow-hidden rounded-2xl border border-white/10 bg-white/[0.055] p-5 backdrop-blur-md"
                style={{ boxShadow: `0 18px 52px ${item.glowColor}` }}
              >
                <div
                  className="pointer-events-none absolute -right-16 -top-20 h-44 w-44 rounded-full blur-3xl opacity-35"
                  style={{ background: `radial-gradient(circle, ${a}, transparent 70%)` }}
                />
                <div className="relative z-10 min-w-0">
                  <div
                    className="mb-3 inline-flex items-center rounded-full px-3 py-1 text-[0.64rem] font-mono tracking-[0.18em]"
                    style={{ background: `linear-gradient(90deg, ${a}24, ${b}12)`, border: `1px solid ${a}55`, color: a }}
                  >
                    {item.id} / CAPABILITY
                  </div>
                  <h3
                    className="mb-3 text-xl font-medium leading-snug tracking-tight text-white"
                    style={{ fontFamily: '"Noto Serif SC", serif' }}
                  >
                    {item.title}
                  </h3>
                  <p
                    className="text-[0.82rem] font-light leading-[1.85] text-neutral-300"
                    style={{ fontFamily: '"Noto Serif SC", serif' }}
                  >
                    {item.description}
                  </p>
                </div>
              </article>
            </motion.div>
          </AnimatePresence>
        </div>

        <div className="mt-5 flex items-center justify-center gap-2.5">
          {capabilities.map((capability, index) => (
            <button key={capability.id} type="button" onClick={() => onJump(index)} aria-label={`Show capability ${index + 1}`}>
              <motion.div
                animate={{
                  width: index === current ? 22 : 7,
                  background: index === current ? capability.accent[0] : 'rgba(255,255,255,0.18)',
                  boxShadow: index === current ? `0 0 8px ${capability.accent[0]}99` : 'none',
                }}
                transition={{ type: 'spring', stiffness: 400, damping: 28 }}
                className="h-[7px] rounded-full"
              />
            </button>
          ))}
        </div>
      </div>
    </div>
  );
};

// ── 主组件 ────────────────────────────────────────────────────────────────────
export const Services = () => {
  const sectionRef = useRef<HTMLElement>(null);
  const currentRef = useRef(0);
  const [capabilities, setCapabilities] = useState(loadCapabilities);
  const [current, setCurrent] = useState(0);
  const [direction, setDirection] = useState(0);
  const [isDesktop, setIsDesktop] = useState(getIsDesktopViewport);
  const total = capabilities.length;
  const item = capabilities[current];
  const [a, b] = item.accent;
  const swipeThreshold = 70;

  const go = (dir: number) => {
    setDirection(dir);
    setCurrent((prev) => {
      const next = Math.max(0, Math.min(total - 1, prev + dir));
      currentRef.current = next;
      return next;
    });
  };

  const jumpTo = (index: number) => {
    setDirection(index > currentRef.current ? 1 : -1);
    currentRef.current = index;
    setCurrent(index);
  };

  useEffect(() => {
    currentRef.current = current;
  }, [current]);

  useEffect(() => {
    const syncCapabilities = () => {
      setCapabilities(loadCapabilities());
    };

    window.addEventListener('storage', syncCapabilities);
    window.addEventListener(capabilitiesChangedEvent, syncCapabilities);

    return () => {
      window.removeEventListener('storage', syncCapabilities);
      window.removeEventListener(capabilitiesChangedEvent, syncCapabilities);
    };
  }, []);

  useEffect(() => {
    if (current >= total) {
      const next = Math.max(0, total - 1);
      currentRef.current = next;
      setCurrent(next);
    }
  }, [current, total]);

  useEffect(() => {
    const mediaQuery = window.matchMedia('(min-width: 768px)');
    const updateViewportMode = () => setIsDesktop(mediaQuery.matches);

    updateViewportMode();
    mediaQuery.addEventListener('change', updateViewportMode);

    return () => {
      mediaQuery.removeEventListener('change', updateViewportMode);
    };
  }, []);

  const handleSwipeEnd = (_event: MouseEvent | TouchEvent | PointerEvent, info: PanInfo) => {
    const swipePower = Math.abs(info.offset.x) + Math.abs(info.velocity.x) * 0.35;

    if (info.offset.x < -swipeThreshold || (info.velocity.x < -320 && swipePower > swipeThreshold)) {
      go(1);
      return;
    }

    if (info.offset.x > swipeThreshold || (info.velocity.x > 320 && swipePower > swipeThreshold)) {
      go(-1);
    }
  };

  // 提高响应速度，缩短切换耗时，同时保留一次轻微回弹
  const springTransition = { type: 'spring' as const, stiffness: 430, damping: 28, mass: 0.72 };

  const cardVariants = {
    enter: (dir: number) => ({ x: dir > 0 ? 140 : -140, opacity: 0, scale: 0.86, rotateY: dir > 0 ? 10 : -10 }),
    center: { x: 0, opacity: 1, scale: 1, rotateY: 0 },
    exit: (dir: number) => ({ x: dir > 0 ? -100 : 100, opacity: 0, scale: 0.9, rotateY: dir > 0 ? -6 : 6 }),
  };

  return (
    <section
      ref={sectionRef}
      id="services"
      data-section-scroll="true"
      className="relative h-screen overflow-y-auto overflow-x-hidden overscroll-contain bg-neutral-950 px-5 pb-24 pt-32 [-webkit-overflow-scrolling:touch] md:flex md:items-center md:px-6 md:py-10"
    >
      <AdjacentCapabilityVideoPreloader capabilities={capabilities} current={current} />
      {/* 背景装饰 */}
      <div className="absolute inset-0 pointer-events-none overflow-hidden">
        <motion.div animate={{ rotate: 360 }} transition={{ duration: 60, repeat: Infinity, ease: 'linear' }}
          className="absolute -top-[20%] -right-[10%] w-[700px] h-[700px] border border-white/[0.04] rounded-full" style={{ borderStyle: 'dashed' }} />
        <motion.div animate={{ rotate: -360 }} transition={{ duration: 90, repeat: Infinity, ease: 'linear' }}
          className="absolute bottom-[5%] -left-[8%] w-[500px] h-[500px] border border-white/[0.03] rounded-full" />
        {/* accent 大光晕随卡片变化 */}
        <motion.div key={current} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 0.9 }}
          className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[700px] h-[500px] rounded-full blur-[130px]"
          style={{ background: `radial-gradient(ellipse, ${item.glowColor}, transparent 70%)` }} />
      </div>

      <div className="container relative z-10 mx-auto">
        {/* ── 标题：核心 / 功能 错排 ── */}
        <div className="mb-12 grid gap-6 md:mb-14 md:grid-cols-2 md:items-center md:gap-10">
          <div>
            <div className="mb-5 flex items-center gap-4 md:mb-6 md:gap-6">
              <div className="flex items-baseline gap-3">
                <span className="font-serif italic text-lg text-white">03</span>
                <span className="text-[0.62rem] font-mono uppercase tracking-[0.24em] text-neutral-400 md:text-xs md:tracking-[0.3em]">/ Capabilities</span>
              </div>
              <div className="h-px flex-1 bg-gradient-to-r from-white/30 to-transparent md:w-32 md:flex-none" />
            </div>
            <motion.h2
              initial={{ opacity: 0, y: 28 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.65 }}
              className="text-4xl font-medium leading-tight tracking-tight text-white md:hidden"
              style={{ fontFamily: '"Noto Serif SC", serif' }}
            >
              核心场景
            </motion.h2>
            <motion.div className="hidden md:block" initial={{ opacity: 0, y: 40 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ duration: 0.8 }}>
              <div
                className="text-5xl md:text-7xl font-medium tracking-tighter leading-none text-white select-none"
                style={{ marginLeft: '0.28em' }}
              >
                核心
              </div>
              <div className="text-5xl md:text-7xl font-medium tracking-tighter leading-none select-none"
                style={{
                  marginLeft: '1.72em',
                  fontStyle: 'italic',
                  fontFamily: 'serif',
                  background: 'linear-gradient(90deg, rgba(255,255,255,0.45), rgba(255,255,255,0.15))',
                  WebkitBackgroundClip: 'text',
                  WebkitTextFillColor: 'transparent',
                }}>
                场景
              </div>
            </motion.div>
          </div>
          <motion.p initial={{ opacity: 0, x: 20 }} whileInView={{ opacity: 1, x: 0 }} viewport={{ once: true }} transition={{ delay: 0.2, duration: 0.8 }}
            className="max-w-[28rem] text-sm font-light leading-relaxed text-neutral-400 md:border-l md:border-white/10 md:pl-10 md:text-base"
            style={{ fontFamily: '"Noto Serif SC", serif' }}>
            覆盖电音爱好者从发现、记录到社交的完整旅途。
          </motion.p>
        </div>

        {!isDesktop && (
          <MobileServicesCarousel
            item={item}
            current={current}
            direction={direction}
            total={total}
            onGo={go}
            onJump={jumpTo}
            onSwipeEnd={handleSwipeEnd}
            cardVariants={cardVariants}
            springTransition={springTransition}
            capabilities={capabilities}
          />
        )}

        {/* ── 轮播区域：窄桌面箭头下沉，宽屏箭头回到卡片两侧 ── */}
        {isDesktop && <div className={`relative mx-auto hidden w-full md:block ${item.displayMode === 'gallery' ? 'max-w-[1480px]' : 'max-w-[1200px]'}`} style={{ perspective: 1400 }}>
          {/* 卡片容器 */}
          <div className={`relative overflow-visible px-0 ${item.displayMode === 'gallery' ? 'sm:px-[34px]' : 'sm:px-[76px]'}`} style={{ minHeight: item.displayMode === 'gallery' ? 660 : 430 }}>
            {/* 左箭头 */}
            <motion.button
              whileHover={{ scale: 1.08, background: 'linear-gradient(145deg, rgba(255,255,255,0.26), rgba(255,255,255,0.09))' }}
              whileTap={{ scale: 0.92 }}
              onClick={() => go(-1)}
              disabled={current === 0}
              aria-label="上一项功能"
              className="absolute bottom-[-4.25rem] left-1/2 z-30 flex h-12 w-12 -translate-x-[4.15rem] items-center justify-center rounded-full transition-opacity disabled:cursor-default disabled:opacity-35 xl:bottom-auto xl:left-2 xl:top-1/2 xl:h-14 xl:w-14 xl:-translate-x-0 xl:-translate-y-1/2"
              style={getDesktopArrowButtonStyle(a)}
            >
              <ChevronLeft className="h-5 w-5 drop-shadow-[0_0_8px_rgba(255,255,255,0.45)]" />
            </motion.button>

            {/* 右箭头 */}
            <motion.button
              whileHover={{ scale: 1.08, background: 'linear-gradient(145deg, rgba(255,255,255,0.26), rgba(255,255,255,0.09))' }}
              whileTap={{ scale: 0.92 }}
              onClick={() => go(1)}
              disabled={current === total - 1}
              aria-label="下一项功能"
              className="absolute bottom-[-4.25rem] left-1/2 z-30 flex h-12 w-12 translate-x-[1.15rem] items-center justify-center rounded-full transition-opacity disabled:cursor-default disabled:opacity-35 xl:bottom-auto xl:left-auto xl:right-2 xl:top-1/2 xl:h-14 xl:w-14 xl:translate-x-0 xl:-translate-y-1/2"
              style={getDesktopArrowButtonStyle(a)}
            >
              <ChevronRight className="h-5 w-5 drop-shadow-[0_0_8px_rgba(255,255,255,0.45)]" />
            </motion.button>

            <AnimatePresence mode="wait" custom={direction}>
              <motion.div
                key={current}
                custom={direction}
                variants={cardVariants}
                initial="enter"
                animate="center"
                exit="exit"
                transition={springTransition}
                className="absolute inset-0 cursor-grab active:cursor-grabbing select-none touch-pan-y"
                style={{ transformStyle: 'preserve-3d' }}
                drag="x"
                dragConstraints={{ left: 0, right: 0 }}
                dragElastic={0.12}
                dragMomentum={false}
                dragSnapToOrigin
                whileDrag={{ scale: 0.985, cursor: 'grabbing' }}
                onDragEnd={handleSwipeEnd}
              >
                {/* 果冻卡片 */}
                <div
                  className="relative mx-auto flex items-center rounded-3xl h-full overflow-visible"
                  style={{
                    width: item.displayMode === 'gallery' ? 'min(100%, 1420px)' : 'min(100%, 1040px)',
                    background: 'linear-gradient(135deg, rgba(255,255,255,0.075) 0%, rgba(255,255,255,0.022) 100%)',
                    backdropFilter: 'blur(36px)',
                    WebkitBackdropFilter: 'blur(36px)',
                    border: '1px solid rgba(255,255,255,0.11)',
                    boxShadow: `0 0 90px ${item.glowColor}, 0 0 0 1px rgba(255,255,255,0.04), inset 0 1px 0 rgba(255,255,255,0.12)`,
                  }}
                >
                  <div className="absolute inset-x-0 top-0 h-px rounded-full pointer-events-none"
                    style={{ background: `linear-gradient(90deg, transparent 0%, ${a}cc 30%, ${b}cc 70%, transparent 100%)` }} />
                  <div className="absolute inset-x-0 bottom-0 h-px rounded-full pointer-events-none"
                    style={{ background: `linear-gradient(90deg, transparent 0%, ${b}55 50%, transparent 100%)` }} />
                  <div className="absolute -top-20 -left-20 w-72 h-72 rounded-full blur-[70px] opacity-25 pointer-events-none"
                    style={{ background: `radial-gradient(circle, ${a}, transparent)` }} />

                  <div className={`${item.displayMode === 'gallery' ? 'w-[25%] max-w-[21rem] flex-none' : 'flex-1'} min-w-0 py-10 pl-10 pr-5 relative z-10`}>
                    <div className="inline-flex items-center gap-2 mb-5 px-3 py-1 rounded-full text-xs font-mono tracking-widest"
                      style={{ background: `linear-gradient(90deg, ${a}25, ${b}10)`, border: `1px solid ${a}50`, color: a }}>
                      {item.id} / CAPABILITY
                    </div>
                    <h3 className="text-2xl sm:text-3xl font-medium tracking-tight text-white mb-5 leading-tight"
                      style={{ fontFamily: '"Noto Serif SC", serif' }}>
                      {item.title}
                    </h3>
                    <p className="text-sm sm:text-base text-neutral-400 leading-relaxed font-light"
                      style={{ fontFamily: '"Noto Serif SC", serif' }}>
                      {item.description}
                    </p>
                  </div>

                  <div className={`${item.displayMode === 'gallery' ? 'min-w-0 flex-1' : 'flex-shrink-0'} py-8 pr-8 relative z-20`}>
                    <CapabilityVisual item={item} active />
                  </div>
                </div>
              </motion.div>
            </AnimatePresence>
          </div>

          {/* ── 圆点：卡片正下方居中 ── */}
          <div className="mt-24 flex items-center justify-center gap-2.5 xl:mt-10">
            {capabilities.map((cap, i) => (
              <button key={i} onClick={() => jumpTo(i)}>
                <motion.div
                  animate={{
                    width: i === current ? 22 : 7,
                    background: i === current ? cap.accent[0] : 'rgba(255,255,255,0.18)',
                    boxShadow: i === current ? `0 0 8px ${cap.accent[0]}99` : 'none',
                  }}
                  transition={{ type: 'spring', stiffness: 400, damping: 28 }}
                  className="h-[7px] rounded-full"
                />
              </button>
            ))}
          </div>
        </div>}
      </div>
    </section>
  );
};
