'use client';

import Link from 'next/link';
import { ChevronDown, ChevronRight, Languages, Plus, Trash2 } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import EditableEntityBindingCard from '@/components/admin/EditableEntityBindingCard';
import {
  MultilingualEditorOverlay,
  type LocalizedLocaleKey,
  type LocalizedTextValue,
  localizedTextFilledLocaleLabels,
} from '@/components/admin/LocalizedTextEditor';
import { genreAdminApi, type GenreAdminNode, type GenreKeyArtistBinding } from '@/features/admin-content/genre-admin';

const flattenTree = (items: GenreAdminNode[]): GenreAdminNode[] =>
  items.flatMap((item) => [item, ...flattenTree(item.children ?? [])]);

const normalizeLocalizedValue = (value?: Record<string, string> | null, fallback = ''): LocalizedTextValue => ({
  zh: value?.zh || fallback || '',
  en: value?.en || '',
  ja: value?.ja || '',
  enFull: value?.enFull || '',
});

type LocalizedFieldKey = 'description' | 'example';

type KeyArtistDraft = {
  id: string;
  name: string;
  djId: string | null;
  dj: GenreKeyArtistBinding['dj'];
};

function GenreTreeNode({
  item,
  selectedId,
  expandedIds,
  onSelect,
  onToggle,
  level = 0,
}: {
  item: GenreAdminNode;
  selectedId: string;
  expandedIds: Set<string>;
  onSelect: (id: string) => void;
  onToggle: (id: string) => void;
  level?: number;
}) {
  const hasChildren = Boolean(item.children?.length);
  const isExpanded = expandedIds.has(item.id);
  const isSelected = selectedId === item.id;

  return (
    <div className="space-y-2">
      <div
        className={`admin-reference-soft-card rounded-[18px] px-4 py-3 ${
          isSelected ? 'border border-[#d7e8dc] bg-[#f6fbf7]' : ''
        }`}
        style={{ marginLeft: `${level * 18}px` }}
      >
        <div className="flex items-start gap-3">
          <button
            type="button"
            className="mt-0.5 rounded-full p-1 text-black/45 transition hover:bg-black/5 disabled:opacity-30"
            onClick={() => hasChildren && onToggle(item.id)}
            disabled={!hasChildren}
            aria-label={hasChildren ? 'Expand or collapse child genres' : 'No child genres'}
          >
            {hasChildren ? (
              isExpanded ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />
            ) : (
              <div className="h-4 w-4" />
            )}
          </button>
          <button type="button" className="min-w-0 flex-1 text-left" onClick={() => onSelect(item.id)}>
            <div className="text-sm font-semibold text-[#111827]">{item.name}</div>
            <div className="mt-1 break-words text-xs leading-5 text-black/45">{item.path}</div>
          </button>
          <span className="admin-reference-chip shrink-0">{item.children?.length ?? 0}</span>
        </div>
      </div>

      {hasChildren && isExpanded ? (
        <div className="space-y-2">
          {item.children!.map((child) => (
            <GenreTreeNode
              key={child.id}
              item={child}
              selectedId={selectedId}
              expandedIds={expandedIds}
              onSelect={onSelect}
              onToggle={onToggle}
              level={level + 1}
            />
          ))}
        </div>
      ) : null}
    </div>
  );
}

