import React, { useRef } from 'react';
import { motion, useScroll, useTransform } from 'motion/react';
import { Apple, Smartphone } from 'lucide-react';
import { media } from '../data/media';

export const Download = () => {
  const sectionRef = useRef<HTMLElement>(null);
  const { scrollYProgress } = useScroll({
    target: sectionRef,
    offset: ['start end', 'start center'],
  });

  const contentOpacity = useTransform(scrollYProgress, [0, 0.5, 1], [0, 0.72, 1]);
  const contentY = useTransform(scrollYProgress, [0, 1], [96, 0]);
  const contentScale = useTransform(scrollYProgress, [0, 1], [0.96, 1]);
  const videoOpacity = useTransform(scrollYProgress, [0, 0.6, 1], [0.2, 0.65, 1]);
  const videoBlurOpacity = useTransform(scrollYProgress, [0, 0.6, 1], [0.18, 0.4, 0.58]);

  return (
    <section
      ref={sectionRef}
      id="download"
      data-section-scroll="true"
      className="relative flex h-screen items-center overflow-y-auto overflow-x-hidden overscroll-contain bg-neutral-950 px-5 py-24 [-webkit-overflow-scrolling:touch] md:px-6 md:py-16"
    >
      <div className="absolute inset-0">
        <motion.video
          autoPlay
          loop
          muted
          playsInline
          aria-hidden="true"
          className="absolute inset-[-6%] h-[112%] w-[112%] object-cover blur-3xl saturate-125"
          style={{ opacity: videoBlurOpacity }}
        >
          <source src={media.videos.downloadBackground} type="video/mp4" />
        </motion.video>

        <motion.video
          autoPlay
          loop
          muted
          playsInline
          className="absolute inset-0 h-full w-full object-cover"
          style={{ opacity: videoOpacity }}
        >
          <source src={media.videos.downloadBackground} type="video/mp4" />
        </motion.video>

        <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(4,10,18,0.06),rgba(2,6,14,0.54)_52%,rgba(2,4,8,0.84)_100%)]" />
        <div className="absolute inset-x-0 top-[-4%] h-40 bg-gradient-to-b from-neutral-950 via-neutral-950/86 to-transparent blur-2xl" />
        <div className="absolute inset-x-0 bottom-[-4%] h-44 bg-gradient-to-t from-neutral-950 via-neutral-950/88 to-transparent blur-2xl" />
        <div className="absolute inset-y-0 left-0 w-40 bg-gradient-to-r from-neutral-950 via-neutral-950/84 to-transparent blur-2xl md:left-[-3%]" />
        <div className="absolute inset-y-0 right-0 w-40 bg-gradient-to-l from-neutral-950 via-neutral-950/84 to-transparent blur-2xl md:right-[-3%]" />
        <div className="absolute inset-0 shadow-[inset_0_0_140px_rgba(3,7,12,0.9)]" />
      </div>

      <motion.div
        className="container relative z-10 mx-auto"
        style={{ opacity: contentOpacity, y: contentY, scale: contentScale }}
      >
        <div className="mb-8 flex items-center gap-4 md:mb-10 md:gap-6">
          <div className="flex items-baseline gap-3">
            <span className="font-serif text-lg italic text-white">04</span>
            <span className="text-[0.62rem] uppercase tracking-[0.24em] text-neutral-300 md:text-xs md:tracking-[0.3em]">Download</span>
          </div>
          <div className="h-px flex-1 bg-gradient-to-r from-white/40 to-transparent md:w-32 md:flex-none" />
        </div>

        <div className="max-w-[720px] md:pl-12 lg:pl-20">
          <motion.h2
            initial={{ opacity: 0, y: 36 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, amount: 0.45 }}
            transition={{ duration: 0.75, ease: [0.22, 1, 0.36, 1] }}
            className="mb-6 text-4xl font-medium leading-tight tracking-tight md:mb-7 md:text-7xl md:leading-[0.9] md:tracking-tighter"
          >
            下载
            <br />
            <span className="font-serif italic text-neutral-300">Ravehub</span>
          </motion.h2>

          <motion.p
            initial={{ opacity: 0, y: 26 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, amount: 0.45 }}
            transition={{ delay: 0.12, duration: 0.75, ease: [0.22, 1, 0.36, 1] }}
            className="mb-9 max-w-[34rem] text-base font-light leading-relaxed text-neutral-200 md:text-lg"
          >
            随时随地，与全球电音爱好者连接。发现最新活动，分享你的音乐热情。
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 22 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, amount: 0.45 }}
            transition={{ delay: 0.2, duration: 0.75, ease: [0.22, 1, 0.36, 1] }}
            className="flex flex-col gap-3 sm:flex-row"
          >
            <motion.a
              href="#"
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              className="group flex items-center gap-3 rounded-full bg-white px-6 py-3.5 text-black shadow-lg transition-all hover:bg-neutral-100 hover:shadow-2xl"
            >
              <Apple className="h-5 w-5" />
              <div className="text-left">
                <div className="text-xs opacity-70">Download on the</div>
                <div className="-mt-0.5 text-sm font-semibold">App Store</div>
              </div>
            </motion.a>

            <motion.a
              href="#"
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              className="group flex items-center gap-3 rounded-full border border-white/18 bg-neutral-900/65 px-6 py-3.5 text-white backdrop-blur-md transition-all hover:bg-neutral-800/85"
            >
              <Smartphone className="h-5 w-5" />
              <div className="text-left">
                <div className="text-xs opacity-70">Get it on</div>
                <div className="-mt-0.5 text-sm font-semibold">Android</div>
              </div>
            </motion.a>
          </motion.div>

        </div>
      </motion.div>
    </section>
  );
};
