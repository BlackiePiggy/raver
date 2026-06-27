import React, { useRef } from 'react';
import { motion, useScroll, useTransform } from 'motion/react';
import { ChevronDown } from 'lucide-react';
import { media } from '../data/media';

const cultureParagraphs = [
  'Ravehub雕琢专属于锐舞圈层的沉静热忱，扎根真实线下电音现场，打造垂直完整的电音数字社群，尊重每一位乐迷纯粹的热爱，一切功能设计都以精简高效为核心，绝不消耗用户多余时间。平台整合曲风演出推荐、一站式出行规划、到场打卡勋章、同好结伴、行业供需对接全链路能力，不少常年奔赴各地现场的电音爱好者深有体会，从前查询派对、邀约同行、记录狂欢足迹需要切换多款软件，如今在 RaveHub 便可一次性完成全部操作，每一次到场签到解锁的专属城市、曲风徽章，也能完整珍藏跨越多座城市的派对记忆，社区内容只聚焦电音相关分享，营造干净纯粹的交流空间。',
  '我们秉持极简克制的产品内核。真正完善的体验不在于不断叠加新功能，而是剥离所有无关干扰，只留存乐迷奔赴现场真正刚需的内容。我们始终认为实用工具与电音氛围感美学浑然一体，行程规划的便捷、数字勋章承载的仪式感、分享板块留存的现场感触，都是同一份线下热爱的不同表达。此前有用户提议增设娱乐弹窗、泛娱乐短视频板块来提升流量，我们选择放弃这类设计，转而深耕演出日历排版、勋章视觉体系、结伴预算核算等核心模块，页面删减冗余装饰，把所有视觉重心留给派对与音乐本身，设计全程贴合锐舞松弛自由的原生气质。',
  '我们以落地行动深耕多元电音文化传播，不流于空洞口号，切实扶持小众地下圈层生态。平台主动收录仓库地下派对、本土独立厂牌活动，为 Psy、Minimal 等小众曲风提供稳定曝光渠道，去年多家缺乏宣传渠道的本地小型厂牌入驻后，依靠平台同城精准分发，线下到场客流实现显著增长。同时我们搭建分城市社群与全球乐迷大使体系，各地资深乐迷成为文化传播大使，在线下小型分享会、露天小众派对推广打卡渠道，打通海内外乐迷交流通道；结伴分摊账单、海外音乐节行程模板等实用功能，也均来自社群玩家真实建议，让圈层参与者共同共建属于自己的电音社区。',
  '我们深耕线上线下联动生态，与坚守纯粹初心的行业从业者长久同行，相信贴合圈层需求的产品，就是电音包容平等精神无声的传递载体。平台不追逐短期流量变现，持续为独立音乐人、中小型主办方提供免费发布渠道，不少小众 DJ 依靠平台匹配到合适俱乐部演出档期，小型活动主办方无需高额推广成本，就能精准触达垂直乐迷群体。我们一边解决普通玩家出行、社交、纪念留存的各类实际难题，一边打通爱好者与行业创作者的沟通桥梁，以长久踏实的产品力量，守护并传递最本真、无门槛的锐舞文化内核。',
];