export default function AdminGenresPage() {
  const [tree, setTree] = useState<GenreAdminNode[]>([]);
  const [expandedIds, setExpandedIds] = useState<Set<string>>(new Set());
  const [selectedId, setSelectedId] = useState('');
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [descriptionValue, setDescriptionValue] = useState<LocalizedTextValue>(() => normalizeLocalizedValue(null));
  const [exampleValue, setExampleValue] = useState<LocalizedTextValue>(() => normalizeLocalizedValue(null));
  const [spotifyTrackURL, setSpotifyTrackURL] = useState('');
  const [wikipediaURL, setWikipediaURL] = useState('');
  const [activeLocalizedField, setActiveLocalizedField] = useState<LocalizedFieldKey | null>(null);
  const [keyArtistDrafts, setKeyArtistDrafts] = useState<KeyArtistDraft[]>([]);

  const flatNodes = useMemo(() => flattenTree(tree), [tree]);
  const selectedNode = flatNodes.find((item) => item.id === selectedId) ?? null;

  const openLocalizedField = (field: LocalizedFieldKey) => {
    setActiveLocalizedField(field);
  };

  const loadTree = async (preferredId?: string) => {
    setLoading(true);
    setError('');
    try {
      const payload = await genreAdminApi.fetchTree();
      setTree(payload.items);
      const nextFlat = flattenTree(payload.items);
      const nextId = (preferredId ?? selectedId) || nextFlat[0]?.id || '';
      setSelectedId(nextId);
      setExpandedIds((current) => {
        const next = new Set(current);
        nextFlat.forEach((item) => {
          const segments = item.path.split(' / ');
          if (segments.length > 1 && item.parentId) next.add(item.parentId);
        });
        return next;
      });
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Failed to load genre tree.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadTree();
  }, []);

  useEffect(() => {
    if (!selectedNode) return;
    setDescriptionValue(normalizeLocalizedValue(selectedNode.descriptionI18n, selectedNode.description || ''));
    setExampleValue(normalizeLocalizedValue(selectedNode.exampleI18n, selectedNode.example || ''));
    setSpotifyTrackURL(selectedNode.spotifyTrackURL || '');
    setWikipediaURL(selectedNode.wikipediaURL || '');
    setKeyArtistDrafts(
      (selectedNode.keyArtistBindings.length
        ? selectedNode.keyArtistBindings
        : selectedNode.keyArtists.map((name) => ({ name, djId: null, dj: null }))).map((item, index) => ({
        id: `${selectedNode.id}-artist-${index}-${item.name}`,
        name: item.name,
        djId: item.djId,
        dj: item.dj,
      }))
    );
  }, [selectedNode]);

  const toggleExpanded = (id: string) => {
    setExpandedIds((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const handleSaveContent = async () => {
    if (!selectedNode) return;
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await genreAdminApi.updateContent(selectedNode.id, {
        description: descriptionValue.zh,
        descriptionI18n: descriptionValue,
        example: exampleValue.zh,
        exampleI18n: exampleValue,
        spotifyTrackURL: spotifyTrackURL.trim() || null,
        wikipediaURL: wikipediaURL.trim() || null,
      });
      await genreAdminApi.updateKeyArtists(selectedNode.id, {
        keyArtists: keyArtistDrafts.map((item) => item.name.trim()).filter(Boolean),
        bindings: keyArtistDrafts
          .map((item) => ({
            name: item.name.trim(),
            djId: item.djId,
          }))
          .filter((item) => item.name),
      });
      setNotice('Updated genre content.');
      await loadTree(selectedNode.id);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Failed to update genre content.');
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteNode = async () => {
    if (!selectedNode) return;
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await genreAdminApi.deleteNode(selectedNode.id);
      setNotice('Deleted genre node.');
      await loadTree();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Failed to delete genre node.');
    } finally {
      setSaving(false);
    }
  };

  const handleAutoMatch = async () => {
    setSaving(true);
    setError('');
    setNotice('');
    try {
      const result = await genreAdminApi.autoMatchKeyArtists();
      setNotice(`Auto-match finished: matched ${result.matched} of ${result.totalArtists}, updated ${result.updatedGenres} genres.`);
      await loadTree(selectedId);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Failed to auto-match key artists.');
    } finally {
      setSaving(false);
    }
  };

  const updateLocalizedValue = (field: LocalizedFieldKey, locale: LocalizedLocaleKey, value: string) => {
    if (field === 'description') {
      setDescriptionValue((current) => ({ ...current, [locale]: value }));
      return;
    }
    setExampleValue((current) => ({ ...current, [locale]: value }));
  };

  const addKeyArtistDraft = () => {
    setKeyArtistDrafts((current) => [
      ...current,
      {
        id: `draft-${Date.now()}-${current.length}`,
        name: '',
        djId: null,
        dj: null,
      },
    ]);
  };

  const updateKeyArtistDraft = (id: string, patch: Partial<KeyArtistDraft>) => {
    setKeyArtistDrafts((current) =>
      current.map((item) => (item.id === id ? { ...item, ...patch } : item))
    );
  };

  const removeKeyArtistDraft = (id: string) => {
    setKeyArtistDrafts((current) => current.filter((item) => item.id !== id));
  };

  return (
    <AdminContentLayout
      title="Genre Management"
      description="Manage hierarchical genre nodes, multilingual descriptions, and reusable DJ bindings for key artists."
      actions={
        <>
          <Link href="/admin/content" className="rounded-full border border-[#ececec] bg-white px-5 py-3 text-sm text-[#18211f]">
            Back to Content Console
          </Link>
          <Link href="/admin/content/genres/new" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            New Genre
          </Link>
        </>
      }
    >
      <section className="space-y-5">
        {error ? <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)] p-4 text-sm text-[#6a3530]">{error}</div> : null}
        {notice ? <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] p-4 text-sm text-[#2f4027]">{notice}</div> : null}

        <div className="grid gap-5 xl:grid-cols-[560px_minmax(0,1fr)]">
          <section className="admin-reference-card p-5">
            <div className="flex items-center justify-between gap-3">
              <div>
                <h2 className="text-[20px] font-semibold text-[#111827]">Genre Tree</h2>
                <div className="mt-1 text-sm text-black/48">Expand multiple levels and inspect full genre paths.</div>
              </div>
              <button type="button" className="rounded-full border border-[#d7ded9] px-4 py-2 text-sm" onClick={handleAutoMatch} disabled={saving}>
                Auto-match Key Artists
              </button>
            </div>

            <div className="mt-4 max-h-[780px] overflow-auto pr-2">
              {tree.length ? (
                <div className="space-y-2">
                  {tree.map((item) => (
                    <GenreTreeNode
                      key={item.id}
                      item={item}
                      selectedId={selectedId}
                      expandedIds={expandedIds}
                      onSelect={setSelectedId}
                      onToggle={toggleExpanded}
                    />
                  ))}
                </div>
              ) : (
                <div className="admin-reference-soft-card p-4 text-sm text-black/48">{loading ? 'Loading...' : 'No genre data yet.'}</div>
              )}
            </div>
          </section>

          <section className="admin-reference-card p-5">
            <div className="flex items-center justify-between gap-3">
              <div>
                <h2 className="text-[20px] font-semibold text-[#111827]">Node Editor</h2>
                <div className="mt-1 text-sm text-black/48">{selectedNode ? selectedNode.path : 'Select a node from the tree.'}</div>
              </div>
              <button type="button" className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm" disabled={!selectedNode || saving} onClick={handleDeleteNode}>
                Delete Node
              </button>
            </div>

            {selectedNode ? (
              <div className="mt-4 space-y-5">
                <div className="admin-reference-soft-card p-4 text-sm text-black/65">
                  <div>Name: {selectedNode.name}</div>
                  <div className="mt-1">Path: {selectedNode.path}</div>
                </div>

                <div className="grid gap-4 xl:grid-cols-2">
                  <div className="admin-reference-soft-card p-4">
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <div className="text-sm font-semibold text-[#111827]">Description</div>
                        <div className="mt-1 text-xs text-black/48">
                          Filled locales: {localizedTextFilledLocaleLabels(descriptionValue).join(' / ') || 'None'}
                        </div>
                      </div>
                      <button
                        type="button"
                        className="rounded-full border border-[#d7ded9] bg-white px-3 py-2 text-sm text-[#18211f]"
                        onClick={() => openLocalizedField('description')}
                      >
                        <span className="inline-flex items-center gap-2">
                          <Languages className="h-4 w-4" />
                          Languages
                        </span>
                      </button>
                    </div>
                    <div className="mt-3 rounded-[16px] border border-[#e8eceb] bg-white px-4 py-3 text-sm leading-7 text-[#111827]">
                      {descriptionValue.zh || 'No Chinese description yet.'}
                    </div>
                  </div>

                  <div className="admin-reference-soft-card p-4">
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <div className="text-sm font-semibold text-[#111827]">Example</div>
                        <div className="mt-1 text-xs text-black/48">
                          Filled locales: {localizedTextFilledLocaleLabels(exampleValue).join(' / ') || 'None'}
                        </div>
                      </div>
                      <button
                        type="button"
                        className="rounded-full border border-[#d7ded9] bg-white px-3 py-2 text-sm text-[#18211f]"
                        onClick={() => openLocalizedField('example')}
                      >
                        <span className="inline-flex items-center gap-2">
                          <Languages className="h-4 w-4" />
                          Languages
                        </span>
                      </button>
                    </div>
                    <div className="mt-3 rounded-[16px] border border-[#e8eceb] bg-white px-4 py-3 text-sm leading-7 text-[#111827]">
                      {exampleValue.zh || 'No example yet.'}
                    </div>
                  </div>
                </div>

                <div className="grid gap-4 xl:grid-cols-2">
                  <label className="block">
                    <div className="mb-2 text-sm font-semibold text-[#111827]">Spotify Track URL</div>
                    <input
                      className="admin-studio-input"
                      placeholder="Spotify track URL"
                      value={spotifyTrackURL}
                      onChange={(event) => setSpotifyTrackURL(event.target.value)}
                    />
                  </label>
                  <label className="block">
                    <div className="mb-2 text-sm font-semibold text-[#111827]">Wikipedia URL</div>
                    <input
                      className="admin-studio-input"
                      placeholder="Wikipedia URL"
                      value={wikipediaURL}
                      onChange={(event) => setWikipediaURL(event.target.value)}
                    />
                  </label>
                </div>

                <div className="admin-reference-soft-card p-4">
                  <div className="flex items-center justify-between gap-3">
                    <div>
                      <div className="text-sm font-semibold text-[#111827]">Key Artists</div>
                      <div className="mt-1 text-xs text-black/48">Each row keeps its own artist name and a single DJ binding.</div>
                    </div>
                    <button type="button" className="rounded-full border border-[#d7ded9] bg-white px-3 py-2 text-sm text-[#18211f]" onClick={addKeyArtistDraft}>
                      <span className="inline-flex items-center gap-2">
                        <Plus className="h-4 w-4" />
                        Add Artist
                      </span>
                    </button>
                  </div>

                  <div className="mt-4 space-y-4">
                    {keyArtistDrafts.map((item, index) => {
                      const currentBinding = item.dj
                        ? {
                            id: item.dj.id,
                            name: item.dj.name,
                            subtitle: null,
                            imageUrl: item.dj.avatarMediumUrl || item.dj.avatarUrl || null,
                          }
                        : null;

                      return (
                        <EditableEntityBindingCard
                          key={item.id}
                          header={`Key Artist #${index + 1}`}
                          name={item.name}
                          nameValue={item.name}
                          namePlaceholder="Artist name"
                          bindingKind="dj"
                          binding={currentBinding}
                          seedQuery={item.name}
                          bindingTitle="Bound DJ"
                          bindingEmptyLabel="This key artist is not linked to a DJ yet."
                          confirmedMeta={null}
                          boundLabel="Bound"
                          unboundLabel="Unbound"
                          onNameChange={(value) => updateKeyArtistDraft(item.id, { name: value })}
                          onAddBinding={(value) =>
                            updateKeyArtistDraft(item.id, {
                              djId: value.id,
                              dj: {
                                id: value.id,
                                name: value.name,
                                avatarUrl: value.imageUrl || null,
                                avatarMediumUrl: value.imageUrl || null,
                              },
                            })
                          }
                          onRemoveBinding={() =>
                            updateKeyArtistDraft(item.id, {
                              djId: null,
                              dj: null,
                            })
                          }
                          onDelete={() => removeKeyArtistDraft(item.id)}
                        />
                      );
                    })}

                    {!keyArtistDrafts.length ? (
                      <div className="rounded-[16px] border border-dashed border-[#d7ded9] px-4 py-6 text-sm text-black/48">
                        No key artists yet. Use the button above to add one.
                      </div>
                    ) : null}
                  </div>
                </div>

                <button type="button" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white" disabled={saving} onClick={handleSaveContent}>
                  {saving ? 'Saving...' : 'Save node content'}
                </button>
              </div>
            ) : (
              <div className="admin-reference-soft-card mt-4 p-4 text-sm text-black/48">{loading ? 'Loading...' : 'Select a genre node to inspect details.'}</div>
            )}
          </section>
        </div>
      </section>

      <MultilingualEditorOverlay
        open={activeLocalizedField === 'description'}
        title="Genre Description"
        kind="textarea"
        value={descriptionValue}
        onChange={(locale, value) => updateLocalizedValue('description', locale, value)}
        onClose={() => setActiveLocalizedField(null)}
      />

      <MultilingualEditorOverlay
        open={activeLocalizedField === 'example'}
        title="Genre Example"
        kind="textarea"
        value={exampleValue}
        onChange={(locale, value) => updateLocalizedValue('example', locale, value)}
        onClose={() => setActiveLocalizedField(null)}
      />
    </AdminContentLayout>
  );
}
