import React from 'react';

interface ToastProps {
  message: string;
  type?: 'success' | 'error' | 'info';
  onClose: () => void;
}

export const Toast: React.FC<ToastProps> = ({ message, type = 'success', onClose }) => {
  const bgColor = {
    success: 'bg-accent-green/20 border-accent-green text-accent-green',
    error: 'bg-red-500/20 border-red-500 text-red-500',
    info: 'bg-primary-blue/20 border-primary-blue text-primary-blue',
  };

  const icon = {
    success: '✅',
    error: '❌',
    info: 'ℹ️',
  };

  return (
    <div className={`fixed top-4 right-4 z-50 ${bgColor[type]} border rounded-lg px-6 py-4 shadow-glow animate-slide-in`}>
      <div className="flex items-center gap-3">
        <span className="text-2xl">{icon[type]}</span>
        <p className="font-medium">{message}</p>
        <button
          onClick={onClose}
          className="ml-4 hover:opacity-70 transition-opacity"
        >
          ✕
        </button>
      </div>
    </div>
  );
};