export const About = () => {
  const containerRef = useRef<HTMLElement>(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start end", "end start"]
  });

  const opacity = useTransform(scrollYProgress, [0, 0.3], [0, 1]);

  return (
    <section
      ref={containerRef}
      id="about"
      data-section-scroll="true"
      className="relative min-h-screen overflow-y-auto overflow-x-hidden overscroll-contain bg-neutral-950 px-5 py-24 [-webkit-overflow-scrolling:touch] md:px-6 md:pb-10 md:pt-28 lg:h-screen lg:overflow-hidden"
    >
      {/* Background Grid - Technical Texture */}
      <div className="absolute inset-0 bg-[linear-gradient(to_right,#ffffff05_1px,transparent_1px),linear-gradient(to_bottom,#ffffff05_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_50%,#000_70%,transparent_100%)] pointer-events-none" />

      {/* Precision Geometric Rings - Dynamic Background */}
      <div className="absolute inset-0 flex items-center justify-center pointer-events-none z-0 overflow-hidden">
        {/* Ring 1: Slow Clockwise */}
        <motion.div
          animate={{ rotate: 360 }}
          transition={{ duration: 60, repeat: Infinity, ease: "linear" }}
          className="absolute w-[600px] h-[600px] md:w-[800px] md:h-[800px] rounded-full border border-white/10 border-dashed opacity-50"
        />
        {/* Ring 2: Counter-Clockwise, Solid */}
        <motion.div
          animate={{ rotate: -360 }}
          transition={{ duration: 80, repeat: Infinity, ease: "linear" }}
          className="absolute w-[450px] h-[450px] md:w-[600px] md:h-[600px] rounded-full border border-white/10 opacity-40"
        >
          {/* Orbital Dot */}
          <div className="absolute top-1/2 left-0 -translate-x-1/2 -translate-y-1/2 w-2 h-2 bg-white rounded-full shadow-[0_0_15px_rgba(255,255,255,0.8)]" />
        </motion.div>
        {/* Ring 3: Large Outer Ring */}
        <motion.div
          animate={{ rotate: 180 }}
          transition={{ duration: 100, repeat: Infinity, ease: "linear" }}
          className="absolute w-[800px] h-[800px] md:w-[1100px] md:h-[1100px] rounded-full border border-white/5 border-dotted opacity-50"
        />
      </div>

      <div className="container mx-auto">
        
        {/* Section Header - Consistent Style */}
        <div className="mb-8 flex items-center gap-4 md:mb-10 md:gap-6">
           <div className="flex items-baseline gap-3">
              <span className="font-serif italic text-lg text-white">04</span>
              <span className="text-[0.62rem] font-mono uppercase tracking-[0.24em] text-neutral-400 md:text-xs md:tracking-[0.3em]">The Studio</span>
           </div>
           <div className="h-px flex-1 bg-gradient-to-r from-white/30 to-transparent md:w-32 md:flex-none" />
        </div>

        <div className="grid items-start gap-10 lg:grid-cols-[1.22fr_0.78fr] lg:gap-12">

          {/* Text Content */}
          <div className="relative z-10">
            <motion.h2
              initial={{ opacity: 0, y: 100 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
              className="mb-6 text-4xl font-medium leading-tight tracking-tight md:mb-8 md:text-6xl md:leading-[0.98]"
              style={{ fontFamily: '"Noto Serif SC", serif' }}
            >
              企业文化
            </motion.h2>

            <div className="grid gap-x-8 gap-y-4 text-neutral-400 md:grid-cols-2">
              {cultureParagraphs.map((paragraph, index) => (
                <motion.p
                  key={paragraph}
                  initial={{ opacity: 0, y: 20 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true }}
                  transition={{ delay: 0.15 + index * 0.08, duration: 0.8 }}
                  className="text-[0.76rem] font-light leading-[1.9] md:text-[0.72rem] md:leading-[1.85]"
                  style={{
                    fontFamily: '"Noto Serif SC", serif',
                    letterSpacing: '0.035em',
                    textAlign: 'justify',
                    textJustify: 'inter-character' as any,
                  }}
                >
                  {paragraph}
                </motion.p>
              ))}
            </div>
          </div>

          {/* Image Area */}
          <motion.div
            style={{ opacity }}
            className="relative hidden lg:mt-4 lg:block"
          >
            <div className="relative z-10 mx-auto flex max-h-[calc(100svh-14rem)] justify-center">
              <motion.div
                whileHover={{ scale: 0.98 }}
                transition={{ duration: 0.5 }}
                className="aspect-[4/5] h-[min(42vw,calc(100svh-14rem))] max-h-[34rem] max-w-full overflow-hidden bg-neutral-900 grayscale transition-all duration-700 ease-in-out hover:grayscale-0"
              >
                <img
                  src={media.images.aboutWorkspace}
                  alt="Workspace"
                  loading="lazy"
                  decoding="async"
                  className="w-full h-full object-cover opacity-80"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black/50 to-transparent" />
              </motion.div>

              {/* Decorative Ring */}
              <div className="absolute -bottom-6 left-0 hidden h-36 w-36 items-center justify-center rounded-full border border-white/10 backdrop-blur-sm lg:flex xl:h-40 xl:w-40" style={{ animation: 'spin 15s linear infinite' }}>
                <style dangerouslySetInnerHTML={{__html: `
                  @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
                `}} />
                <svg className="w-full h-full p-2" viewBox="0 0 100 100">
                  <path id="circlePath" d="M 50, 50 m -37, 0 a 37,37 0 1,1 74,0 a 37,37 0 1,1 -74,0" fill="transparent" />
                  <text className="fill-neutral-500 text-[10px] uppercase tracking-widest font-mono">
                    <textPath href="#circlePath">
                      • Rave Culture • Community • Live Events
                    </textPath>
                  </text>
                </svg>
              </div>
            </div>
          </motion.div>

        </div>
      </div>

      {/* 底部渐变过渡层 */}
      <div className="absolute bottom-0 left-0 right-0 h-96 pointer-events-none">
        {/* 主渐变 - 黑色到透明 */}
        <div className="absolute inset-0 bg-gradient-to-b from-transparent via-black/60 to-black/30" />

        {/* 与产品介绍区衔接的低饱和光晕 */}
        <div className="absolute inset-0 bg-gradient-to-b from-transparent via-neutral-950/20 to-neutral-950/50" />

        {/* 底部强化黑色 */}
        <div className="absolute bottom-0 left-0 right-0 h-32 bg-gradient-to-b from-transparent to-black/80" />
      </div>

      {/* 底部下拉箭头 */}
      <motion.button
        onClick={() => {
          const downloadSection = document.getElementById('download');
          if (downloadSection) {
            downloadSection.scrollIntoView({ behavior: 'auto' });
          }
        }}
        initial={{ opacity: 0 }}
        whileInView={{ opacity: 1 }}
        viewport={{ once: false }}
        transition={{ duration: 1 }}
        className="absolute bottom-8 left-1/2 z-10 hidden -translate-x-1/2 cursor-pointer flex-col items-center gap-2 md:flex"
      >
        <motion.div
          animate={{ y: [0, 10, 0] }}
          transition={{ duration: 2, repeat: Infinity, ease: "easeInOut" }}
        >
          <ChevronDown className="w-8 h-8 text-white/70 hover:text-white transition-colors" strokeWidth={1.5} />
        </motion.div>
      </motion.button>
    </section>
  );
};
