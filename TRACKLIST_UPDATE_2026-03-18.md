# Tracklist 功能更新说明

## 最新改进 (2026-03-18)

### 1. 优化界面布局
- ✅ **压缩行高**：每个 tracklist 卡片的高度从 4rem 减少到 3rem，更紧凑
- ✅ **减少内边距**：从 p-4 改为 p-3，footer 从 py-4 改为 py-3
- ✅ **头像尺寸**：从 14x14 减少到 10x10，更节省空间
- ✅ **字体大小**：标题从 text-lg 改为 text-base，信息从 text-sm 改为 text-xs

### 2. 默认 Tracklist 显示贡献者
- ✅ 默认 Tracklist 现在显示视频上传者的信息
- ✅ 显示上传者的头像和昵称
- ✅ 不再显示"系统默认"，而是显示实际的贡献者

### 3. ID 一键复制功能
- ✅ 每个 tracklist 的 ID 按钮可以点击复制完整 ID
- ✅ 点击后显示"✓ 已复制"提示，2秒后恢复
- ✅ 默认 tracklist 的 ID 是 "default"
- ✅ 用户 tracklist 显示前 8 位 ID，点击复制完整 ID

### 4. 分享功能
- ✅ 每个 tracklist 都有分享按钮（分享图标）
- ✅ 点击后自动复制分享文本到剪贴板
- ✅ 分享文本包含：
  - DJ Set 标题
  - Tracklist 名称
  - 贡献者信息
  - 歌曲数量
  - Tracklist ID
  - 详细的使用步骤

### 5. 分享文本格式示例

```
🎵 Martin Garrix - Tomorrowland 2024

📝 Tracklist: 我的完整版本
👤 贡献者: 张三
🎼 歌曲数: 25 首
🆔 ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890

🔍 如何使用：
1. 访问 https://yoursite.com
2. 打开这个 DJ Set
3. 点击歌单区域的 Tracklist 选择按钮
4. 在搜索框输入 ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890
5. 选择对应的 Tracklist 即可

✨ 快来体验不同版本的 Tracklist 吧！
```

## 界面对比

### 优化前
```
┌────────────────────────────────────────────┐
│  👤  我的完整版本                    [当前] │  ← 高度较大
│      上传者：张三 • 18 首歌曲              │
│      上传时间：2026年3月17日               │
│                          ID: a1b2c3d4...   │
└────────────────────────────────────────────┘
```

### 优化后
```
┌────────────────────────────────────────────┐
│ 👤 我的完整版本 [当前]                     │  ← 高度更紧凑
│    张三 • 18 首 • 2026年3月17日            │
│                    [a1b2c3d4...] [分享]    │
└────────────────────────────────────────────┘
```

## 功能特点

### ID 复制
- 点击 ID 按钮即可复制完整 ID
- 复制成功后显示绿色勾号
- 2 秒后自动恢复原状态
- 支持搜索时使用完整 ID

### 分享功能
- 类似淘宝/拼多多的分享文本
- 包含完整的使用说明
- 一键复制到剪贴板
- 方便分享给朋友

### 视觉优化
- 更紧凑的布局，可以显示更多内容
- 保持清晰易读
- 响应式设计不变
- 所有功能按钮都有 hover 效果

## 使用示例

### 1. 复制 Tracklist ID
1. 打开 Tracklist 选择窗口
2. 找到想要分享的 tracklist
3. 点击 ID 按钮（如 "a1b2c3d4..."）
4. ID 已复制到剪贴板
5. 可以分享给朋友，让���们搜索

### 2. 分享 Tracklist
1. 打开 Tracklist 选择窗口
2. 找到想要分享的 tracklist
3. 点击分享按钮（分享图标）
4. 分享文本已复制到剪贴板
5. 粘贴到微信/QQ/Discord 等平台

### 3. 使用分享的 ID
1. 收到朋友分享的 ID
2. 打开对应的 DJ Set
3. 点击 Tracklist 选择按钮
4. 在搜索框粘贴 ID
5. 选择匹配的 tracklist

## 技术实现

### 复制功能
```typescript
const copyToClipboard = async (text: string, type: 'id' | 'share', id: string) => {
  try {
    await navigator.clipboard.writeText(text);
    if (type === 'id') {
      setCopiedId(id);
      setTimeout(() => setCopiedId(null), 2000);
    } else {
      setCopiedShare(id);
      setTimeout(() => setCopiedShare(null), 2000);
    }
  } catch (error) {
    console.error('Failed to copy:', error);
  }
};
```

### 分享文本生成
```typescript
const generateShareText = (tracklist: Tracklist | null, isDefault: boolean) => {
  const baseUrl = typeof window !== 'undefined' ? window.location.origin : '';
  // ... 生成包含所有信息的分享文本
  return shareText;
};
```

## 兼容性
- ✅ 支持所有现代浏览器
- ✅ 需要 HTTPS 才能使用剪贴板 API
- ✅ 移动端完全支持
- ✅ 复制失败时会在控制台显示错误

## 注意事项
- 剪贴板 API 需要用户交互触发
- 在 HTTP 环境下可能无法使用复制功能
- 建议在 HTTPS 环境下使用
- 分享文本会自动包含当前网站的 URL
