import React, { InputHTMLAttributes } from 'react';

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
}

export const Input: React.FC<InputProps> = ({
  label,
  error,
  className = '',
  ...props
}) => {
  return (
    <div className="w-full">
      {label && (
        <label className="block text-sm font-medium text-text-secondary mb-2">
          {label}
        </label>
      )}
      <input
        className={`w-full px-4 py-3 bg-bg-elevated border ${
          error ? 'border-red-500' : 'border-border-secondary'
        } rounded-xl text-text-primary placeholder-text-tertiary focus:outline-none focus:border-primary-blue focus:ring-2 focus:ring-primary-blue/20 transition-all duration-300 ${className}`}
        {...props}
      />
      {error && (
        <p className="mt-2 text-sm text-red-500">{error}</p>
      )}
    </div>
  );
};
