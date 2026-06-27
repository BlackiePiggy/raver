import React, { useRef } from 'react';
import { motion, useScroll, useTransform } from 'motion/react';
import { ChevronDown } from 'lucide-react';
import { media } from '../data/media';

export const Hero = () => {
  const containerRef = useRef<HTMLElement>(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start start", "end start"]
  });

  const yText = useTransform(scrollYProgress, [0, 1], [0, 200]);
  const opacityText = useTransform(scrollYProgress, [0, 0.6], [1, 0]);

  return (
    <section ref={containerRef} id="hero" className="relative h-screen flex items-center justify-center overflow-hidden px-6 bg-neutral-950">

      {/* Video Background */}
      <div className="absolute inset-0 z-0">
        <video
          autoPlay
          loop
          muted
          playsInline
          className="absolute inset-0 w-full h-full object-cover opacity-50"
        >
          <source src={media.videos.hero} type="video/mp4" />
        </video>
        {/* Dark Overlay */}
        <div className="absolute inset-0 bg-black/40" />
        {/* Bottom Gradient Fade with Blur */}
        <div className="absolute bottom-0 left-0 right-0 h-64 bg-gradient-to-t from-neutral-950 via-neutral-950/60 to-transparent backdrop-blur-[2px]" />
        <div className="absolute bottom-0 left-0 right-0 h-32 bg-gradient-to-t from-neutral-950 to-transparent" />
      </div>

      {/* Main Content */}
      <div className="relative z-10 w-full h-full flex flex-col">
        {/* Title at center */}
        <div className="flex-1 flex items-center justify-center -mt-4">
          <motion.div
            className="flex w-full flex-col items-center px-4"
            style={{ y: yText, opacity: opacityText }}
          >
            <motion.h1
              initial={{ opacity: 0, y: 50 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 1, ease: [0.16, 1, 0.3, 1] }}
              className="text-6xl md:text-8xl lg:text-9xl font-bold tracking-tighter leading-none"
              style={{ fontFamily: 'Graduate, serif' }}
            >
              <span className="text-white">Rave</span>
              <span className="italic text-neutral-500">hub</span>
            </motion.h1>

            <motion.div
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 1, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
              className="mt-7 flex w-full max-w-[22rem] items-center justify-center gap-4 text-sm font-light text-neutral-300 sm:max-w-[30rem] sm:gap-6 sm:text-base md:mt-9 md:max-w-4xl md:gap-16 md:text-lg"
            >
              <p className="min-w-0 flex-1 text-right leading-relaxed">
                由电音人共建，<br />
                为电音人而生
              </p>

              <div className="h-12 w-px shrink-0 bg-white/10 md:h-16" />

              <p className="min-w-0 flex-1 text-left leading-relaxed">
                Based in China,<br />
                working globally.
              </p>
            </motion.div>
          </motion.div>
        </div>

        {/* Animated Arrow - at bottom */}
        <motion.button
          onClick={() => {
            const servicesSection = document.getElementById('services');
            if (servicesSection) {
              servicesSection.scrollIntoView({ behavior: 'auto' });
            }
          }}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 1, delay: 0.4 }}
          className="absolute bottom-12 left-1/2 -translate-x-1/2 flex flex-col items-center gap-2 cursor-pointer group"
        >
          <span className="text-xs uppercase tracking-widest text-white/60 font-mono group-hover:text-white/80 transition-colors">Learn more</span>
          <motion.div
            animate={{ y: [0, 10, 0] }}
            transition={{ duration: 2, repeat: Infinity, ease: "easeInOut" }}
          >
            <ChevronDown className="w-8 h-8 text-white/70 group-hover:text-white transition-colors" strokeWidth={1.5} />
          </motion.div>
        </motion.button>
      </div>
    </section>
  );
};
