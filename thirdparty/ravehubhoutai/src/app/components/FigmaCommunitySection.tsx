import React, { useEffect, useRef, useState } from 'react';
import { motion, type MotionValue, useMotionValue, useScroll, useTransform } from 'motion/react';
import { media } from '../data/media';

type CommunityMedia = {
  src: string;
  type: 'image' | 'video';
  title: string;
  glowColor: string;
  angle: number;
  radius: string;
};

const communityMedia: CommunityMedia[] = [
  {
    src: media.communityShowcase.edmPersonality,
    type: 'image',
    title: 'EDM personality profile',
    glowColor: 'rgba(155,92,255,0.78)',
    angle: -84,
    radius: 'clamp(12rem, 24vw, 22rem)',
  },
  {
    src: media.communityShowcase.diyTimetable,
    type: 'image',
    title: 'DIY timetable',
    glowColor: 'rgba(124,255,107,0.72)',
    angle: -18,
    radius: 'clamp(13rem, 27vw, 24rem)',
  },
  {
    src: media.communityShowcase.rollingBanner,
    type: 'image',
    title: 'Rolling banner editor',
    glowColor: 'rgba(52,214,255,0.76)',
    angle: 48,
    radius: 'clamp(12rem, 25vw, 23rem)',
  },
  {
    src: media.communityShowcase.keepInTouch,
    type: 'image',
    title: 'Keep in touch',
    glowColor: 'rgba(255,74,47,0.78)',
    angle: 116,
    radius: 'clamp(12rem, 25vw, 23rem)',
  },
  {
    src: media.communityShowcase.communityVideo01,
    type: 'image',
    title: 'Community video one',
    glowColor: 'rgba(255,71,204,0.76)',
    angle: 184,
    radius: 'clamp(12rem, 24vw, 22rem)',
  },
  {
    src: media.communityShowcase.communityVideo02,
    type: 'image',
    title: 'Community video two',
    glowColor: 'rgba(255,216,74,0.76)',
    angle: 250,
    radius: 'clamp(12rem, 24vw, 22rem)',
  },
];

