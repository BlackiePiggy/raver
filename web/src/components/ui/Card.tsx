import React from 'react';

interface CardProps {
  children: React.ReactNode;
  className?: string;
}

export const Card: React.FC<CardProps> = ({ children, className = '' }) => {
  return (
    <div className={`bg-bg-elevated rounded-2xl p-6 border border-border-secondary hover:border-border-primary transition-all duration-300 shadow-apple ${className}`}>
      {children}
    </div>
  );
};
