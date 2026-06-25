import React, { useEffect, useState } from 'react';
import {
  AlertTriangle,
  ArrowDown,
  ArrowUp,
  CheckCircle2,
  Copy,
  Download,
  Image as ImageIcon,
  Monitor,
  Plus,
  RefreshCcw,
  Save,
  Smartphone,
  Trash2,
  Upload,
  Video,
} from 'lucide-react';
import {
  defaultCapabilities,
  loadCapabilities,
  normalizeCapabilities,
  resetCapabilities,
  saveCapabilities,
  type Capability,
  type CapabilityDisplayMode,
  type CapabilityMediaType,
} from '../data/capabilities';
import { media } from '../data/media';

type PreviewMode = 'mobile' | 'web';

type MediaCheck = {
  status: 'idle' | 'checking' | 'ok' | 'warning' | 'error';
  sizeBytes: number | null;
  note: string;
};

const maxImageBytes = 2 * 1024 * 1024;
const maxVideoBytes = 12 * 1024 * 1024;

const fieldClass = 'w-full rounded-md border border-white/10 bg-neutral-950/90 px-3 py-2.5 text-sm text-white outline-none transition placeholder:text-neutral-600 focus:border-cyan-300/70 focus:bg-neutral-950';
const labelClass = 'mb-2 block text-[0.68rem] font-medium uppercase tracking-[0.18em] text-neutral-500';
const iconButtonClass = 'inline-flex h-10 w-10 items-center justify-center rounded-md border border-white/10 bg-white/[0.04] text-neutral-300 transition hover:border-white/25 hover:bg-white/[0.08] disabled:cursor-not-allowed disabled:opacity-35';
const textButtonClass = 'inline-flex min-h-10 items-center justify-center gap-2 rounded-md border border-white/10 bg-white/[0.05] px-3 py-2 text-sm text-neutral-200 transition hover:border-white/25 hover:bg-white/[0.09] disabled:cursor-not-allowed disabled:opacity-35';
const panelClass = 'rounded-lg border border-white/10 bg-neutral-900/78 shadow-[0_20px_80px_rgba(0,0,0,0.32)]';