export const FigmaCommunitySection = () => {
  const sectionRef = useRef<HTMLElement>(null);
  const rotationProgressRef = useRef(0);
  const displayedRotationProgressRef = useRef(0);
  const targetRotationProgressRef = useRef(0);
  const rotationAnimationRef = useRef<number | null>(null);
  const rotationProgress = useMotionValue(0);
  const [isDesktop, setIsDesktop] = useState(() => (
    typeof window !== 'undefined' && window.matchMedia('(min-width: 768px)').matches
  ));

  const { scrollYProgress } = useScroll({
    target: sectionRef,
    offset: ['start start', 'end end'],
  });
  const interactiveRotate = useTransform(rotationProgress, [0, 1], [-34, 326]);
  const nativeRotate = useTransform(scrollYProgress, [0, 1], [-34, 326]);
  const interactiveHeadlineY = useTransform(rotationProgress, [0, 0.18, 0.78, 1], [34, 0, 0, -18]);
  const nativeHeadlineY = useTransform(scrollYProgress, [0, 0.18, 0.78, 1], [34, 0, 0, -18]);
  const interactiveHeadlineOpacity = useTransform(rotationProgress, [0, 0.12, 0.86, 1], [0.82, 1, 1, 0.78]);
  const nativeHeadlineOpacity = useTransform(scrollYProgress, [0, 0.12, 0.86, 1], [0.82, 1, 1, 0.78]);
  const rotate = isDesktop ? interactiveRotate : nativeRotate;
  const headlineY = isDesktop ? interactiveHeadlineY : nativeHeadlineY;
  const headlineOpacity = isDesktop ? interactiveHeadlineOpacity : nativeHeadlineOpacity;

  const updateRotation = (delta: number) => {
    const current = rotationProgressRef.current;
    const next = Math.min(1, Math.max(0, current + delta));

    rotationProgressRef.current = next;
    targetRotationProgressRef.current = next;

    if (rotationAnimationRef.current === null) {
      const tick = () => {
        const displayed = displayedRotationProgressRef.current;
        const eased = displayed + (targetRotationProgressRef.current - displayed) * 0.26;

        displayedRotationProgressRef.current = eased;
        rotationProgress.set(eased);

        if (Math.abs(targetRotationProgressRef.current - eased) < 0.002) {
          displayedRotationProgressRef.current = targetRotationProgressRef.current;
          rotationProgress.set(targetRotationProgressRef.current);
          rotationAnimationRef.current = null;
          return;
        }

        rotationAnimationRef.current = requestAnimationFrame(tick);
      };

      rotationAnimationRef.current = requestAnimationFrame(tick);
    }

    return next;
  };

  useEffect(() => {
    const section = sectionRef.current;
    if (!section) return;

    const onSectionWheel = (event: Event) => {
      const customEvent = event as CustomEvent<{ deltaY: number; direction: number; sectionId: string }>;
      if (customEvent.detail.sectionId !== 'community') return;

      const current = rotationProgressRef.current;
      const direction = customEvent.detail.direction;
      const isAtStart = current <= 0 && direction < 0;
      const isAtEnd = current >= 1 && direction > 0;

      if (isAtStart || isAtEnd) {
        return;
      }

      customEvent.preventDefault();
      updateRotation(Math.abs(customEvent.detail.deltaY) * 0.0027 * direction);
    };

    section.addEventListener('ravehub:section-wheel', onSectionWheel as EventListener);
    return () => {
      if (rotationAnimationRef.current !== null) {
        cancelAnimationFrame(rotationAnimationRef.current);
      }

      section.removeEventListener('ravehub:section-wheel', onSectionWheel as EventListener);
    };
  }, []);

  useEffect(() => {
    const mediaQuery = window.matchMedia('(min-width: 768px)');
    const updateViewportMode = () => setIsDesktop(mediaQuery.matches);

    updateViewportMode();
    mediaQuery.addEventListener('change', updateViewportMode);

    return () => mediaQuery.removeEventListener('change', updateViewportMode);
  }, []);

  return (
    <section
      ref={sectionRef}
      id="community"
      className="relative h-[260svh] bg-black md:h-screen md:overflow-hidden"
      aria-label="Community interactive media carousel"
      tabIndex={0}
    >
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_50%_54%,rgba(80,255,95,0.13),transparent_36%),radial-gradient(circle_at_18%_22%,rgba(155,92,255,0.18),transparent_28%),radial-gradient(circle_at_82%_76%,rgba(255,74,47,0.12),transparent_32%)] opacity-60 md:opacity-100" />
      <div className="absolute inset-0 bg-[linear-gradient(to_right,#ffffff07_1px,transparent_1px),linear-gradient(to_bottom,#ffffff07_1px,transparent_1px)] bg-[size:5rem_5rem] opacity-35 [mask-image:radial-gradient(circle_at_center,#000_48%,transparent_82%)]" />

      <div className="sticky top-0 flex h-[100svh] items-center justify-center overflow-hidden px-5 md:relative md:top-auto md:h-screen">
        <motion.div
          className="absolute left-1/2 top-[23%] z-20 w-full max-w-[18rem] -translate-x-1/2 -translate-y-1/2 text-center md:top-1/2 md:max-w-none"
          style={{ y: headlineY, opacity: headlineOpacity }}
        >
          <p className="mb-3 text-[0.62rem] uppercase tracking-[0.32em] text-lime-200/55 md:mb-4 md:text-xs md:tracking-[0.42em]">Scroll to rotate</p>
          <h2 className="text-3xl font-semibold tracking-[0.1em] text-white md:text-6xl md:tracking-[0.16em]">
            了解，热爱，参与
          </h2>
          <p
            className="mt-2 text-4xl text-[#76ff55] drop-shadow-[0_0_22px_rgba(118,255,85,0.75)] md:mt-3 md:text-7xl"
            style={{ fontFamily: '"Irish Grover", "Noto Serif SC", serif' }}
          >
            Laputa
          </p>
        </motion.div>

        <motion.div
          aria-hidden="true"
          className="absolute h-[min(88vw,23.5rem)] w-[min(88vw,23.5rem)] rounded-full border border-lime-300/[0.07] shadow-[0_0_42px_rgba(80,255,95,0.035)] md:h-[min(74vw,46rem)] md:w-[min(74vw,46rem)] md:border-lime-300/10 md:shadow-[0_0_140px_rgba(80,255,95,0.08)]"
          style={{ rotate, willChange: 'transform' }}
        />

        <FixedPhoneGlows />

        <motion.div
          className="relative mt-28 h-[min(92vw,24.5rem)] w-[min(92vw,24.5rem)] md:hidden"
          style={{ rotate, willChange: 'transform' }}
        >
          {communityMedia.map((item, index) => (
            <MediaCard key={item.title} item={item} index={index} rotate={rotate} compact />
          ))}
        </motion.div>

        <motion.div
          className="relative hidden h-[min(78vw,48rem)] w-[min(78vw,48rem)] md:block"
          style={{ rotate, willChange: 'transform' }}
        >
          {communityMedia.map((item, index) => (
            <MediaCard key={item.title} item={item} index={index} rotate={rotate} />
          ))}
        </motion.div>

        <div className="pointer-events-none absolute bottom-10 left-1/2 z-20 -translate-x-1/2 text-center text-[0.68rem] uppercase tracking-[0.28em] text-white/38">
          <div className="mx-auto mb-2 h-6 w-px animate-pulse bg-white/35" />
          Scroll to rotate
        </div>

        <div className="pointer-events-none absolute inset-x-0 top-0 h-40 bg-gradient-to-b from-neutral-950 via-black/82 to-transparent" />
        <div className="pointer-events-none absolute inset-x-0 bottom-0 h-48 bg-gradient-to-t from-neutral-950 via-black/84 to-transparent" />
      </div>
    </section>
  );
};

