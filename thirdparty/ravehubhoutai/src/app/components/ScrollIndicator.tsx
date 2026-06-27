import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';

interface Section {
  id: string;
  label: string;
}

const sections: Section[] = [
  { id: 'hero', label: 'Home' },
  { id: 'services', label: 'Services' },
  { id: 'community', label: 'Community' },
  { id: 'about', label: 'About' },
  { id: 'download', label: 'Download' },
  { id: 'contact', label: 'Contact' }
];

export const ScrollIndicator = () => {
  const [activeSection, setActiveSection] = useState('hero');
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setIsVisible(window.scrollY > 200);

      const scrollPosition = window.scrollY + window.innerHeight / 2;

      for (let i = sections.length - 1; i >= 0; i--) {
        const section = document.getElementById(sections[i].id);
        if (section && section.offsetTop <= scrollPosition) {
          setActiveSection(sections[i].id);
          break;
        }
      }
    };

    window.addEventListener('scroll', handleScroll);
    handleScroll();

    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const scrollToSection = (id: string) => {
    const element = document.getElementById(id);
    if (element) {
      element.scrollIntoView({ behavior: 'auto' });
    } else if (id === 'hero') {
      window.scrollTo({ top: 0, behavior: 'auto' });
    }
  };

  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          initial={{ opacity: 0, x: 50 }}
          animate={{ opacity: 1, x: 0 }}
          exit={{ opacity: 0, x: 50 }}
          transition={{ duration: 0.3 }}
          className="fixed right-8 top-1/2 -translate-y-1/2 z-40 hidden lg:block"
        >
          <div className="flex flex-col gap-6">
            {sections.map((section) => {
              const isActive = activeSection === section.id;

              return (
                <motion.button
                  key={section.id}
                  onClick={() => scrollToSection(section.id)}
                  className="group relative flex items-center justify-end gap-4"
                  whileHover={{ scale: 1.1 }}
                  whileTap={{ scale: 0.95 }}
                >
                  <motion.span
                    initial={{ opacity: 0, x: 10 }}
                    whileHover={{ opacity: 1, x: 0 }}
                    className="absolute right-full mr-4 text-xs uppercase tracking-widest text-white/70 font-mono whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity"
                  >
                    {section.label}
                  </motion.span>

                  <div className="relative w-3 h-3">
                    <div
                      className={`absolute inset-0 rounded-full border transition-all duration-300 ${
                        isActive
                          ? 'border-white border-2'
                          : 'border-white/30 border group-hover:border-white/50'
                      }`}
                    />

                    <motion.div
                      initial={false}
                      animate={{
                        scale: isActive ? 1 : 0,
                        opacity: isActive ? 1 : 0
                      }}
                      transition={{ duration: 0.2 }}
                      className="absolute inset-[3px] rounded-full bg-white"
                    />

                    {isActive && (
                      <motion.div
                        initial={{ scale: 1, opacity: 0.5 }}
                        animate={{ scale: 2, opacity: 0 }}
                        transition={{
                          duration: 1.5,
                          repeat: Infinity,
                          ease: 'easeOut'
                        }}
                        className="absolute inset-0 rounded-full border-2 border-white"
                      />
                    )}
                  </div>
                </motion.button>
              );
            })}
          </div>

          <div className="absolute top-0 bottom-0 right-[5px] w-[1px] bg-white/10 -z-10" />
        </motion.div>
      )}
    </AnimatePresence>
  );
};
