'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState, type Dispatch, type SetStateAction } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import EntityBindingField from '@/components/admin/EntityBindingField';
import type { EntityBindingValue } from '@/components/admin/EntityBindingSearch';
import { ratingAdminApi, type RatingEvent, type RatingUnit } from '@/features/admin-content/rating-admin';

type RatingUnitBindingDraft = {
  id: string;
  djId: string;
  name: string;
  subtitle?: string | null;
  imageUrl?: string | null;
};

const toBindingDrafts = (unit: RatingUnit | null): RatingUnitBindingDraft[] => {
  if (!unit?.linkedDJs?.length) return [];
  return unit.linkedDJs.map((dj, index) => ({
    id: `${unit.id}-binding-${index}-${dj.id}`,
    djId: dj.id,
    name: dj.name,
    subtitle: dj.country || null,
    imageUrl: dj.avatarUrl || dj.bannerUrl || null,
  }));
};

const toBindingValue = (item: RatingUnitBindingDraft): EntityBindingValue => ({
  id: item.djId,
  name: item.name,
  subtitle: item.subtitle || null,
  imageUrl: item.imageUrl || null,
});

export default function AdminRatingsPage() {
  const [items, setItems] = useState<RatingEvent[]>([]);
  const [selectedId, setSelectedId] = useState('');
  const [detail, setDetail] = useState<RatingEvent | null>(null);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [draft, setDraft] = useState({
    name: '',
    description: '',
    imageUrl: '',
    sourceEventId: '',
  });
  const [unitDraft, setUnitDraft] = useState({
    name: '',
    description: '',
    imageUrl: '',
  });
  const [newUnitBindings, setNewUnitBindings] = useState<RatingUnitBindingDraft[]>([]);
  const [editingUnitId, setEditingUnitId] = useState('');
  const [editingUnitDraft, setEditingUnitDraft] = useState({
    name: '',
    description: '',
    imageUrl: '',
  });
  const [editingUnitBindings, setEditingUnitBindings] = useState<RatingUnitBindingDraft[]>([]);

  const selectedItem = useMemo(() => items.find((item) => item.id === selectedId) ?? null, [items, selectedId]);
  const editingUnit = useMemo(
    () => detail?.units.find((unit) => unit.id === editingUnitId) ?? null,
    [detail, editingUnitId]
  );

  const loadEvents = async (preferredId?: string) => {
    setLoading(true);
    setError('');
    try {
      const payload = await ratingAdminApi.listEvents();
      setItems(payload.items);
      const nextId = (preferredId ?? selectedId) || payload.items[0]?.id || '';
      setSelectedId(nextId);
      if (nextId) {
        const nextDetail = await ratingAdminApi.fetchEvent(nextId);
        setDetail(nextDetail);
      } else {
        setDetail(null);
      }
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Failed to load rating events.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadEvents();
  }, []);

  useEffect(() => {
    if (!selectedId) return;
    setLoading(true);
    setError('');
    void ratingAdminApi
      .fetchEvent(selectedId)
      .then((payload) => setDetail(payload))
      .catch((nextError) => setError(nextError instanceof Error ? nextError.message : 'Failed to load rating event detail.'))
      .finally(() => setLoading(false));
  }, [selectedId]);

  useEffect(() => {
    if (!editingUnit) return;
    setEditingUnitDraft({
      name: editingUnit.name,
      description: editingUnit.description || '',
      imageUrl: editingUnit.imageUrl || '',
    });
    setEditingUnitBindings(toBindingDrafts(editingUnit));
  }, [editingUnit]);

  const handleCreateEvent = async () => {
    setSaving(true);
    setError('');
    setNotice('');
    try {
      const created = draft.sourceEventId.trim()
        ? await ratingAdminApi.createEventFromEvent(draft.sourceEventId.trim())
        : await ratingAdminApi.createEvent({
            name: draft.name,
            description: draft.description || undefined,
            imageUrl: draft.imageUrl || null,
          });
      setNotice(`Created rating event: ${created.name}`);
      await loadEvents(created.id);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Failed to create rating event.');
    } finally {
      setSaving(false);
    }
  };

  const handleCreateUnit = async () => {
    if (!selectedId) return;
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await ratingAdminApi.createUnit(selectedId, {
        name: unitDraft.name,
        description: unitDraft.description || undefined,
        imageUrl: unitDraft.imageUrl || null,
        djIds: newUnitBindings.map((item) => item.djId).filter(Boolean),
      });
      setNotice('Added rating unit.');
      setUnitDraft({ name: '', description: '', imageUrl: '' });
      setNewUnitBindings([]);
      const nextDetail = await ratingAdminApi.fetchEvent(selectedId);
      setDetail(nextDetail);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Failed to create rating unit.');
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteEvent = async () => {
    if (!selectedId) return;
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await ratingAdminApi.deleteEvent(selectedId);
      setNotice('Deleted rating event.');
      await loadEvents();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Failed to delete rating event.');
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteUnit = async (unitId: string) => {
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await ratingAdminApi.deleteUnit(unitId);
      setNotice('Deleted rating unit.');
      if (editingUnitId === unitId) {
        setEditingUnitId('');
        setEditingUnitBindings([]);
      }
      if (selectedId) {
        const nextDetail = await ratingAdminApi.fetchEvent(selectedId);
        setDetail(nextDetail);
      }
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Failed to delete rating unit.');
    } finally {
      setSaving(false);
    }
  };

  const handleSaveUnit = async () => {
    if (!editingUnitId) return;
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await ratingAdminApi.updateUnit(editingUnitId, {
        name: editingUnitDraft.name,
        description: editingUnitDraft.description || null,
        imageUrl: editingUnitDraft.imageUrl || null,
        djIds: editingUnitBindings.map((item) => item.djId).filter(Boolean),
      });
      setNotice('Updated rating unit.');
      if (selectedId) {
        const nextDetail = await ratingAdminApi.fetchEvent(selectedId);
        setDetail(nextDetail);
      }
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Failed to update rating unit.');
    } finally {
      setSaving(false);
    }
  };

  const addBindingToDraft = (
    setter: Dispatch<SetStateAction<RatingUnitBindingDraft[]>>,
    value: EntityBindingValue
  ) => {
    setter((current) => {
      if (current.some((item) => item.djId === value.id)) return current;
      return [
        ...current,
        {
          id: `${value.id}-${Date.now()}`,
          djId: value.id,
          name: value.name,
          subtitle: value.subtitle || null,
          imageUrl: value.imageUrl || null,
        },
      ];
    });
  };

  const removeBindingFromDraft = (
    setter: Dispatch<SetStateAction<RatingUnitBindingDraft[]>>,
    djId: string
  ) => {
    setter((current) => current.filter((item) => item.djId !== djId));
  };

  return (
    <AdminContentLayout
      title="Rating Management"
      description="Manage rating events, rating units, source event mapping, and reusable DJ bindings."
      actions={
        <Link href="/admin/content" className="rounded-full border border-[#ececec] bg-white px-5 py-3 text-sm text-[#18211f]">
          Back to Content Console
        </Link>
      }
    >
      <section className="space-y-5">
        {error ? <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)] p-4 text-sm text-[#6a3530]">{error}</div> : null}
        {notice ? <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] p-4 text-sm text-[#2f4027]">{notice}</div> : null}

        <div className="grid gap-5 xl:grid-cols-[360px_minmax(0,1fr)]">
          <section className="admin-reference-card p-5">
            <div className="flex items-center justify-between">
              <h2 className="text-[20px] font-semibold text-[#111827]">Rating Events</h2>
              <span className="admin-reference-chip">{items.length}</span>
            </div>
            <div className="mt-4 space-y-3">
              {items.map((item) => (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => setSelectedId(item.id)}
                  className={`admin-reference-soft-card w-full rounded-[20px] px-4 py-4 text-left ${
                    selectedId === item.id ? 'border border-[#d7e8dc] bg-[#f6fbf7]' : ''
                  }`}
                >
                  <div className="text-[16px] font-semibold text-[#111827]">{item.name}</div>
                  <div className="mt-2 text-xs text-black/48">{item.id}</div>
                  <div className="mt-2 text-sm text-black/52">Units: {item.units.length}</div>
                </button>
              ))}
              {!items.length && !loading ? <div className="admin-reference-soft-card p-4 text-sm text-black/48">No rating events yet.</div> : null}
            </div>
          </section>

          <div className="space-y-5">
            <section className="admin-reference-card p-5">
              <h2 className="text-[20px] font-semibold text-[#111827]">Create Rating Event</h2>
              <div className="mt-4 grid gap-4 md:grid-cols-2">
                <input className="admin-reference-soft-card px-4 py-3 text-sm" placeholder="Event name" value={draft.name} onChange={(event) => setDraft((prev) => ({ ...prev, name: event.target.value }))} />
                <input className="admin-reference-soft-card px-4 py-3 text-sm" placeholder="Source Event ID (optional)" value={draft.sourceEventId} onChange={(event) => setDraft((prev) => ({ ...prev, sourceEventId: event.target.value }))} />
              </div>
              <textarea className="admin-reference-soft-card mt-4 min-h-[110px] w-full px-4 py-3 text-sm" placeholder="Description" value={draft.description} onChange={(event) => setDraft((prev) => ({ ...prev, description: event.target.value }))} />
              <input className="admin-reference-soft-card mt-4 w-full px-4 py-3 text-sm" placeholder="Image URL (optional)" value={draft.imageUrl} onChange={(event) => setDraft((prev) => ({ ...prev, imageUrl: event.target.value }))} />
              <button type="button" className="mt-4 rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white" disabled={saving} onClick={handleCreateEvent}>
                {saving ? 'Saving...' : draft.sourceEventId.trim() ? 'Create from event' : 'Create rating event'}
              </button>
            </section>

            <section className="admin-reference-card p-5">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <h2 className="text-[20px] font-semibold text-[#111827]">Current Event</h2>
                  <div className="mt-1 text-sm text-black/48">{selectedItem ? selectedItem.name : 'Select a rating event from the left.'}</div>
                </div>
                <button type="button" className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm" disabled={!selectedId || saving} onClick={handleDeleteEvent}>
                  Delete Rating Event
                </button>
              </div>
              {detail ? (
                <div className="mt-4 space-y-5">
                  <div className="admin-reference-soft-card p-4 text-sm text-black/65">
                    <div>Source event: {detail.sourceEventId || 'Not linked'}</div>
                    <div className="mt-1">Rating units: {detail.units.length}</div>
                  </div>

                  <div className="admin-reference-soft-card p-4">
                    <div className="text-sm font-semibold text-[#111827]">Add Rating Unit</div>
                    <div className="mt-3 grid gap-3 md:grid-cols-2">
                      <input className="rounded-[16px] border border-[#e8eceb] bg-white px-3 py-2 text-sm" placeholder="Unit name" value={unitDraft.name} onChange={(event) => setUnitDraft((prev) => ({ ...prev, name: event.target.value }))} />
                      <input className="rounded-[16px] border border-[#e8eceb] bg-white px-3 py-2 text-sm" placeholder="Image URL (optional)" value={unitDraft.imageUrl} onChange={(event) => setUnitDraft((prev) => ({ ...prev, imageUrl: event.target.value }))} />
                    </div>
                    <textarea className="mt-3 min-h-[90px] w-full rounded-[16px] border border-[#e8eceb] bg-white px-3 py-2 text-sm" placeholder="Description" value={unitDraft.description} onChange={(event) => setUnitDraft((prev) => ({ ...prev, description: event.target.value }))} />
                    <div className="mt-4">
                      <EntityBindingField
                        kind="dj"
                        mode="multiple"
                        seedQuery={unitDraft.name}
                        items={newUnitBindings.map(toBindingValue)}
                        title="Bound DJs"
                        emptyLabel="No DJs bound to this rating unit yet."
                        onAdd={(value) => addBindingToDraft(setNewUnitBindings, value)}
                        onRemove={(value) => removeBindingFromDraft(setNewUnitBindings, value.id)}
                      />
                    </div>
                    <button type="button" className="mt-4 rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white" disabled={saving} onClick={handleCreateUnit}>
                      {saving ? 'Saving...' : 'Add rating unit'}
                    </button>
                  </div>

                  <div className="space-y-3">
                    {detail.units.map((unit) => {
                      const isEditing = editingUnitId === unit.id;
                      return (
                        <div key={unit.id} className="admin-reference-soft-card p-4">
                          <div className="flex flex-wrap items-start justify-between gap-3">
                            <div>
                              <div className="text-[15px] font-semibold text-[#111827]">{unit.name}</div>
                              <div className="mt-1 text-xs text-black/48">{unit.id}</div>
                              <div className="mt-2 text-sm text-black/56">{unit.description || 'No description'}</div>
                              <div className="mt-2 text-xs text-black/45">Bound DJs: {unit.linkedDJs?.length || 0}</div>
                            </div>
                            <div className="flex flex-wrap gap-2">
                              <button
                                type="button"
                                className="rounded-full border border-[#d7ded9] bg-white px-3 py-2 text-sm text-[#18211f]"
                                onClick={() => setEditingUnitId(isEditing ? '' : unit.id)}
                              >
                                {isEditing ? 'Collapse editor' : 'Edit bindings'}
                              </button>
                              <button
                                type="button"
                                className="rounded-full border border-[#ead6d6] bg-white px-3 py-2 text-sm text-[#8b3a3a]"
                                onClick={() => void handleDeleteUnit(unit.id)}
                                disabled={saving}
                              >
                                Delete
                              </button>
                            </div>
                          </div>

                          {unit.linkedDJs?.length ? (
                            <div className="mt-3 flex flex-wrap gap-2">
                              {unit.linkedDJs.map((dj) => (
                                <span key={`${unit.id}-${dj.id}`} className="admin-reference-chip">
                                  {dj.name}
                                </span>
                              ))}
                            </div>
                          ) : null}

                          {isEditing ? (
                            <div className="mt-4 space-y-4 border-t border-[#ecefec] pt-4">
                              <div className="grid gap-3 md:grid-cols-2">
                                <input className="rounded-[16px] border border-[#e8eceb] bg-white px-3 py-2 text-sm" value={editingUnitDraft.name} placeholder="Unit name" onChange={(event) => setEditingUnitDraft((prev) => ({ ...prev, name: event.target.value }))} />
                                <input className="rounded-[16px] border border-[#e8eceb] bg-white px-3 py-2 text-sm" value={editingUnitDraft.imageUrl} placeholder="Image URL (optional)" onChange={(event) => setEditingUnitDraft((prev) => ({ ...prev, imageUrl: event.target.value }))} />
                              </div>
                              <textarea className="min-h-[90px] w-full rounded-[16px] border border-[#e8eceb] bg-white px-3 py-2 text-sm" value={editingUnitDraft.description} placeholder="Description" onChange={(event) => setEditingUnitDraft((prev) => ({ ...prev, description: event.target.value }))} />

                              <EntityBindingField
                                kind="dj"
                                mode="multiple"
                                seedQuery={editingUnitDraft.name || unit.name}
                                items={editingUnitBindings.map(toBindingValue)}
                                title="Bound DJs"
                                emptyLabel="No DJs bound to this rating unit yet."
                                onAdd={(value) => addBindingToDraft(setEditingUnitBindings, value)}
                                onRemove={(value) => removeBindingFromDraft(setEditingUnitBindings, value.id)}
                              />

                              <button type="button" className="rounded-full bg-[#071110] px-4 py-2 text-sm font-semibold text-white" disabled={saving} onClick={() => void handleSaveUnit()}>
                                {saving ? 'Saving...' : 'Save rating unit'}
                              </button>
                            </div>
                          ) : null}
                        </div>
                      );
                    })}
                    {!detail.units.length ? <div className="admin-reference-soft-card p-4 text-sm text-black/48">No rating units yet.</div> : null}
                  </div>
                </div>
              ) : (
                <div className="admin-reference-soft-card mt-4 p-4 text-sm text-black/48">{loading ? 'Loading...' : 'Select a rating event to inspect details.'}</div>
              )}
            </section>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
