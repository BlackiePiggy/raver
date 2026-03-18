'use client';

import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Image from 'next/image';
import { toPng } from 'html-to-image';
import Navigation from '@/components/Navigation';
import { Button } from '@/components/ui/Button';
import { Event, EventLineupSlot, eventAPI } from '@/lib/api/event';

const SCHEDULE_TZ = 'Asia/Shanghai';
const STORAGE_KEY_PREFIX = 'ravehub:routine:';
const TIME_COL_WIDTH = 68;
const PX_PER_MIN = 1.15;

type DayGroup = {
  key: string;
  label: string;
  slots: EventLineupSlot[];
  stages: Array<{
    stageName: string;
    slots: EventLineupSlot[];
  }>;
};

type PlannedSlot = {
  key: string;
  slot: EventLineupSlot;
  dayKey: string;
  dayLabel: string;
  note?: string;
};

type ConflictCluster = {
  id: string;
  dayKey: string;
  dayLabel: string;
  items: PlannedSlot[];
};

type SwitchPlan = {
  mode: 'parallel' | 'switch';
  fromKey?: string;
  toKey?: string;
  switchAt?: string;
};

const slotKey = (slot: EventLineupSlot) =>
  slot.id || `${slot.djName}-${slot.stageName || 'stage'}-${slot.startTime}-${slot.endTime}`;

