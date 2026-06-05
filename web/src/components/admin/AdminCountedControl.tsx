'use client';

import { cloneElement, isValidElement, type ReactElement } from 'react';

type CountedChildProps = {
  className?: string;
};

type AdminCountedControlProps = {
  children: ReactElement<CountedChildProps>;
  count: number;
  maxLength?: number;
  multiline?: boolean;
};

export default function AdminCountedControl({
  children,
  count,
  maxLength,
  multiline = false,
}: AdminCountedControlProps) {
  if (!isValidElement(children)) {
    return children;
  }

  const nextClassName = [
    children.props.className || '',
    'admin-studio-counted-control',
    multiline ? 'is-textarea' : '',
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <div className={`admin-studio-counted-shell ${multiline ? 'is-textarea' : ''}`}>
      {cloneElement(children, {
        className: nextClassName,
      })}
      {typeof maxLength === 'number' ? (
        <span className={`admin-studio-counted-badge ${multiline ? 'is-textarea' : ''}`} aria-hidden="true">
          {count}/{maxLength}
        </span>
      ) : null}
    </div>
  );
}
