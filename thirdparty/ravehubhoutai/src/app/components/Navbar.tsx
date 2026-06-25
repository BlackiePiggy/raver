import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Menu, X, ChevronDown } from 'lucide-react';
import { Link, useLocation } from '../router';

export const Navbar = () => {
  const [isOpen, setIsOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 50);
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  // Close mobile menu on route change
  const [location] = useLocation();
  useEffect(() => {
    setIsOpen(false);
    setMenuOpen(false);
  }, [location]);

  const navItems = [
    { name: 'Download', to: '/#download' }
  ];

  const collapsibleItems = [
    { name: 'About', to: '/#about' },
    { name: 'Services', to: '/#services' },
    { name: 'Contact', to: '/#contact' }
  ];

  return (
    <motion.nav
      initial={{ y: -100 }}
      animate={{ y: 0 }}
      className={`fixed w-full z-50 transition-all duration-300 ${
        scrolled ? 'bg-neutral-950/80 backdrop-blur-md py-4 border-b border-white/5' : 'py-8 bg-transparent'
      }`}
    >
      <div className="container mx-auto px-6 flex justify-between items-center">
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
        >
          <Link to="/" className="text-2xl font-bold tracking-tighter mix-blend-difference z-50">
            Ravehub
          </Link>
        </motion.div>

        {/* Desktop Menu */}
        <div className="hidden md:flex gap-8 items-center">
          {navItems.map((item, i) => (
            <motion.div
              key={item.name}
              initial={{ opacity: 0, y: -20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: i * 0.1 }}
            >
              <Link
                to={item.to}
                className="text-sm uppercase tracking-widest hover:text-white/70 transition-colors relative group"
              >
                {item.name}
                <span className="absolute -bottom-1 left-0 w-0 h-px bg-white transition-all group-hover:w-full" />
              </Link>
            </motion.div>
          ))}
          
          {/* Collapsible Menu */}
          <motion.div
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.1 }}
            className="relative"
          >
            <button
              onClick={() => setMenuOpen(!menuOpen)}
              className="text-sm uppercase tracking-widest hover:text-white/70 transition-colors relative group flex items-center gap-2"
            >
              Menu
              <ChevronDown className={`w-4 h-4 transition-transform ${menuOpen ? 'rotate-180' : ''}`} />
            </button>
            
            <AnimatePresence>
              {menuOpen && (
                <motion.div
                  initial={{ opacity: 0, y: -10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -10 }}
                  transition={{ duration: 0.2 }}
                  className="absolute top-full right-0 mt-4 bg-neutral-900/95 backdrop-blur-md border border-white/10 rounded-lg overflow-hidden min-w-[200px]"
                >
                  {collapsibleItems.map((item) => (
                    <Link
                      key={item.name}
                      to={item.to}
                      className="block px-6 py-3 text-sm uppercase tracking-widest hover:bg-white/5 transition-colors border-b border-white/5 last:border-0"
                    >
                      {item.name}
                    </Link>
                  ))}
                </motion.div>
              )}
            </AnimatePresence>
          </motion.div>
        </div>

        {/* Mobile Toggle */}
        <button 
          onClick={() => setIsOpen(!isOpen)}
          className="md:hidden z-50 text-white"
        >
          {isOpen ? <X /> : <Menu />}
        </button>

        {/* Mobile Menu */}
        <AnimatePresence>
          {isOpen && (
            <motion.div
              initial={{ opacity: 0, x: '100%' }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: '100%' }}
              transition={{ type: "tween", duration: 0.4 }}
              className="fixed inset-0 bg-neutral-950 flex flex-col items-center justify-center gap-8 md:hidden"
            >
              {navItems.map((item) => (
                <Link
                  key={item.name}
                  to={item.to}
                  className="text-4xl font-medium tracking-tight hover:text-neutral-500 transition-colors"
                >
                  {item.name}
                </Link>
              ))}
              
              <div className="w-32 h-px bg-white/10 my-4" />
              
              {collapsibleItems.map((item) => (
                <Link
                  key={item.name}
                  to={item.to}
                  className="text-2xl font-light tracking-tight hover:text-neutral-500 transition-colors"
                >
                  {item.name}
                </Link>
              ))}
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </motion.nav>
  );
};