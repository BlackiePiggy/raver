/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        // 主色调
        'primary-purple': '#8B5CF6',
        'primary-blue': '#3B82F6',
        'accent-green': '#10B981',
        'accent-pink': '#EC4899',
        'accent-cyan': '#06B6D4',

        // 背景色 - 苹果风格
        'bg-primary': '#000000',
        'bg-secondary': '#0a0a0a',
        'bg-tertiary': '#161616',
        'bg-elevated': '#1d1d1f',
        'bg-glass': 'rgba(29, 29, 31, 0.72)',

        // 文字色
        'text-primary': '#f5f5f7',
        'text-secondary': '#a1a1a6',
        'text-tertiary': '#6e6e73',
        'text-disabled': '#525252',

        // 边框色
        'border-primary': '#424245',
        'border-secondary': '#2c2c2e',
      },
      fontFamily: {
        sans: ['-apple-system', 'BlinkMacSystemFont', 'SF Pro Display', 'Inter', 'system-ui', 'sans-serif'],
        display: ['SF Pro Display', 'Poppins', 'Inter', 'sans-serif'],
        mono: ['SF Mono', 'JetBrains Mono', 'Fira Code', 'monospace'],
      },
      backdropBlur: {
        'xs': '2px',
        'apple': '20px',
      },
      boxShadow: {
        'glow': '0 0 20px rgba(139, 92, 246, 0.5)',
        'glow-lg': '0 0 30px rgba(139, 92, 246, 0.6)',
        'glow-blue': '0 0 20px rgba(59, 130, 246, 0.5)',
        'apple': '0 4px 16px rgba(0, 0, 0, 0.3)',
        'apple-lg': '0 8px 32px rgba(0, 0, 0, 0.4)',
      },
      animation: {
        'fade-in': 'fadeIn 0.8s ease-out',
        'slide-up': 'slideUp 0.8s ease-out',
        'scale-in': 'scaleIn 0.6s ease-out',
        'music-bar-1': 'music-bar-1 0.8s ease-in-out infinite',
        'music-bar-2': 'music-bar-2 0.9s ease-in-out infinite',
        'music-bar-3': 'music-bar-3 0.7s ease-in-out infinite',
        'music-bar-4': 'music-bar-4 1s ease-in-out infinite',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { transform: 'translateY(40px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        scaleIn: {
          '0%': { transform: 'scale(0.95)', opacity: '0' },
          '100%': { transform: 'scale(1)', opacity: '1' },
        },
        'music-bar-1': {
          '0%, 100%': { height: '40%' },
          '50%': { height: '100%' },
        },
        'music-bar-2': {
          '0%, 100%': { height: '70%' },
          '50%': { height: '30%' },
        },
        'music-bar-3': {
          '0%, 100%': { height: '50%' },
          '50%': { height: '90%' },
        },
        'music-bar-4': {
          '0%, 100%': { height: '80%' },
          '50%': { height: '40%' },
        },
      },
      fontSize: {
        'display': ['80px', { lineHeight: '1.05', letterSpacing: '-0.015em', fontWeight: '600' }],
        'display-sm': ['56px', { lineHeight: '1.07', letterSpacing: '-0.015em', fontWeight: '600' }],
      },
    },
  },
  plugins: [],
}
