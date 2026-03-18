'use client';

import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import Image from 'next/image';
import Navigation from '@/components/Navigation';
import { useAuth } from '@/contexts/AuthContext';
import { eventAPI } from '@/lib/api/event';
import { djAPI, DJ } from '@/lib/api/dj';

interface LineupSlotForm {
  djId?: string;
  djName: string;
  stageName: string;
  startTime: string;
  endTime: string;
}

interface TicketTierForm {
  name: string;
  price: string;
  currency: string;
}

const EVENT_TYPES = ['电音节', '酒吧活动', '露天活动', '俱乐部派对', '仓库派对', '巡演专场', '其他'];

const slugify = (value: string) =>
  value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '') || 'event';

function UploadDropZone({
  label,
  previewUrl,
  onFileSelect,
  uploading,
}: {
  label: string;
  previewUrl: string;
  onFileSelect: (file: File) => void;
  uploading: boolean;
}) {
  const [dragging, setDragging] = useState(false);

  return (
    <div
      onDragOver={(e) => {
        e.preventDefault();
        setDragging(true);
      }}
      onDragLeave={() => setDragging(false)}
      onDrop={(e) => {
        e.preventDefault();
        setDragging(false);
        const file = e.dataTransfer.files?.[0];
        if (file) {
          onFileSelect(file);
        }
      }}
      className={`rounded-xl border-2 border-dashed p-4 transition-colors ${
        dragging ? 'border-primary-blue bg-primary-blue/10' : 'border-bg-primary bg-bg-tertiary/40'
      }`}
    >
      <p className="text-sm text-text-secondary mb-3">{label}</p>
      {previewUrl ? (
        <div className="relative w-full aspect-video rounded-lg overflow-hidden border border-bg-primary mb-3">
          <Image src={previewUrl} alt={label} fill className="object-cover" sizes="800px" />
        </div>
      ) : (
        <div className="w-full aspect-video rounded-lg bg-bg-primary/40 flex items-center justify-center text-text-tertiary mb-3">
          拖动图片到这里
        </div>
      )}

      <label className="inline-flex items-center px-3 py-2 rounded-lg bg-bg-primary border border-bg-secondary text-text-primary text-sm cursor-pointer hover:border-primary-blue">
        {uploading ? '上传中...' : '点击上传图片'}
        <input
          type="file"
          accept="image/*"
          className="hidden"
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) {
              onFileSelect(file);
            }
          }}
        />
      </label>
    </div>
  );
}