const formatBytes = (bytes: number | null) => {
  if (bytes === null) return '未知';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(2)} MB`;
};

const getLimitBytes = (type: CapabilityMediaType) => (
  type === 'video' ? maxVideoBytes : maxImageBytes
);

const getLimitLabel = (type: CapabilityMediaType) => (
  type === 'video' ? '视频建议不超过 12 MB' : '图片建议不超过 2 MB'
);

const getPhoneFrameDropShadow = (glowColor: string) => [
  'drop-shadow(0 24px 42px rgba(0,0,0,0.58))',
  `drop-shadow(0 0 14px ${glowColor})`,
  `drop-shadow(0 0 32px ${glowColor})`,
].join(' ');

const VideoLoadingOverlay = () => (
  <div className="pointer-events-none absolute inset-0 z-10 flex flex-col items-center justify-center gap-3 bg-black/55 text-white backdrop-blur-[2px]">
    <div className="h-8 w-8 rounded-full border-2 border-white/25 border-t-white animate-spin" />
    <span className="text-[0.65rem] font-mono uppercase tracking-[0.22em] text-white/80">视频加载中</span>
  </div>
);

const PreviewVideo = ({ src }: { src: string }) => {
  const [loading, setLoading] = useState(true);

  return (
    <>
      <video
        src={src}
        className="h-full w-full object-cover"
        controls
        muted
        playsInline
        preload="metadata"
        onLoadStart={() => setLoading(true)}
        onWaiting={() => setLoading(true)}
        onStalled={() => setLoading(true)}
        onCanPlay={() => setLoading(false)}
        onLoadedData={() => setLoading(false)}
        onPlaying={() => setLoading(false)}
      />
      {loading && <VideoLoadingOverlay />}
    </>
  );
};

const getMediaCheck = async (url: string, type: CapabilityMediaType): Promise<MediaCheck> => {
  if (!url.trim()) {
    return { status: 'idle', sizeBytes: null, note: '尚未设置媒体链接。' };
  }

  try {
    new URL(url);
  } catch {
    return { status: 'error', sizeBytes: null, note: '媒体链接不是有效 URL。' };
  }

  try {
    const response = await fetch(url, { method: 'HEAD' });
    const size = Number(response.headers.get('content-length'));
    const sizeBytes = Number.isFinite(size) && size > 0 ? size : null;

    if (!response.ok) {
      return { status: 'error', sizeBytes, note: `资源请求失败，状态码 ${response.status}。` };
    }

    if (sizeBytes !== null && sizeBytes > getLimitBytes(type)) {
      return {
        status: 'error',
        sizeBytes,
        note: `${type === 'video' ? '视频' : '图片'}过大，当前 ${formatBytes(sizeBytes)}，上限 ${formatBytes(getLimitBytes(type))}。`,
      };
    }

    return {
      status: 'ok',
      sizeBytes,
      note: sizeBytes === null ? '资源可访问，但服务器没有返回文件大小。' : `资源大小 ${formatBytes(sizeBytes)}，符合限制。`,
    };
  } catch {
    return {
      status: 'warning',
      sizeBytes: null,
      note: '浏览器无法读取文件大小，通常是 OSS CORS 未开放 HEAD；预览能正常加载时仍可使用。',
    };
  }
};

const createCapability = (index: number): Capability => ({
  id: String(index + 1).padStart(2, '0'),
  title: '新增功能展示',
  description: '在这里填写功能说明。',
  accent: ['#06b6d4', '#14b8a6', '#10b981'],
  glowColor: 'rgba(6,182,212,0.4)',
  appScreen: '',
  appScreenType: 'image',
  displayMode: 'phone',
  galleryImages: [],
});

const swapItems = (items: Capability[], from: number, to: number) => {
  const next = [...items];
  const temp = next[from];
  next[from] = next[to];
  next[to] = temp;
  return next;
};

const getGalleryImages = (item: Capability) => (
  item.galleryImages.length > 0
    ? item.galleryImages
    : item.appScreen
      ? [item.appScreen]
      : []
);

const parseGalleryImages = (value: string) => (
  value
    .split(/\n|,/)
    .map((line) => line.trim())
    .filter(Boolean)
);

const MediaPreview = ({
  item,
  mode,
  onModeChange,
  mediaCheck,
}: {
  item: Capability;
  mode: PreviewMode;
  onModeChange: (mode: PreviewMode) => void;
  mediaCheck: MediaCheck;
}) => {
  const [a, b] = item.accent;
  const isVideo = item.appScreenType === 'video';
  const isGallery = item.displayMode === 'gallery';
  const galleryImages = getGalleryImages(item).slice(0, 8);
  const icon = mediaCheck.status === 'ok'
    ? <CheckCircle2 className="h-4 w-4 text-emerald-300" />
    : <AlertTriangle className="h-4 w-4 text-amber-300" />;

  const mediaNode = item.appScreen ? (
    isVideo ? (
      <PreviewVideo src={item.appScreen} />
    ) : (
      <img
        src={item.appScreen}
        alt={item.title}
        className="h-full w-full object-cover"
        loading="lazy"
        decoding="async"
      />
    )
  ) : (
    <div className="flex h-full w-full items-center justify-center px-8 text-center text-sm text-neutral-500">
      尚未设置图片或视频链接
    </div>
  );

  const phonePreview = (
    <div className="relative mx-auto w-full max-w-[18rem]">
      <div
        className="pointer-events-none absolute -inset-6 rounded-[3rem] blur-3xl opacity-35"
        style={{ background: `radial-gradient(ellipse, ${a}99, transparent 70%)` }}
      />
      <div className="relative" style={{ aspectRatio: '1403 / 2862' }}>
        <div
            className="absolute overflow-hidden bg-black"
          style={{
            inset: '2.5% 5.1% 2.3%',
            borderRadius: '12% / 5.7%',
          }}
        >
          {mediaNode}
        </div>
        <div
          className="pointer-events-none absolute"
          style={{
            inset: '2.5% 5.1% 2.3%',
            borderRadius: '12% / 5.7%',
            boxShadow: 'inset 0 0 34px rgba(255,255,255,0.08), inset 0 0 18px rgba(0,0,0,0.24)',
          }}
        />
        <img
          src={media.frames.iphone16ProPortrait}
          alt=""
          aria-hidden="true"
          loading="lazy"
          decoding="async"
          className="pointer-events-none absolute inset-0 z-20 h-full w-full select-none"
          style={{ filter: getPhoneFrameDropShadow(`${a}88`) }}
        />
        <div className="pointer-events-none absolute inset-x-[9%] top-[1.1%] z-30 h-[2.8%] rounded-full bg-white/20 opacity-45 blur-md" />
      </div>
    </div>
  );

  const galleryPreview = (
    <div
      className="mx-auto w-full max-w-[34rem] overflow-hidden rounded-xl border border-white/10 bg-neutral-950/80 p-2"
      style={{ boxShadow: `0 0 48px ${item.glowColor}` }}
    >
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
        {galleryImages.length > 0 ? galleryImages.map((src, index) => (
          <figure key={src} className="overflow-hidden rounded-lg border border-white/10 bg-black">
            <img
              src={src}
              alt={`${item.title} ${index + 1}`}
              loading="lazy"
              decoding="async"
              className="aspect-[16/10] h-full w-full object-cover"
            />
          </figure>
        )) : (
          <div className="col-span-full flex aspect-[16/10] items-center justify-center px-8 text-center text-sm text-neutral-500">
            尚未设置画廊图片链接
          </div>
        )}
      </div>
    </div>
  );

  return (
    <aside className={`${panelClass} overflow-hidden`}>
      <div className="border-b border-white/10 p-4 md:p-5">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <p className="text-[0.68rem] uppercase tracking-[0.2em] text-neutral-500">Preview</p>
            <h3 className="mt-1 text-lg font-semibold">展示预览</h3>
            <p className="mt-2 max-w-sm text-sm leading-6 text-neutral-400">
              媒体容器已固定比例和最大尺寸，桌面与移动端都不会被资源原始尺寸撑开。
            </p>
          </div>

          <div className="inline-grid grid-cols-2 rounded-md border border-white/10 bg-neutral-950 p-1">
            <button
              type="button"
              onClick={() => onModeChange('mobile')}
              className={`inline-flex h-9 items-center justify-center gap-2 rounded px-3 text-sm transition ${mode === 'mobile' ? 'bg-white text-neutral-950' : 'text-neutral-400 hover:text-white'}`}
            >
              <Smartphone className="h-4 w-4" />
              移动
            </button>
            <button
              type="button"
              onClick={() => onModeChange('web')}
              className={`inline-flex h-9 items-center justify-center gap-2 rounded px-3 text-sm transition ${mode === 'web' ? 'bg-white text-neutral-950' : 'text-neutral-400 hover:text-white'}`}
            >
              <Monitor className="h-4 w-4" />
              Web
            </button>
          </div>
        </div>
      </div>

      <div className="p-4 md:p-5">
        {isGallery ? (
          galleryPreview
        ) : mode === 'mobile' ? (
          <div className="mx-auto flex max-h-[36rem] justify-center overflow-visible py-2">
            {phonePreview}
          </div>
        ) : (
          <div
            className="mx-auto max-h-[25rem] w-full max-w-[34rem] overflow-hidden rounded-xl border border-white/10 bg-black p-2 transition-all"
            style={{ boxShadow: `0 0 48px ${item.glowColor}` }}
          >
            <div className="relative aspect-[16/10] overflow-hidden rounded-lg bg-neutral-950">
              {mediaNode}
            </div>
          </div>
        )}

        <div className="mt-5 rounded-lg border border-white/10 bg-neutral-950/80 p-4">
          <div className="flex items-start gap-3">
            {icon}
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2">
                <span className="rounded-full border border-white/10 px-2 py-0.5 text-xs text-neutral-400">
                  {isGallery ? 'gallery' : isVideo ? 'video' : 'image'}
                </span>
                <span className="rounded-full border border-white/10 px-2 py-0.5 text-xs text-neutral-400">
                  {formatBytes(mediaCheck.sizeBytes)}
                </span>
                <span className="rounded-full border border-white/10 px-2 py-0.5 text-xs text-neutral-400">
                  {isGallery ? '最多展示 8 张横向图' : getLimitLabel(item.appScreenType)}
                </span>
              </div>
              <p className="mt-3 break-words text-sm leading-6 text-neutral-300">{mediaCheck.note}</p>
              <p className="mt-2 break-all text-xs leading-5 text-neutral-500">{item.appScreen || '未设置链接'}</p>
            </div>
          </div>
        </div>

        <div className="mt-5 rounded-lg border border-white/10 p-4" style={{ background: `linear-gradient(135deg, ${a}18, ${b}10)` }}>
          <p className="font-mono text-xs text-neutral-400">{item.id || '00'} / CAPABILITY</p>
          <h4 className="mt-2 text-lg font-semibold text-white">{item.title || '未命名模块'}</h4>
          <p className="mt-2 line-clamp-4 text-sm leading-6 text-neutral-300">{item.description || '暂无描述'}</p>
        </div>
      </div>
    </aside>
  );
};

export const ResourceAdmin = () => {
  const [items, setItems] = useState<Capability[]>(loadCapabilities);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [jsonText, setJsonText] = useState(() => JSON.stringify(loadCapabilities(), null, 2));
  const [message, setMessage] = useState('未保存的修改只会停留在当前页面，点击保存后首页生效。');
  const [previewMode, setPreviewMode] = useState<PreviewMode>('mobile');
  const [mediaCheck, setMediaCheck] = useState<MediaCheck>({
    status: 'idle',
    sizeBytes: null,
    note: '尚未设置媒体链接。',
  });
  const selected = items[selectedIndex] ?? items[0];

  useEffect(() => {
    if (!selected) {
      return;
    }

    let active = true;
    setMediaCheck({ status: selected.appScreen ? 'checking' : 'idle', sizeBytes: null, note: selected.appScreen ? '正在检查资源大小...' : '尚未设置媒体链接。' });

    getMediaCheck(selected.appScreen ?? '', selected.appScreenType).then((result) => {
      if (active) {
        setMediaCheck(result);
      }
    });

    return () => {
      active = false;
    };
  }, [selected?.appScreen, selected?.appScreenType]);

  const updateSelected = (patch: Partial<Capability>) => {
    setItems((prev) => prev.map((item, index) => (
      index === selectedIndex ? { ...item, ...patch } : item
    )));
  };

  const updateAccent = (colorIndex: number, value: string) => {
    if (!selected) return;

    const accent = [...selected.accent] as [string, string, string];
    accent[colorIndex] = value;
    updateSelected({ accent });
  };

  const addItem = () => {
    setItems((prev) => {
      const next = [...prev, createCapability(prev.length)];
      setSelectedIndex(next.length - 1);
      return next;
    });
  };

  const duplicateItem = () => {
    if (!selected) return;

    setItems((prev) => {
      const copy = {
        ...selected,
        id: `${selected.id}-copy`,
        title: `${selected.title} 副本`,
        accent: [...selected.accent] as [string, string, string],
      };
      const next = [...prev.slice(0, selectedIndex + 1), copy, ...prev.slice(selectedIndex + 1)];
      setSelectedIndex(selectedIndex + 1);
      return next;
    });
  };

  const removeItem = () => {
    if (items.length <= 1) {
      setMessage('至少需要保留一个功能展示模块。');
      return;
    }

    setItems((prev) => {
      const next = prev.filter((_, index) => index !== selectedIndex);
      setSelectedIndex(Math.max(0, selectedIndex - 1));
      return next;
    });
  };

  const moveSelected = (direction: -1 | 1) => {
    const nextIndex = selectedIndex + direction;
    if (nextIndex < 0 || nextIndex >= items.length) {
      return;
    }

    setItems((prev) => swapItems(prev, selectedIndex, nextIndex));
    setSelectedIndex(nextIndex);
  };

  const save = () => {
    const normalized = normalizeCapabilities(items);
    if (mediaCheck.status === 'error') {
      setMessage(`当前模块资源未通过检查：${mediaCheck.note}`);
      return;
    }

    saveCapabilities(normalized);
    setItems(normalized);
    setJsonText(JSON.stringify(normalized, null, 2));
    setMessage(`已保存 ${normalized.length} 个功能展示模块，首页会使用最新配置。`);
  };

  const reset = () => {
    resetCapabilities();
    setItems(defaultCapabilities);
    setSelectedIndex(0);
    setJsonText(JSON.stringify(defaultCapabilities, null, 2));
    setMessage('已恢复默认功能展示配置。');
  };

  const exportJson = () => {
    const text = JSON.stringify(normalizeCapabilities(items), null, 2);
    setJsonText(text);
    void navigator.clipboard?.writeText(text);
    setMessage('配置 JSON 已刷新，并已尝试复制到剪贴板。');
  };

  const importJson = () => {
    try {
      const normalized = normalizeCapabilities(JSON.parse(jsonText));
      setItems(normalized);
      setSelectedIndex(0);
      setMessage(`已导入 ${normalized.length} 个功能展示模块，保存后首页生效。`);
    } catch {
      setMessage('JSON 格式无法解析，请检查后再导入。');
    }
  };

  return (
    <main data-native-scroll="true" className="min-h-screen overflow-x-hidden bg-[linear-gradient(180deg,#050505_0%,#0b0b0d_42%,#050505_100%)] text-white">
      <div className="mx-auto flex min-h-screen w-full max-w-[1480px] flex-col gap-5 px-3 py-4 sm:px-5 md:gap-6 md:px-6 md:py-6 lg:flex-row">
        <aside className="lg:sticky lg:top-6 lg:h-[calc(100vh-3rem)] lg:w-[23rem] lg:flex-none">
          <div className={`${panelClass} flex h-full flex-col overflow-hidden`}>
            <div className="border-b border-white/10 p-5">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className="text-xs uppercase tracking-[0.24em] text-cyan-200/70">Ravehub Admin</p>
                  <h1 className="mt-2 text-2xl font-semibold tracking-tight">网页资源管理</h1>
                </div>
                <span className="rounded-full border border-cyan-200/20 bg-cyan-200/10 px-3 py-1 text-xs text-cyan-100">
                  {items.length} 项
                </span>
              </div>
              <p className="mt-3 text-sm leading-6 text-neutral-400">
                隐藏路径进入，不会出现在官网导航里。
              </p>
            </div>

            <div className="max-h-[20rem] flex-1 overflow-y-auto p-3 lg:max-h-none">
              <div className="space-y-2">
                {items.map((item, index) => {
                  const active = index === selectedIndex;

                  return (
                    <button
                      key={`${item.id}-${index}`}
                      type="button"
                      onClick={() => setSelectedIndex(index)}
                      className={`w-full rounded-lg border px-3 py-3 text-left transition ${
                        active
                          ? 'border-cyan-300/60 bg-cyan-300/[0.12] shadow-[0_0_24px_rgba(103,232,249,0.08)]'
                          : 'border-white/10 bg-white/[0.03] hover:border-white/25 hover:bg-white/[0.06]'
                      }`}
                    >
                      <div className="flex items-center justify-between gap-3">
                        <span className="font-mono text-xs text-neutral-400">{item.id || String(index + 1).padStart(2, '0')}</span>
                        <span className="inline-flex items-center gap-1 text-xs text-neutral-400">
                          {item.appScreenType === 'video' ? <Video className="h-3.5 w-3.5" /> : <ImageIcon className="h-3.5 w-3.5" />}
                          {item.appScreenType}
                        </span>
                      </div>
                      <p className="mt-2 truncate text-sm font-medium text-white">{item.title || '未命名模块'}</p>
                    </button>
                  );
                })}
              </div>
            </div>

            <div className="grid grid-cols-2 gap-2 border-t border-white/10 bg-neutral-950/35 p-3">
              <button type="button" className={textButtonClass} onClick={addItem}>
                <Plus className="h-4 w-4" />
                新增
              </button>
              <button type="button" className={textButtonClass} onClick={save}>
                <Save className="h-4 w-4" />
                保存
              </button>
            </div>
          </div>
        </aside>

        <section className="min-w-0 flex-1 space-y-5 md:space-y-6">
          <div className={`${panelClass} p-4 md:p-5`}>
            <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
              <div>
                <p className="text-xs uppercase tracking-[0.22em] text-neutral-500">Capability Resource</p>
                <h2 className="mt-2 text-xl font-semibold tracking-tight">功能展示模块编辑</h2>
              </div>
              <div className="flex flex-wrap gap-2">
                <button type="button" className={iconButtonClass} onClick={() => moveSelected(-1)} disabled={selectedIndex === 0} aria-label="上移">
                  <ArrowUp className="h-4 w-4" />
                </button>
                <button type="button" className={iconButtonClass} onClick={() => moveSelected(1)} disabled={selectedIndex === items.length - 1} aria-label="下移">
                  <ArrowDown className="h-4 w-4" />
                </button>
                <button type="button" className={iconButtonClass} onClick={duplicateItem} aria-label="复制">
                  <Copy className="h-4 w-4" />
                </button>
                <button type="button" className={iconButtonClass} onClick={removeItem} aria-label="删除">
                  <Trash2 className="h-4 w-4" />
                </button>
                <button type="button" className={textButtonClass} onClick={reset}>
                  <RefreshCcw className="h-4 w-4" />
                  恢复默认
                </button>
              </div>
            </div>

            <p className="mt-4 rounded-md border border-cyan-300/15 bg-cyan-300/[0.06] px-3 py-2 text-sm leading-6 text-cyan-100/80">
              {message}
            </p>
          </div>

          {selected && (
            <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_28rem] 2xl:grid-cols-[minmax(0,1fr)_32rem]">
              <div className={`${panelClass} p-4 md:p-5`}>
                <div className="grid gap-4 md:grid-cols-[8rem_minmax(0,1fr)]">
                  <label>
                    <span className={labelClass}>编号</span>
                    <input
                      value={selected.id}
                      onChange={(event) => updateSelected({ id: event.target.value })}
                      maxLength={8}
                      className={fieldClass}
                    />
                  </label>

                  <label>
                    <span className={labelClass}>标题 · {selected.title.length}/32</span>
                    <input
                      value={selected.title}
                      onChange={(event) => updateSelected({ title: event.target.value })}
                      maxLength={32}
                      className={fieldClass}
                    />
                  </label>

                  <label className="md:col-span-2">
                    <span className={labelClass}>描述 · {selected.description.length}/260</span>
                    <textarea
                      value={selected.description}
                      onChange={(event) => updateSelected({ description: event.target.value })}
                      maxLength={260}
                      className={`${fieldClass} min-h-36 resize-y leading-6`}
                    />
                  </label>

                  <label>
                    <span className={labelClass}>展示形式</span>
                    <select
                      value={selected.displayMode}
                      onChange={(event) => updateSelected({ displayMode: event.target.value as CapabilityDisplayMode })}
                      className={fieldClass}
                    >
                      <option value="phone">手机框展示</option>
                      <option value="gallery">横向图片画廊</option>
                    </select>
                  </label>

                  <label>
                    <span className={labelClass}>媒体类型</span>
                    <select
                      value={selected.appScreenType}
                      onChange={(event) => updateSelected({ appScreenType: event.target.value as CapabilityMediaType })}
                      className={fieldClass}
                    >
                      <option value="image">图片</option>
                      <option value="video">视频</option>
                    </select>
                  </label>

                  <label>
                    <span className={labelClass}>图片 / 视频链接</span>
                    <input
                      type="url"
                      value={selected.appScreen ?? ''}
                      onChange={(event) => updateSelected({ appScreen: event.target.value })}
                      className={fieldClass}
                      placeholder="https://ravehubcn.oss-cn-beijing.aliyuncs.com/..."
                    />
                  </label>

                  {selected.displayMode === 'gallery' && (
                    <label className="md:col-span-2">
                      <span className={labelClass}>画廊图片链接 · {selected.galleryImages.length}/8</span>
                      <textarea
                        value={selected.galleryImages.join('\n')}
                        onChange={(event) => {
                          const galleryImages = parseGalleryImages(event.target.value).slice(0, 8);
                          updateSelected({
                            galleryImages,
                            appScreen: galleryImages[0] ?? selected.appScreen,
                            appScreenType: 'image',
                          });
                        }}
                        className={`${fieldClass} min-h-44 resize-y font-mono text-xs leading-5`}
                        placeholder="每行一个 OSS 图片链接，最多 8 张"
                        spellCheck={false}
                      />
                    </label>
                  )}

                  <div className="md:col-span-2">
                    <span className={labelClass}>主题色</span>
                    <div className="grid gap-3 md:grid-cols-3">
                      {selected.accent.map((color, index) => (
                        <label key={index} className="flex items-center gap-3 rounded-md border border-white/10 bg-neutral-950 p-2">
                          <input
                            type="color"
                            value={color}
                            onChange={(event) => updateAccent(index, event.target.value)}
                            className="h-9 w-10 rounded border-0 bg-transparent p-0"
                          />
                          <input
                            value={color}
                            onChange={(event) => updateAccent(index, event.target.value)}
                            className="min-w-0 flex-1 bg-transparent text-sm text-white outline-none"
                          />
                        </label>
                      ))}
                    </div>
                  </div>

                  <label className="md:col-span-2">
                    <span className={labelClass}>发光颜色</span>
                    <input
                      value={selected.glowColor}
                      onChange={(event) => updateSelected({ glowColor: event.target.value })}
                      className={fieldClass}
                      placeholder="rgba(6,182,212,0.4)"
                    />
                  </label>
                </div>
              </div>

              <MediaPreview
                item={selected}
                mode={previewMode}
                onModeChange={setPreviewMode}
                mediaCheck={mediaCheck}
              />
            </div>
          )}

          <div className={`${panelClass} p-4 md:p-5`}>
            <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
              <div>
                <p className="text-xs uppercase tracking-[0.2em] text-neutral-500">JSON</p>
                <h2 className="mt-1 text-lg font-semibold">配置导入 / 导出</h2>
              </div>
              <div className="flex flex-wrap gap-2">
                <button type="button" className={textButtonClass} onClick={exportJson}>
                  <Download className="h-4 w-4" />
                  导出
                </button>
                <button type="button" className={textButtonClass} onClick={importJson}>
                  <Upload className="h-4 w-4" />
                  导入
                </button>
              </div>
            </div>
            <textarea
              value={jsonText}
              onChange={(event) => setJsonText(event.target.value)}
              className={`${fieldClass} mt-4 min-h-72 resize-y font-mono text-xs leading-5`}
              spellCheck={false}
            />
          </div>
        </section>
      </div>
    </main>
  );
};