const FixedPhoneGlows = () => (
  <div
    aria-hidden="true"
    className="pointer-events-none absolute left-1/2 top-1/2 hidden h-[min(78vw,48rem)] w-[min(78vw,48rem)] -translate-x-1/2 -translate-y-1/2 md:block"
  >
    {communityMedia.map((item) => (
      <div
        key={item.title}
        className="absolute left-1/2 top-1/2"
        style={{ transform: `translate(-50%, -50%) rotate(${item.angle}deg)` }}
      >
        <div style={{ transform: `translateX(${item.radius})` }}>
          <div
            className="h-[clamp(8rem,13vw,12rem)] w-[clamp(8rem,13vw,12rem)] -translate-x-1/2 -translate-y-1/2 rounded-full opacity-70 blur-3xl"
            style={{
              background: `radial-gradient(circle, ${item.glowColor} 0%, rgba(0,0,0,0) 68%)`,
            }}
          />
        </div>
      </div>
    ))}
  </div>
);

const MediaCard = ({
  item,
  index,
  rotate,
  compact = false,
}: {
  item: CommunityMedia;
  index: number;
  rotate: MotionValue<number>;
  compact?: boolean;
}) => {
  const counterRotate = useTransform(rotate, (value) => -value);
  const zIndex = index % 2 === 0 ? 12 : 8;
  const radius = compact ? 'clamp(6.2rem, 31vw, 7.6rem)' : item.radius;
  const frameWidth = compact ? 'w-[clamp(3.8rem,16vw,5rem)]' : 'w-[clamp(6rem,10vw,9.2rem)]';

  return (
    <motion.div
      className="absolute left-1/2 top-1/2"
      style={{
        rotate: item.angle,
        x: '-50%',
        y: '-50%',
        zIndex,
        willChange: 'transform',
        backfaceVisibility: 'hidden',
      }}
    >
      <div style={{ transform: `translateX(${radius})` }}>
        <motion.figure
          className={`relative ${frameWidth}`}
          style={{ rotate: counterRotate, willChange: 'transform', backfaceVisibility: 'hidden' }}
          initial={{ opacity: 0, scale: 0.78 }}
          whileInView={{ opacity: 1, scale: 1 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={{ delay: index * 0.08, duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
        >
          <div
            className="relative overflow-visible"
            style={{ aspectRatio: '1403 / 2862' }}
          >
            <div
              className="absolute overflow-hidden bg-black"
              style={{
                inset: '2.5% 5.1% 2.3%',
                borderRadius: '12% / 5.7%',
              }}
            >
              {item.type === 'video' ? (
                <video
                  className="absolute inset-0 h-full w-full object-cover"
                  src={item.src}
                  autoPlay
                  muted
                  loop
                  playsInline
                  preload="metadata"
                />
              ) : (
                <img
                  className="absolute inset-0 h-full w-full object-cover"
                  src={item.src}
                  alt={item.title}
                  loading="lazy"
                  decoding="async"
                />
              )}
            </div>

            <img
              src={media.frames.iphone16ProPortrait}
              alt=""
              aria-hidden="true"
              loading="lazy"
              decoding="async"
              className="pointer-events-none absolute inset-0 z-20 h-full w-full select-none"
            />

            <div className="pointer-events-none absolute inset-x-[9%] top-[1.1%] z-30 h-[2.8%] rounded-full bg-white/20 blur-md opacity-45" />
          </div>
        </motion.figure>
      </div>
    </motion.div>
  );
};
