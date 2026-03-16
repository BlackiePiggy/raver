# Raver 设计系统

## 色彩系统

### 主色调
```css
--primary-purple: #8B5CF6;      /* 深紫色 - 主要CTA */
--primary-blue: #3B82F6;        /* 电蓝色 - 链接、次要CTA */
--accent-green: #10B981;        /* 荧光绿 - 成功、在线状态 */
--accent-pink: #EC4899;         /* 荧光粉 - 特殊标记、热门 */
--accent-cyan: #06B6D4;         /* 青色 - 信息提示 */
```

### 背景色
```css
--bg-primary: #0F0F0F;          /* 主背景 */
--bg-secondary: #1A1A1A;        /* 卡片背景 */
--bg-tertiary: #262626;         /* 悬停状态 */
--bg-elevated: #2D2D2D;         /* 弹窗、模态框 */
```

### 文字色
```css
--text-primary: #FFFFFF;        /* 主要文字 */
--text-secondary: #E5E5E5;      /* 次要文字 */
--text-tertiary: #A3A3A3;       /* 辅助文字 */
--text-disabled: #525252;       /* 禁用文字 */
```

### 边框与分割线
```css
--border-primary: #404040;      /* 主要边框 */
--border-secondary: #2D2D2D;    /* 次要边框 */
--divider: #262626;             /* 分割线 */
```

## 字体系统

### 字体家族
```css
--font-sans: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
--font-display: 'Poppins', 'Inter', sans-serif;  /* 标题用 */
--font-mono: 'JetBrains Mono', 'Fira Code', monospace;
```

### 字体大小
```css
--text-xs: 0.75rem;      /* 12px - 标签、辅助信息 */
--text-sm: 0.875rem;     /* 14px - 正文小字 */
--text-base: 1rem;       /* 16px - 正文 */
--text-lg: 1.125rem;     /* 18px - 小标题 */
--text-xl: 1.25rem;      /* 20px - 卡片标题 */
--text-2xl: 1.5rem;      /* 24px - 页面标题 */
--text-3xl: 1.875rem;    /* 30px - 大标题 */
--text-4xl: 2.25rem;     /* 36px - Hero标题 */
```

### 字重
```css
--font-normal: 400;
--font-medium: 500;
--font-semibold: 600;
--font-bold: 700;
```

## 间距系统
```css
--space-1: 0.25rem;   /* 4px */
--space-2: 0.5rem;    /* 8px */
--space-3: 0.75rem;   /* 12px */
--space-4: 1rem;      /* 16px */
--space-5: 1.25rem;   /* 20px */
--space-6: 1.5rem;    /* 24px */
--space-8: 2rem;      /* 32px */
--space-10: 2.5rem;   /* 40px */
--space-12: 3rem;     /* 48px */
--space-16: 4rem;     /* 64px */
```

## 圆角系统
```css
--radius-sm: 0.375rem;   /* 6px - 小按钮、标签 */
--radius-md: 0.5rem;     /* 8px - 按钮、输入框 */
--radius-lg: 0.75rem;    /* 12px - 卡片 */
--radius-xl: 1rem;       /* 16px - 大卡片 */
--radius-2xl: 1.5rem;    /* 24px - 模态框 */
--radius-full: 9999px;   /* 圆形 */
```

## 阴影系统
```css
--shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.5);
--shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.5);
--shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.5);
--shadow-xl: 0 20px 25px -5px rgba(0, 0, 0, 0.5);
--shadow-glow: 0 0 20px rgba(139, 92, 246, 0.4);  /* 发光效果 */
```

## 组件样式

### 按钮
```tsx
// Primary Button
className="bg-primary-purple hover:bg-purple-600 text-white px-6 py-3 rounded-lg
           font-medium transition-all duration-200 hover:shadow-glow"

// Secondary Button
className="bg-bg-tertiary hover:bg-bg-elevated text-text-primary px-6 py-3 rounded-lg
           font-medium transition-all duration-200 border border-border-primary"

// Ghost Button
className="text-primary-blue hover:bg-bg-tertiary px-6 py-3 rounded-lg
           font-medium transition-all duration-200"
```

### 卡片
```tsx
className="bg-bg-secondary rounded-xl p-6 border border-border-secondary
           hover:border-border-primary transition-all duration-200
           hover:shadow-lg"
```

### 输入框
```tsx
className="bg-bg-tertiary border border-border-primary rounded-lg px-4 py-3
           text-text-primary placeholder:text-text-tertiary
           focus:border-primary-purple focus:ring-2 focus:ring-primary-purple/20
           transition-all duration-200"
```

### 标签/徽章
```tsx
// DJ粉丝牌
className="bg-gradient-to-r from-primary-purple to-primary-blue
           text-white px-3 py-1 rounded-full text-xs font-semibold"

// 风格标签
className="bg-bg-tertiary text-accent-cyan px-3 py-1 rounded-full
           text-xs font-medium border border-accent-cyan/30"
```

## 动画效果

### 过渡时间
```css
--transition-fast: 150ms;
--transition-base: 200ms;
--transition-slow: 300ms;
```

### 常用动画
```css
/* 淡入 */
@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

/* 滑入 */
@keyframes slideUp {
  from { transform: translateY(20px); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}

/* 发光脉冲 */
@keyframes glow {
  0%, 100% { box-shadow: 0 0 20px rgba(139, 92, 246, 0.4); }
  50% { box-shadow: 0 0 30px rgba(139, 92, 246, 0.6); }
}
```

## 布局规范

### 容器宽度
```css
--container-sm: 640px;
--container-md: 768px;
--container-lg: 1024px;
--container-xl: 1280px;
--container-2xl: 1536px;
```

### 响应式断点
```css
--breakpoint-sm: 640px;
--breakpoint-md: 768px;
--breakpoint-lg: 1024px;
--breakpoint-xl: 1280px;
--breakpoint-2xl: 1536px;
```

## 图标系统
推荐使用: **Lucide Icons** 或 **Heroicons**
- 统一使用24px尺寸
- 线条粗细: 2px (stroke-width)
- 颜色跟随文字色

## 图片规范
- **头像**: 正方形, 最小200x200px
- **活动封面**: 16:9, 最小1280x720px
- **DJ照片**: 4:3, 最小800x600px
- **格式**: WebP优先, 降级JPEG/PNG
- **压缩**: 质量80-85%

## 可访问性
- 对比度: 至少4.5:1 (WCAG AA)
- 焦点状态: 明显的focus ring
- 键盘导航: 支持Tab/Enter/Esc
- 屏幕阅读器: 语义化HTML + ARIA标签