export default function PublishEventPage() {
  const router = useRouter();
  const { user, token, isLoading } = useAuth();

  const [djs, setDjs] = useState<DJ[]>([]);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [eventType, setEventType] = useState(EVENT_TYPES[0]);
  const [organizerName, setOrganizerName] = useState('');
  const [coverImageUrl, setCoverImageUrl] = useState('');
  const [lineupImageUrl, setLineupImageUrl] = useState('');
  const [venueName, setVenueName] = useState('');
  const [venueAddress, setVenueAddress] = useState('');
  const [city, setCity] = useState('');
  const [country, setCountry] = useState('');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [ticketUrl, setTicketUrl] = useState('');
  const [ticketCurrency, setTicketCurrency] = useState('CNY');
  const [ticketNotes, setTicketNotes] = useState('');
  const [ticketTiers, setTicketTiers] = useState<TicketTierForm[]>([]);
  const [officialWebsite, setOfficialWebsite] = useState('');
  const [lineupSlots, setLineupSlots] = useState<LineupSlotForm[]>([]);

  const [uploadingCover, setUploadingCover] = useState(false);
  const [uploadingLineup, setUploadingLineup] = useState(false);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    if (!isLoading && !user) {
      router.push('/login');
      return;
    }
  }, [isLoading, user, router]);

  useEffect(() => {
    const loadDjs = async () => {
      try {
        const response = await djAPI.getDJs({ page: 1, limit: 200, sortBy: 'followerCount' });
        setDjs(response.djs || []);
      } catch (err) {
        console.error(err);
      }
    };

    if (user) {
      loadDjs();
      setOrganizerName(user.displayName || user.username || '');
    }
  }, [user]);

  const canSubmit = useMemo(() => {
    return Boolean(name && startDate && endDate && city && country && venueName);
  }, [name, startDate, endDate, city, country, venueName]);

  const uploadImage = async (file: File, target: 'cover' | 'lineup') => {
    if (!token) {
      router.push('/login');
      return;
    }
    if (target === 'cover') {
      setUploadingCover(true);
    } else {
      setUploadingLineup(true);
    }

    try {
      const result = await eventAPI.uploadImage(file, token);
      if (target === 'cover') {
        setCoverImageUrl(result.url);
      } else {
        setLineupImageUrl(result.url);
      }
      setMessage('图片上传成功');
    } catch (err) {
      setError(err instanceof Error ? err.message : '图片上传失败');
    } finally {
      setUploadingCover(false);
      setUploadingLineup(false);
    }
  };

  const addLineupSlot = () => {
    setLineupSlots((prev) => [
      ...prev,
      {
        djId: '',
        djName: '',
        stageName: '',
        startTime: '',
        endTime: '',
      },
    ]);
  };

  const updateLineupSlot = (index: number, key: keyof LineupSlotForm, value: string) => {
    setLineupSlots((prev) => {
      const next = [...prev];
      next[index] = { ...next[index], [key]: value };
      if (key === 'djId') {
        const dj = djs.find((item) => item.id === value);
        if (dj) {
          next[index].djName = dj.name;
        }
      }
      return next;
    });
  };

  const removeLineupSlot = (index: number) => {
    setLineupSlots((prev) => prev.filter((_, i) => i !== index));
  };

  const addTicketTier = () => {
    setTicketTiers((prev) => [...prev, { name: '', price: '', currency: ticketCurrency || 'CNY' }]);
  };

  const updateTicketTier = (index: number, key: keyof TicketTierForm, value: string) => {
    setTicketTiers((prev) => {
      const next = [...prev];
      next[index] = { ...next[index], [key]: value };
      return next;
    });
  };

  const removeTicketTier = (index: number) => {
    setTicketTiers((prev) => prev.filter((_, i) => i !== index));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token) {
      router.push('/login');
      return;
    }
    if (!canSubmit) {
      setError('请先填写活动名称、时间、国家城市和场地');
      return;
    }

    setSaving(true);
    setError('');
    setMessage('');

    try {
      const payload = {
        name,
        slug: `${slugify(name)}-${Date.now().toString().slice(-6)}`,
        description,
        eventType,
        organizerName,
        coverImageUrl: coverImageUrl || null,
        lineupImageUrl: lineupImageUrl || null,
        venueName,
        venueAddress,
        city,
        country,
        startDate,
        endDate,
        ticketUrl: ticketUrl || null,
        ticketPriceMin: null,
        ticketPriceMax: null,
        ticketCurrency: ticketCurrency || null,
        ticketNotes: ticketNotes || null,
        ticketTiers: ticketTiers
          .filter((tier) => tier.name.trim() && tier.price.trim())
          .map((tier, idx) => ({
            name: tier.name.trim(),
            price: Number(tier.price),
            currency: (tier.currency || ticketCurrency || 'CNY').trim(),
            sortOrder: idx + 1,
          })),
        officialWebsite: officialWebsite || null,
        lineupSlots: lineupSlots
          .filter((slot) => slot.djName && slot.startTime && slot.endTime)
          .map((slot, idx) => ({
            djId: slot.djId || null,
            djName: slot.djName,
            stageName: slot.stageName || null,
            sortOrder: idx + 1,
            startTime: slot.startTime,
            endTime: slot.endTime,
          })),
      };

      const created = await eventAPI.createEvent(payload as any, token);
      setMessage('活动发布成功');
      router.push(`/events/${created.id}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : '发布活动失败');
    } finally {
      setSaving(false);
    }
  };

  if (!user) {
    return null;
  }

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px] max-w-6xl mx-auto p-6">
        <h1 className="text-3xl font-bold text-text-primary mb-2">发布电音活动</h1>
        <p className="text-text-secondary mb-6">主办方/宣传方可在此发布活动信息，支持封面图和阵容图上传（拖拽或点击）。</p>
        <div className="mb-6">
          <button
            type="button"
            onClick={() => router.push('/my-publishes?type=event')}
            className="px-3 py-2 rounded-lg border border-bg-primary text-text-secondary hover:text-text-primary text-sm"
          >
            进入我的发布内容
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-5">
          <div className="rounded-xl border border-bg-tertiary bg-bg-secondary p-5 grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="md:col-span-2">
              <label className="block text-sm text-text-secondary mb-1">活动名称</label>
              <input value={name} onChange={(e) => setName(e.target.value)} className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary" required />
            </div>

            <div>
              <label className="block text-sm text-text-secondary mb-1">活动性质</label>
              <select value={eventType} onChange={(e) => setEventType(e.target.value)} className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary">
                {EVENT_TYPES.map((type) => (
                  <option key={type} value={type}>{type}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm text-text-secondary mb-1">主办方/宣传方</label>
              <input value={organizerName} onChange={(e) => setOrganizerName(e.target.value)} className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary" />
            </div>

            <div>
              <label className="block text-sm text-text-secondary mb-1">开始时间</label>
              <input type="datetime-local" value={startDate} onChange={(e) => setStartDate(e.target.value)} className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary" required />
            </div>

            <div>
              <label className="block text-sm text-text-secondary mb-1">结束时间</label>
              <input type="datetime-local" value={endDate} onChange={(e) => setEndDate(e.target.value)} className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary" required />
            </div>

            <div>
              <label className="block text-sm text-text-secondary mb-1">国家</label>
              <input value={country} onChange={(e) => setCountry(e.target.value)} className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary" required />
            </div>

            <div>
              <label className="block text-sm text-text-secondary mb-1">城市</label>
              <input value={city} onChange={(e) => setCity(e.target.value)} className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary" required />
            </div>

            <div>
              <label className="block text-sm text-text-secondary mb-1">场地名称</label>
              <input value={venueName} onChange={(e) => setVenueName(e.target.value)} className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary" required />
            </div>

            <div>
              <label className="block text-sm text-text-secondary mb-1">场地地址</label>
              <input value={venueAddress} onChange={(e) => setVenueAddress(e.target.value)} className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary" />
            </div>

            <div className="md:col-span-2">
              <label className="block text-sm text-text-secondary mb-1">活动介绍</label>
              <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={4} className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary" />
            </div>
          </div>

          <div className="rounded-xl border border-bg-tertiary bg-bg-secondary p-5 grid grid-cols-1 md:grid-cols-2 gap-4">
            <UploadDropZone label="活动封面图" previewUrl={coverImageUrl} onFileSelect={(file) => uploadImage(file, 'cover')} uploading={uploadingCover} />
            <UploadDropZone label="活动阵容图" previewUrl={lineupImageUrl} onFileSelect={(file) => uploadImage(file, 'lineup')} uploading={uploadingLineup} />
          </div>

          <div className="rounded-xl border border-bg-tertiary bg-bg-secondary p-5 grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="block text-sm text-text-secondary mb-1">币种</label>
              <input value={ticketCurrency} onChange={(e) => setTicketCurrency(e.target.value)} className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary" placeholder="CNY / USD" />
            </div>
            <div className="md:col-span-2">
              <label className="block text-sm text-text-secondary mb-1">票务链接</label>
              <input value={ticketUrl} onChange={(e) => setTicketUrl(e.target.value)} className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary" placeholder="https://" />
            </div>
            <div className="md:col-span-3 rounded-lg border border-bg-primary bg-bg-tertiary/40 p-3">
              <div className="flex items-center justify-between mb-2">
                <label className="block text-sm text-text-secondary">票档（票档名称 - 票价）</label>
                <button type="button" onClick={addTicketTier} className="px-3 py-1.5 rounded-lg bg-bg-primary border border-bg-secondary text-text-primary text-xs">
                  + 添加票档
                </button>
              </div>
              <div className="space-y-2">
                {ticketTiers.map((tier, index) => (
                  <div key={index} className="grid grid-cols-1 md:grid-cols-[1fr_180px_120px_auto] gap-2 items-center">
                    <input value={tier.name} onChange={(e) => updateTicketTier(index, 'name', e.target.value)} className="w-full bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary text-sm" placeholder="票档名称（如 Early Bird）" />
                    <input type="number" min="0" step="0.01" value={tier.price} onChange={(e) => updateTicketTier(index, 'price', e.target.value)} className="w-full bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary text-sm" placeholder="票价" />
                    <input value={tier.currency} onChange={(e) => updateTicketTier(index, 'currency', e.target.value)} className="w-full bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary text-sm" placeholder="币种" />
                    <button type="button" onClick={() => removeTicketTier(index)} className="text-accent-red text-xs">
                      删除
                    </button>
                  </div>
                ))}
                {ticketTiers.length === 0 && (
                  <p className="text-xs text-text-tertiary">暂无票档，可点击“添加票档”。</p>
                )}
              </div>
            </div>
            <div className="md:col-span-3">
              <label className="block text-sm text-text-secondary mb-1">票价备注</label>
              <textarea value={ticketNotes} onChange={(e) => setTicketNotes(e.target.value)} rows={2} className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary" placeholder="例如：早鸟票/预售票/VIP等" />
            </div>
            <div className="md:col-span-3">
              <label className="block text-sm text-text-secondary mb-1">官方网站</label>
              <input value={officialWebsite} onChange={(e) => setOfficialWebsite(e.target.value)} className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary" placeholder="https://" />
            </div>
          </div>

          <div className="rounded-xl border border-bg-tertiary bg-bg-secondary p-5">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-semibold text-text-primary">参演DJ与演出时间段</h2>
              <button type="button" onClick={addLineupSlot} className="px-3 py-2 rounded-lg bg-primary-blue hover:bg-primary-purple text-white text-sm">+ 添加时段</button>
            </div>

            <div className="space-y-3">
              {lineupSlots.length === 0 && <p className="text-sm text-text-tertiary">还未添加DJ时段。</p>}
              {lineupSlots.map((slot, index) => (
                <div key={index} className="rounded-lg border border-bg-primary bg-bg-tertiary p-3 grid grid-cols-1 md:grid-cols-5 gap-2">
                  <div>
                    <label className="block text-xs text-text-tertiary mb-1">选择DJ</label>
                    <select value={slot.djId || ''} onChange={(e) => updateLineupSlot(index, 'djId', e.target.value)} className="w-full bg-bg-primary text-text-primary rounded-lg px-2 py-2 border border-bg-secondary text-sm">
                      <option value="">手动填写</option>
                      {djs.map((dj) => (
                        <option key={dj.id} value={dj.id}>{dj.name}</option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="block text-xs text-text-tertiary mb-1">DJ名称</label>
                    <input value={slot.djName} onChange={(e) => updateLineupSlot(index, 'djName', e.target.value)} className="w-full bg-bg-primary text-text-primary rounded-lg px-2 py-2 border border-bg-secondary text-sm" />
                  </div>
                  <div>
                    <label className="block text-xs text-text-tertiary mb-1">舞台</label>
                    <input value={slot.stageName} onChange={(e) => updateLineupSlot(index, 'stageName', e.target.value)} className="w-full bg-bg-primary text-text-primary rounded-lg px-2 py-2 border border-bg-secondary text-sm" />
                  </div>
                  <div>
                    <label className="block text-xs text-text-tertiary mb-1">开始</label>
                    <input type="datetime-local" value={slot.startTime} onChange={(e) => updateLineupSlot(index, 'startTime', e.target.value)} className="w-full bg-bg-primary text-text-primary rounded-lg px-2 py-2 border border-bg-secondary text-sm" />
                  </div>
                  <div>
                    <label className="block text-xs text-text-tertiary mb-1">结束</label>
                    <div className="flex items-center gap-2">
                      <input type="datetime-local" value={slot.endTime} onChange={(e) => updateLineupSlot(index, 'endTime', e.target.value)} className="w-full bg-bg-primary text-text-primary rounded-lg px-2 py-2 border border-bg-secondary text-sm" />
                      <button type="button" onClick={() => removeLineupSlot(index)} className="text-accent-red text-xs">删除</button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {error && <div className="rounded-lg border border-accent-red/40 bg-accent-red/10 text-accent-red px-3 py-2 text-sm">{error}</div>}
          {message && <div className="rounded-lg border border-primary-blue/40 bg-primary-blue/10 text-primary-blue px-3 py-2 text-sm">{message}</div>}

          <div className="flex items-center gap-3">
            <button type="submit" disabled={!canSubmit || saving} className="px-5 py-2.5 rounded-lg bg-primary-blue hover:bg-primary-purple text-white disabled:opacity-50">
              {saving ? '发布中...' : '发布活动'}
            </button>
            <button type="button" onClick={() => router.push('/events')} className="px-5 py-2.5 rounded-lg border border-bg-primary text-text-secondary hover:text-text-primary">
              取消
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