const getFestivalDayKey = (dateString: string) => {
  const localText = new Date(dateString).toLocaleString('sv-SE', {
    timeZone: SCHEDULE_TZ,
    hour12: false,
  });
  const [datePart, timePart] = localText.split(' ');
  const hour = Number(timePart.split(':')[0] || '0');

  if (hour >= 12) return datePart;

  const [y, m, d] = datePart.split('-').map(Number);
  const prev = new Date(Date.UTC(y, m - 1, d));
  prev.setUTCDate(prev.getUTCDate() - 1);
  return new Intl.DateTimeFormat('sv-SE', {
    timeZone: 'UTC',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(prev);
};

const formatDayLabel = (dateString: string) =>
  new Date(dateString).toLocaleDateString('zh-CN', {
    timeZone: SCHEDULE_TZ,
    month: 'long',
    day: 'numeric',
    weekday: 'long',
  });

const formatSlotTime = (dateString: string) =>
  new Date(dateString).toLocaleTimeString('zh-CN', {
    timeZone: SCHEDULE_TZ,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });

const toMs = (dateString: string) => new Date(dateString).getTime();

const overlaps = (a: EventLineupSlot, b: EventLineupSlot) =>
  toMs(a.startTime) < toMs(b.endTime) && toMs(b.startTime) < toMs(a.endTime);

const floorToHour = (ms: number) => {
  const d = new Date(ms);
  d.setMinutes(0, 0, 0);
  return d.getTime();
};

const ceilToHour = (ms: number) => {
  const d = new Date(ms);
  if (d.getMinutes() !== 0 || d.getSeconds() !== 0 || d.getMilliseconds() !== 0) {
    d.setHours(d.getHours() + 1);
  }
  d.setMinutes(0, 0, 0);
  return d.getTime();
};

const formatSwitchValue = (ms: number) =>
  new Date(ms).toLocaleString('sv-SE', {
    timeZone: SCHEDULE_TZ,
    hour12: false,
  }).replace(' ', 'T').slice(0, 16);

const parseSwitchValueToMs = (value: string) => {
  const [datePart, timePart] = value.split('T');
  if (!datePart || !timePart) return NaN;
  const [y, m, d] = datePart.split('-').map(Number);
  const [hh, mm] = timePart.split(':').map(Number);
  if ([y, m, d, hh, mm].some((n) => Number.isNaN(n))) return NaN;
  return Date.UTC(y, m - 1, d, hh - 8, mm, 0);
};

const getDjVisualImage = (slot: EventLineupSlot) => slot.dj?.bannerUrl || slot.dj?.avatarUrl || null;

export default function EventRoutinePage() {
  const router = useRouter();
  const params = useParams();
  const eventId = String(params.id || '');
  const [event, setEvent] = useState<Event | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedKeys, setSelectedKeys] = useState<string[]>([]);
  const [switchPlans, setSwitchPlans] = useState<Record<string, SwitchPlan>>({});
  const [planned, setPlanned] = useState<PlannedSlot[]>([]);
  const [isGeneratingShare, setIsGeneratingShare] = useState(false);
  const sharePosterRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const load = async () => {
      if (!eventId) return;
      try {
        setIsLoading(true);
        const data = await eventAPI.getEvent(eventId);
        setEvent(data);
      } catch (err) {
        setError(err instanceof Error ? err.message : '加载活动失败');
      } finally {
        setIsLoading(false);
      }
    };
    load();
  }, [eventId]);

  const dayGroups: DayGroup[] = useMemo(() => {
    if (!event?.lineupSlots || event.lineupSlots.length === 0) return [];

    const sorted = [...event.lineupSlots].sort((a, b) => toMs(a.startTime) - toMs(b.startTime));
    const map = new Map<string, EventLineupSlot[]>();
    for (const slot of sorted) {
      const key = getFestivalDayKey(slot.startTime);
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(slot);
    }

    return Array.from(map.entries()).map(([key, slots], index) => {
      const stageMap = new Map<string, EventLineupSlot[]>();
      for (const slot of slots) {
        const stageName = (slot.stageName || '未命名舞台').trim() || '未命名舞台';
        if (!stageMap.has(stageName)) stageMap.set(stageName, []);
        stageMap.get(stageName)!.push(slot);
      }
      return {
        key,
        label: `Day ${index + 1} · ${formatDayLabel(slots[0].startTime)}`,
        slots,
        stages: Array.from(stageMap.entries()).map(([stageName, stageSlots]) => ({
          stageName,
          slots: stageSlots.sort((a, b) => toMs(a.startTime) - toMs(b.startTime)),
        })),
      };
    });
  }, [event?.lineupSlots]);

  const allSlots = useMemo(
    () =>
      dayGroups.flatMap((day) =>
        day.slots.map((slot) => ({
          key: slotKey(slot),
          slot,
          dayKey: day.key,
          dayLabel: day.label,
        }))
      ),
    [dayGroups]
  );

  useEffect(() => {
    if (!eventId || allSlots.length === 0) return;
    const raw = localStorage.getItem(`${STORAGE_KEY_PREFIX}${eventId}`);
    if (!raw) return;
    try {
      const parsed = JSON.parse(raw);
      if (!Array.isArray(parsed)) return;
      const valid = parsed.filter((key) => allSlots.some((s) => s.key === key));
      setSelectedKeys(valid);
    } catch {
      // ignore invalid local cache
    }
  }, [eventId, allSlots]);

  useEffect(() => {
    if (!eventId) return;
    localStorage.setItem(`${STORAGE_KEY_PREFIX}${eventId}`, JSON.stringify(selectedKeys));
  }, [eventId, selectedKeys]);

  const selectedSet = useMemo(() => new Set(selectedKeys), [selectedKeys]);

  const selectedByDay = useMemo(() => {
    const map = new Map<string, PlannedSlot[]>();
    for (const item of allSlots) {
      if (!selectedSet.has(item.key)) continue;
      if (!map.has(item.dayKey)) map.set(item.dayKey, []);
      map.get(item.dayKey)!.push(item);
    }
    for (const arr of map.values()) {
      arr.sort((a, b) => toMs(a.slot.startTime) - toMs(b.slot.startTime));
    }
    return map;
  }, [allSlots, selectedSet]);

  const conflictClusters = useMemo<ConflictCluster[]>(() => {
    const clusters: ConflictCluster[] = [];
    for (const day of dayGroups) {
      const items = selectedByDay.get(day.key) || [];
      if (items.length < 2) continue;

      const visited = new Set<number>();
      for (let i = 0; i < items.length; i += 1) {
        if (visited.has(i)) continue;
        const queue = [i];
        visited.add(i);
        const indices: number[] = [];

        while (queue.length > 0) {
          const cur = queue.shift()!;
          indices.push(cur);
          for (let j = 0; j < items.length; j += 1) {
            if (visited.has(j)) continue;
            if (overlaps(items[cur].slot, items[j].slot)) {
              visited.add(j);
              queue.push(j);
            }
          }
        }

        if (indices.length > 1) {
          clusters.push({
            id: `${day.key}-${clusters.length + 1}`,
            dayKey: day.key,
            dayLabel: day.label,
            items: indices.map((idx) => items[idx]),
          });
        }
      }
    }
    return clusters;
  }, [dayGroups, selectedByDay]);

  useEffect(() => {
    const validIds = new Set(conflictClusters.map((c) => c.id));
    setSwitchPlans((prev) => {
      const next: Record<string, SwitchPlan> = {};
      for (const [id, value] of Object.entries(prev)) {
        if (validIds.has(id)) next[id] = value;
      }
      for (const cluster of conflictClusters) {
        if (!next[cluster.id]) next[cluster.id] = { mode: 'parallel' };
      }
      return next;
    });
  }, [conflictClusters]);

  const toggleSelect = (key: string) => {
    setSelectedKeys((prev) => (prev.includes(key) ? prev.filter((k) => k !== key) : [...prev, key]));
  };

  const updateSwitchPlan = (clusterId: string, patch: Partial<SwitchPlan>) => {
    setSwitchPlans((prev) => ({
      ...prev,
      [clusterId]: {
        ...(prev[clusterId] || { mode: 'parallel' as const }),
        ...patch,
      },
    }));
  };

  const getSlotByKey = (key?: string) => allSlots.find((item) => item.key === key);

  const generatePlan = () => {
    const result: PlannedSlot[] = [];
    const clusteredKeys = new Set(conflictClusters.flatMap((cluster) => cluster.items.map((item) => item.key)));

    for (const item of allSlots) {
      if (!selectedSet.has(item.key)) continue;
      if (clusteredKeys.has(item.key)) continue;
      result.push(item);
    }

    for (const cluster of conflictClusters) {
      const plan = switchPlans[cluster.id] || { mode: 'parallel' as const };

      if (plan.mode === 'switch' && plan.fromKey && plan.toKey && plan.fromKey !== plan.toKey) {
        const from = getSlotByKey(plan.fromKey);
        const to = getSlotByKey(plan.toKey);
        if (!from || !to) {
          result.push(...cluster.items);
          continue;
        }

        const overlapStart = Math.max(toMs(from.slot.startTime), toMs(to.slot.startTime));
        const overlapEnd = Math.min(toMs(from.slot.endTime), toMs(to.slot.endTime));
        if (overlapStart >= overlapEnd) {
          result.push(...cluster.items);
          continue;
        }

        let switchAt = plan.switchAt ? parseSwitchValueToMs(plan.switchAt) : NaN;
        if (Number.isNaN(switchAt)) switchAt = Math.floor((overlapStart + overlapEnd) / 2);
        switchAt = Math.min(Math.max(switchAt, overlapStart), overlapEnd);

        if (toMs(from.slot.startTime) < switchAt) {
          result.push({
            ...from,
            slot: {
              ...from.slot,
              endTime: new Date(switchAt).toISOString(),
            },
            note: `串场前：${from.slot.stageName || '未命名舞台'}`,
          });
        }
        if (switchAt < toMs(to.slot.endTime)) {
          result.push({
            ...to,
            slot: {
              ...to.slot,
              startTime: new Date(switchAt).toISOString(),
            },
            note: `串场后：${to.slot.stageName || '未命名舞台'}`,
          });
        }
      } else {
        result.push(...cluster.items.map((item) => ({ ...item, note: '并行关注' })));
      }
    }

    result.sort((a, b) => toMs(a.slot.startTime) - toMs(b.slot.startTime));
    setPlanned(result);
  };

  const groupedPlanned = useMemo(() => {
    const map = new Map<string, { label: string; items: PlannedSlot[] }>();
    for (const item of planned) {
      if (!map.has(item.dayKey)) map.set(item.dayKey, { label: item.dayLabel, items: [] });
      map.get(item.dayKey)!.items.push(item);
    }
    return Array.from(map.entries()).map(([dayKey, value]) => ({ dayKey, ...value }));
  }, [planned]);

  const handleGenerateShareImage = async () => {
    if (planned.length === 0) {
      alert('请先点击“生成我的日程”');
      return;
    }
    if (!sharePosterRef.current) return;

    try {
      setIsGeneratingShare(true);
      const dataUrl = await toPng(sharePosterRef.current, {
        cacheBust: true,
        pixelRatio: 2,
        backgroundColor: '#05070d',
      });

      const link = document.createElement('a');
      link.download = `${event?.name || 'ravehub'}-routine.png`;
      link.href = dataUrl;
      link.click();
    } catch (err) {
      console.error('Generate share image failed:', err);
      alert('生成分享图失败，请稍后重试');
    } finally {
      setIsGeneratingShare(false);
    }
  };

  const getRoutineShareText = () => {
    const lines: string[] = [];
    lines.push(`RaveHub 我的电音节路线`);
    lines.push(event?.name || '');
    lines.push('');
    groupedPlanned.forEach((day) => {
      lines.push(`${day.label}`);
      day.items.forEach((item) => {
        lines.push(
          `- ${formatSlotTime(item.slot.startTime)}-${formatSlotTime(item.slot.endTime)} ${item.slot.djName || item.slot.dj?.name || 'Unknown DJ'} @ ${item.slot.stageName || '未命名舞台'}`
        );
      });
      lines.push('');
    });
    lines.push('Generated with RaveHub');
    return lines.join('\n');
  };

  const handleCopyRoutineText = async () => {
    if (planned.length === 0) {
      alert('请先点击“生成我的日程”');
      return;
    }
    try {
      await navigator.clipboard.writeText(getRoutineShareText());
      alert('行程文案已复制，可以直接粘贴到社交平台。');
    } catch {
      alert('复制失败，请检查浏览器权限。');
    }
  };

  const handleNativeShare = async () => {
    if (planned.length === 0) {
      alert('请先点击“生成我的日程”');
      return;
    }
    if (!navigator.share) {
      alert('当前浏览器不支持系统分享，可使用“一键生成分享图”。');
      return;
    }
    try {
      await navigator.share({
        title: `${event?.name || 'RaveHub'} - 我的行程`,
        text: getRoutineShareText(),
        url: typeof window !== 'undefined' ? window.location.href : undefined,
      });
    } catch {
      // user canceled share
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-bg-primary">
        <Navigation />
        <div className="pt-[44px] min-h-[80vh] flex items-center justify-center">
          <div className="text-text-secondary">加载中...</div>
        </div>
      </div>
    );
  }

  if (error || !event) {
    return (
      <div className="min-h-screen bg-bg-primary">
        <Navigation />
        <div className="pt-[44px] min-h-[80vh] flex items-center justify-center px-6">
          <div className="text-center">
            <p className="text-text-primary text-xl mb-2">路线页加载失败</p>
            <p className="text-text-secondary mb-6">{error || '活动不存在'}</p>
            <Button onClick={() => router.push('/events')}>返回活动列表</Button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px]">
        <div className="max-w-[1600px] mx-auto px-4 md:px-6 py-6 space-y-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h1 className="text-3xl font-bold text-text-primary">制定我的观演路线</h1>
              <p className="text-text-secondary mt-1">{event.name}</p>
            </div>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => router.push(`/events/${event.id}`)}
                className="px-4 py-2 rounded-lg border border-bg-tertiary text-text-secondary hover:text-text-primary"
              >
                返回活动页
              </button>
              <Button onClick={generatePlan}>生成我的日程</Button>
              <Button onClick={handleGenerateShareImage} isLoading={isGeneratingShare} variant="secondary">
                一键生成分享图
              </Button>
              <button
                type="button"
                onClick={handleNativeShare}
                className="px-4 py-2 rounded-lg border border-bg-tertiary text-text-secondary hover:text-text-primary"
              >
                系统分享
              </button>
              <button
                type="button"
                onClick={handleCopyRoutineText}
                className="px-4 py-2 rounded-lg border border-bg-tertiary text-text-secondary hover:text-text-primary"
              >
                复制文案
              </button>
            </div>
          </div>

          <div className="grid grid-cols-1 2xl:grid-cols-[1fr_420px] gap-6">
            <div className="space-y-6">
              <div className="rounded-2xl border border-border-secondary bg-bg-elevated p-4 flex flex-wrap items-center gap-3">
                <span className="text-sm text-text-secondary">已选 {selectedKeys.length} 个时段</span>
                <span className="text-sm text-text-secondary">重叠组 {conflictClusters.length} 组</span>
                <button
                  type="button"
                  onClick={() => {
                    setSelectedKeys([]);
                    setPlanned([]);
                    setSwitchPlans({});
                  }}
                  className="ml-auto px-3 py-1.5 text-xs rounded-md border border-bg-tertiary text-text-tertiary hover:text-text-primary"
                >
                  清空选择
                </button>
              </div>

              {conflictClusters.length > 0 && (
                <div className="rounded-2xl border border-primary-purple/40 bg-primary-purple/10 p-4 space-y-4">
                  <h2 className="text-lg font-semibold text-text-primary">串场设置</h2>
                  {conflictClusters.map((cluster) => {
                    const current = switchPlans[cluster.id] || { mode: 'parallel' as const };
                    const fromItem = getSlotByKey(current.fromKey);
                    const toItem = getSlotByKey(current.toKey);
                    const overlapStart =
                      fromItem && toItem
                        ? Math.max(toMs(fromItem.slot.startTime), toMs(toItem.slot.startTime))
                        : NaN;
                    const overlapEnd =
                      fromItem && toItem
                        ? Math.min(toMs(fromItem.slot.endTime), toMs(toItem.slot.endTime))
                        : NaN;
                    const hasOverlap =
                      !Number.isNaN(overlapStart) && !Number.isNaN(overlapEnd) && overlapStart < overlapEnd;

                    return (
                      <div key={cluster.id} className="rounded-xl border border-border-secondary bg-bg-primary/60 p-3">
                        <div className="mb-2">
                          <p className="text-sm font-medium text-text-primary">{cluster.dayLabel}</p>
                          <p className="text-xs text-text-tertiary">
                            冲突组：{cluster.items.map((item) => item.slot.stageName || '舞台').join(' / ')}
                          </p>
                        </div>

                        <div className="flex flex-wrap items-center gap-3 mb-3">
                          <label className="text-sm text-text-secondary flex items-center gap-2">
                            <input
                              type="radio"
                              checked={current.mode === 'parallel'}
                              onChange={() => updateSwitchPlan(cluster.id, { mode: 'parallel' })}
                            />
                            同时关注（并行保留）
                          </label>
                          <label className="text-sm text-text-secondary flex items-center gap-2">
                            <input
                              type="radio"
                              checked={current.mode === 'switch'}
                              onChange={() => updateSwitchPlan(cluster.id, { mode: 'switch' })}
                            />
                            串场（从 A 舞台切到 B 舞台）
                          </label>
                        </div>

                        {current.mode === 'switch' && (
                          <div className="grid grid-cols-1 md:grid-cols-3 gap-2">
                            <select
                              className="bg-bg-secondary border border-bg-tertiary rounded-lg px-2 py-2 text-sm text-text-primary"
                              value={current.fromKey || ''}
                              onChange={(e) => updateSwitchPlan(cluster.id, { fromKey: e.target.value || undefined })}
                            >
                              <option value="">选择起始舞台</option>
                              {cluster.items.map((item) => (
                                <option key={`from-${item.key}`} value={item.key}>
                                  {item.slot.stageName || '未命名舞台'} · {item.slot.djName}
                                </option>
                              ))}
                            </select>

                            <select
                              className="bg-bg-secondary border border-bg-tertiary rounded-lg px-2 py-2 text-sm text-text-primary"
                              value={current.toKey || ''}
                              onChange={(e) => updateSwitchPlan(cluster.id, { toKey: e.target.value || undefined })}
                            >
                              <option value="">选择目标舞台</option>
                              {cluster.items.map((item) => (
                                <option key={`to-${item.key}`} value={item.key}>
                                  {item.slot.stageName || '未命名舞台'} · {item.slot.djName}
                                </option>
                              ))}
                            </select>

                            <input
                              type="datetime-local"
                              value={current.switchAt || ''}
                              onChange={(e) => updateSwitchPlan(cluster.id, { switchAt: e.target.value || undefined })}
                              min={hasOverlap ? formatSwitchValue(overlapStart) : undefined}
                              max={hasOverlap ? formatSwitchValue(overlapEnd) : undefined}
                              className="bg-bg-secondary border border-bg-tertiary rounded-lg px-2 py-2 text-sm text-text-primary"
                            />
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}

              {dayGroups.map((day) => {
                const stageNames = day.stages.map((stage) => stage.stageName);
                const minStart = Math.min(...day.slots.map((s) => toMs(s.startTime)));
                const maxEnd = Math.max(...day.slots.map((s) => toMs(s.endTime)));
                const axisStart = floorToHour(minStart);
                const axisEnd = ceilToHour(maxEnd);
                const totalMinutes = Math.max((axisEnd - axisStart) / 60000, 60);
                const axisHeight = totalMinutes * PX_PER_MIN;
                const stageWidthPercent = stageNames.length > 0 ? 100 / stageNames.length : 100;
                const hours = Array.from({ length: Math.floor(totalMinutes / 60) + 1 }).map(
                  (_, i) => axisStart + i * 3600000
                );

                return (
                  <section
                    key={day.key}
                    className="rounded-3xl bg-gradient-to-br from-transparent via-bg-secondary/25 to-transparent p-2 md:p-3"
                  >
                    <h2 className="text-xl font-semibold text-text-primary mb-4">{day.label}</h2>
                    <div className="rounded-2xl bg-bg-primary/10">
                      <div className="relative w-full">
                        <div className="flex border-b border-border-secondary">
                          <div
                            className="shrink-0 p-2 text-xs text-text-tertiary bg-bg-secondary/70 border-r border-border-secondary"
                            style={{ width: TIME_COL_WIDTH }}
                          >
                            Time
                          </div>
                          {stageNames.map((stageName) => (
                            <div
                              key={`${day.key}-head-${stageName}`}
                              className="shrink-0 p-2 text-sm font-semibold text-text-primary bg-bg-secondary/70 border-r border-border-secondary last:border-r-0"
                              style={{ width: `calc((100% - ${TIME_COL_WIDTH}px) / ${stageNames.length || 1})` }}
                            >
                              {stageName}
                            </div>
                          ))}
                        </div>

                        <div className="flex relative" style={{ height: axisHeight }}>
                          <div
                            className="shrink-0 border-r border-border-secondary bg-bg-secondary/40"
                            style={{ width: TIME_COL_WIDTH, height: axisHeight }}
                          >
                            {hours.map((hourMs) => {
                              const top = ((hourMs - axisStart) / 60000) * PX_PER_MIN;
                              return (
                                <div
                                  key={`${day.key}-time-${hourMs}`}
                                  className="absolute left-0 text-[11px] text-text-tertiary px-2"
                                  style={{ top: Math.max(top - 8, 0) }}
                                >
                                  {new Date(hourMs).toLocaleTimeString('zh-CN', {
                                    timeZone: SCHEDULE_TZ,
                                    hour: '2-digit',
                                    minute: '2-digit',
                                    hour12: false,
                                  })}
                                </div>
                              );
                            })}
                          </div>

                          <div className="relative" style={{ width: `calc(100% - ${TIME_COL_WIDTH}px)`, height: axisHeight }}>
                            {stageNames.map((stageName, idx) => (
                              <div
                                key={`${day.key}-col-${stageName}`}
                                className="absolute top-0 bottom-0 border-r border-border-secondary/40"
                                style={{
                                  left: `${idx * stageWidthPercent}%`,
                                  width: `${stageWidthPercent}%`,
                                }}
                              />
                            ))}

                            {hours.map((hourMs) => {
                              const top = ((hourMs - axisStart) / 60000) * PX_PER_MIN;
                              return (
                                <div
                                  key={`${day.key}-line-${hourMs}`}
                                  className="absolute left-0 right-0 border-t border-border-secondary/50"
                                  style={{ top }}
                                />
                              );
                            })}

                            {day.slots.map((slot) => {
                              const stageName = (slot.stageName || '未命名舞台').trim() || '未命名舞台';
                              const stageIndex = stageNames.findIndex((s) => s === stageName);
                              if (stageIndex < 0) return null;

                              const key = slotKey(slot);
                              const selected = selectedSet.has(key);
                              const top = ((toMs(slot.startTime) - axisStart) / 60000) * PX_PER_MIN + 2;
                              const height = Math.max(((toMs(slot.endTime) - toMs(slot.startTime)) / 60000) * PX_PER_MIN - 4, 54);
                              const left = `calc(${stageIndex * stageWidthPercent}% + 6px)`;
                              const width = `calc(${stageWidthPercent}% - 12px)`;
                              const djName = slot.djName || slot.dj?.name || 'Unknown DJ';
                              const letter = djName.slice(0, 1).toUpperCase();
                              const bgImage = getDjVisualImage(slot);

                              return (
                                <button
                                  key={`${day.key}-${key}`}
                                  type="button"
                                  onClick={() => toggleSelect(key)}
                                  className={`absolute rounded-xl border p-2 text-left overflow-hidden transition-all duration-200 ${
                                    selected
                                      ? 'border-primary-blue bg-primary-blue/20 shadow-[0_10px_30px_rgba(59,130,246,0.25)]'
                                      : 'border-white/20 bg-bg-elevated/95 hover:border-primary-purple/50 hover:-translate-y-[1px]'
                                  }`}
                                  style={{ top, left, width, height }}
                                >
                                  {bgImage && (
                                    <div
                                      className="absolute inset-0 bg-cover bg-center scale-110"
                                      style={{ backgroundImage: `url(${bgImage})` }}
                                    />
                                  )}
                                  <div className="absolute inset-0 bg-gradient-to-br from-black/70 via-black/55 to-black/75" />
                                  <div className="relative z-10 flex items-start gap-2">
                                    {slot.dj?.avatarUrl ? (
                                      <div className="relative h-9 w-9 rounded-full overflow-hidden border border-primary-blue/50 shrink-0">
                                        <Image src={slot.dj.avatarUrl} alt={djName} fill className="object-cover" sizes="36px" />
                                      </div>
                                    ) : (
                                      <div className="h-9 w-9 rounded-full shrink-0 border border-primary-purple/50 bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-white text-sm font-semibold">
                                        {letter}
                                      </div>
                                    )}
                                    <div className="min-w-0 relative">
                                      <p className="text-sm font-semibold text-white truncate">{djName}</p>
                                      <p className="text-[11px] text-white/80">
                                        {formatSlotTime(slot.startTime)} - {formatSlotTime(slot.endTime)}
                                      </p>
                                      <p className="text-[10px] text-white/75 mt-1">{stageName}</p>
                                    </div>
                                  </div>
                                </button>
                              );
                            })}
                          </div>
                        </div>
                      </div>
                    </div>
                  </section>
                );
              })}
            </div>

            <aside className="2xl:sticky 2xl:top-[58px] h-fit rounded-3xl border border-border-secondary bg-bg-elevated p-5">
              <h3 className="text-xl font-semibold text-text-primary mb-3">我的路线结果</h3>
              {planned.length === 0 ? (
                <p className="text-sm text-text-secondary">选择想看的时段后点击“生成我的日程”。</p>
              ) : (
                <div className="space-y-4">
                  {groupedPlanned.map((day) => (
                    <div key={day.dayKey} className="rounded-xl border border-border-secondary bg-bg-primary/40 p-3">
                      <p className="text-sm font-semibold text-text-primary mb-2">{day.label}</p>
                      <div className="space-y-2">
                        {day.items.map((item) => (
                          <div key={item.key + item.slot.startTime} className="rounded-lg bg-bg-secondary/70 border border-border-secondary p-2.5">
                            <p className="text-sm text-text-primary font-medium truncate">
                              {item.slot.djName || item.slot.dj?.name || 'Unknown DJ'}
                            </p>
                            <p className="text-xs text-text-tertiary">
                              {formatSlotTime(item.slot.startTime)} - {formatSlotTime(item.slot.endTime)} · {item.slot.stageName || '未命名舞台'}
                            </p>
                            {item.note && <p className="text-[11px] text-primary-blue mt-1">{item.note}</p>}
                          </div>
                        ))}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </aside>
          </div>
        </div>
      </div>

      <div className="fixed -left-[20000px] top-0 pointer-events-none opacity-100">
        <div
          ref={sharePosterRef}
          className="w-[1080px] p-10 text-white"
          style={{
            background:
              'radial-gradient(1200px 700px at 0% 0%, rgba(58,87,232,0.35) 0%, rgba(6,8,16,0.92) 45%), radial-gradient(1000px 600px at 100% 0%, rgba(149,54,215,0.35) 0%, rgba(6,8,16,0.92) 50%), #05070d',
          }}
        >
          <div className="flex items-center justify-between border border-white/15 bg-white/5 rounded-2xl px-6 py-4 mb-6 backdrop-blur">
            <div className="flex items-center gap-4">
              <img src="/icon.png" alt="RaveHub logo" className="h-10 w-10" />
              <div>
                <p className="text-2xl font-bold tracking-wide">RaveHub Festival Routine</p>
                <p className="text-sm text-white/70">{event?.name}</p>
              </div>
            </div>
            <div className="text-right">
              <p className="text-sm text-white/80">Generated at</p>
              <p className="text-sm">{new Date().toLocaleString('zh-CN')}</p>
            </div>
          </div>

          <div className="space-y-5">
            {groupedPlanned.map((day) => (
              <section key={`poster-${day.dayKey}`} className="rounded-2xl border border-white/15 bg-white/[0.04] p-5">
                <h3 className="text-xl font-semibold mb-4">{day.label}</h3>
                <div className="grid grid-cols-2 gap-4">
                  {day.items.map((item) => {
                    const djName = item.slot.djName || item.slot.dj?.name || 'Unknown DJ';
                    const bgImage = getDjVisualImage(item.slot);
                    return (
                      <div
                        key={`poster-slot-${item.key}-${item.slot.startTime}`}
                        className="relative rounded-xl border border-white/20 overflow-hidden min-h-[110px]"
                      >
                        {bgImage && (
                          <div
                            className="absolute inset-0 bg-cover bg-center scale-105"
                            style={{ backgroundImage: `url(${bgImage})` }}
                          />
                        )}
                        <div className="absolute inset-0 bg-gradient-to-r from-black/80 via-black/60 to-black/70" />
                        <div className="relative p-4">
                          <p className="text-base font-semibold leading-tight">{djName}</p>
                          <p className="text-sm text-white/85 mt-1">
                            {formatSlotTime(item.slot.startTime)} - {formatSlotTime(item.slot.endTime)}
                          </p>
                          <p className="text-xs text-white/80 mt-1">{item.slot.stageName || '未命名舞台'}</p>
                          {item.note && <p className="text-xs text-cyan-200 mt-2">{item.note}</p>}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </section>
            ))}
          </div>

          <div className="mt-6 flex justify-between items-center text-xs text-white/70">
            <span>www.ravehub.live</span>
            <span>Generated with RaveHub</span>
          </div>
        </div>
      </div>
    </div>
  );
}
