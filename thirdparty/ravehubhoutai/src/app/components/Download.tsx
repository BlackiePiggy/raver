import React, { useRef } from 'react';
import { motion, useScroll, useTransform } from 'motion/react';
import { media } from '../data/media';
import { showComingSoon } from '../utils/comingSoon';

const AppleDownloadIcon = ({ className }: { className?: string }) => (
  <svg
    className={className}
    viewBox="0 0 1024 1024"
    version="1.1"
    xmlns="http://www.w3.org/2000/svg"
    aria-hidden="true"
    focusable="false"
  >
    <path
      d="M905.758118 784.564706c-14.757647 34.093176-32.225882 65.475765-52.464942 94.32847-27.587765 39.333647-50.176 66.56-67.584 81.679059-26.985412 24.816941-55.898353 37.526588-86.859294 38.249412-22.226824 0-49.031529-6.324706-80.233411-19.154823-31.304282-12.769882-60.072659-19.094588-86.377412-19.094589-27.587765 0-57.175341 6.324706-88.822965 19.094589-31.695812 12.830118-57.229553 19.516235-76.751812 20.178823-29.689976 1.264941-59.283576-11.806118-88.822964-39.273412-18.853647-16.444235-42.435765-44.634353-70.686118-84.570353-30.3104-42.646588-55.229741-92.099765-74.752-148.48-20.907671-60.897882-31.388612-119.868235-31.388612-176.959247 0-65.397459 14.1312-121.801788 42.435765-169.068423 22.244894-37.966306 51.838494-67.915294 88.877176-89.901177s77.059012-33.189647 120.157365-33.906447c23.582118 0 54.506918 7.294494 92.937035 21.630494 38.321694 14.384188 62.927812 21.678682 73.715953 21.678683 8.065506 0 35.400282-8.529318 81.739294-25.533741 43.821176-15.7696 80.805647-22.299106 111.104-19.727059 82.100706 6.625882 143.781647 38.990306 184.801883 97.29807-73.426824 44.489788-109.748706 106.8032-109.025883 186.741459 0.662588 62.265224 23.250824 114.079624 67.644236 155.22033 20.118588 19.094588 42.586353 33.852235 67.584 44.333176-5.421176 15.721412-11.143529 30.780235-17.227294 45.236706zM717.462588 43.610353c0 48.802635-17.829647 94.370635-53.36847 136.547388-42.887529 50.139859-94.762165 79.113035-151.015906 74.541177a151.925459 151.925459 0 0 1-1.132424-18.492236c0-46.851012 20.395671-96.990871 56.615153-137.987011 18.082635-20.757082 41.080471-38.014494 68.969412-51.784283 27.828706-13.564988 54.151529-21.064282 78.908235-22.347294 0.722824 6.523482 1.024 13.046965 1.024 19.516235z"
      fill="currentColor"
    />
  </svg>
);

const AndroidDownloadIcon = ({ className }: { className?: string }) => (
  <svg
    className={className}
    viewBox="0 0 1024 1024"
    version="1.1"
    xmlns="http://www.w3.org/2000/svg"
    aria-hidden="true"
    focusable="false"
  >
    <path
      d="M256.013333 768.013333c0 23.465445 19.199 42.664445 42.664445 42.664445l42.664445 0 0 149.325556c0 35.411489 28.585178 63.996667 63.996667 63.996667s63.996667-28.585178 63.996667-63.996667l0-149.325556 85.328889 0 0 149.325556c0 35.411489 28.585178 63.996667 63.996667 63.996667s63.996667-28.585178 63.996667-63.996667l0-149.325556 42.664445 0c23.465445 0 42.664445-19.199 42.664445-42.664445l0-426.644446-511.973335 0 0 426.644446zM149.352221 341.368887c-35.411489 0-63.996667 28.585178-63.996667 63.996667l0 298.651112c0 35.411489 28.585178 63.996667 63.996667 63.996667s63.996667-28.585178 63.996667-63.996667l0-298.651112c0-35.411489-28.585178-63.996667-63.996667-63.996667zM874.647779 341.368887c-35.411489 0-63.996667 28.585178-63.996667 63.996667l0 298.651112c0 35.411489 28.585178 63.996667 63.996667 63.996667s63.996667-28.585178 63.996667-63.996667l0-298.651112c0-35.411489-28.585178-63.996667-63.996667-63.996667zM662.605489 92.208531l55.6771-55.6771c8.319567-8.319567 8.319567-21.758867 0-30.078433s-21.758867-8.319567-30.078433 0l-63.143378 62.930056c-34.131556-16.852456-72.316234-26.665278-113.060778-26.665278-40.957867 0-79.355867 9.812822-113.700745 26.8786l-63.3567-63.3567c-8.319567-8.319567-21.758867-8.319567-30.078433 0s-8.319567 21.758867 0 30.078433l55.890422 55.890422c-63.3567 46.717567-104.741211 121.806989-104.741211 206.495912l511.973335 0c0-84.902245-41.597833-159.991667-105.381178-206.495912zM426.671111 213.375553l-42.664445 0 0-42.664445 42.664445 0 0 42.664445zM639.993334 213.375553l-42.664445 0 0-42.664445 42.664445 0 0 42.664445z"
      fill="currentColor"
    />
  </svg>
);

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
      className="relative flex min-h-[100svh] items-center overflow-hidden bg-neutral-950 px-5 py-24 md:h-screen md:overflow-hidden md:px-6 md:py-16"
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
            <span className="font-serif text-lg italic text-white">05</span>
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
              onClick={showComingSoon}
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              className="group flex items-center gap-3 rounded-full bg-white px-6 py-3.5 text-black shadow-lg transition-all hover:bg-neutral-100 hover:shadow-2xl"
            >
              <AppleDownloadIcon className="h-5 w-5" />
              <div className="text-left">
                <div className="text-xs opacity-70">Download on the</div>
                <div className="-mt-0.5 text-sm font-semibold">App Store</div>
              </div>
            </motion.a>

            <motion.a
              href="#"
              onClick={showComingSoon}
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              className="group flex items-center gap-3 rounded-full bg-white px-6 py-3.5 text-black shadow-lg transition-all hover:bg-neutral-100 hover:shadow-2xl"
            >
              <AndroidDownloadIcon className="h-5 w-5" />
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
