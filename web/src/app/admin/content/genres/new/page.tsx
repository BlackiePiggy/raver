'use client';

import Link from 'next/link';
import { Plus, Trash2 } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import EntityBindingField from '@/components/admin/EntityBindingField';
import {
  LocalizedTextField,
  MultilingualEditorOverlay,
  type LocalizedLocaleKey,
  type LocalizedTextValue,
} from '@/components/admin/LocalizedTextEditor';
import {
  genreAdminApi,
  type GenreAdminNode,
  type GenreKeyArtistBinding,
} from '@/features/admin-content/genre-admin';

type ParentMode = 'root' | 'existing' | 'new';
type ParentPlacementMode = 'root' | 'existing';
type LocalizedFieldKey = 'description' | 'example';

type KeyArtistDraft = {
  id: string;
  name: string;
  djId: string | null;
  dj: GenreKeyArtistBinding['dj'];
};

type CreateGenreDraft = {
  name: string;
  slug: string;
  sortOrder: string;
  parentMode: ParentMode;
  parentId: string;
  spotifyTrackURL: string;
  wikipediaURL: string;
  descriptionValue: LocalizedTextValue;
  exampleValue: LocalizedTextValue;
};

type NewParentDraft = {
  name: string;
  slug: string;
  sortOrder: string;
  placementMode: ParentPlacementMode;
  ancestorParentId: string;
};

type CreatedResult = {
  genre: {
    id: string;
    name: string;
    path: string;
  };
  parent: {
    id: string;
    name: string;
    path: string;
  } | null;
};

type FlatGenreNode = GenreAdminNode & {
  depth: number;
};

const emptyLocalizedValue = (): LocalizedTextValue => ({
  zh: '',
  en: '',
  ja: '',
  enFull: '',
});

const initialDraft = (): CreateGenreDraft => ({
  name: '',
  slug: '',
  sortOrder: '',
  parentMode: 'root',
  parentId: '',
  spotifyTrackURL: '',
  wikipediaURL: '',
  descriptionValue: emptyLocalizedValue(),
  exampleValue: emptyLocalizedValue(),
});

const initialNewParentDraft = (): NewParentDraft => ({
  name: '',
  slug: '',
  sortOrder: '',
  placementMode: 'root',
  ancestorParentId: '',
});

const flattenTree = (items: GenreAdminNode[], depth = 0): FlatGenreNode[] =>
  items.flatMap((item) => [{ ...item, depth }, ...flattenTree(item.children ?? [], depth + 1)]);

const makeDraftArtist = (): KeyArtistDraft => ({
  id: `draft-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
  name: '',
  djId: null,
  dj: null,
});

export default function AdminGenreCreatePage() {
  const [draft, setDraft] = useState<CreateGenreDraft>(initialDraft);
  const [newParentDraft, setNewParentDraft] = useState<NewParentDraft>(initialNewParentDraft);
  const [keyArtistDrafts, setKeyArtistDrafts] = useState<KeyArtistDraft[]>([]);
  const [tree, setTree] = useState<GenreAdminNode[]>([]);
  const [loadingTree, setLoadingTree] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [created, setCreated] = useState<CreatedResult | null>(null);
  const [activeLocalizedField, setActiveLocalizedField] = useState<LocalizedFieldKey | null>(null);

  const flatNodes = useMemo(() => flattenTree(tree), [tree]);
  const selectedParent = flatNodes.find((item) => item.id === draft.parentId) ?? null;
  const selectedAncestorParent = flatNodes.find((item) => item.id === newParentDraft.ancestorParentId) ?? null;
  const canSubmit = draft.name.trim().length > 0 && !saving;

  const loadTree = async () => {
    setLoadingTree(true);
    try {
      const payload = await genreAdminApi.fetchTree();
      setTree(payload.items);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Failed to load genre tree.');
    } finally {
      setLoadingTree(false);
    }
  };

  useEffect(() => {
    void loadTree();
  }, []);

  const updateLocalizedValue = (field: LocalizedFieldKey, locale: LocalizedLocaleKey, value: string) => {
    setDraft((current) => ({
      ...current,
      [field === 'description' ? 'descriptionValue' : 'exampleValue']: {
        ...(field === 'description' ? current.descriptionValue : current.exampleValue),
        [locale]: value,
      },
    }));
  };

  const addKeyArtistDraft = () => {
    setKeyArtistDrafts((current) => [...current, makeDraftArtist()]);
  };

  const updateKeyArtistDraft = (id: string, patch: Partial<KeyArtistDraft>) => {
    setKeyArtistDrafts((current) => current.map((item) => (item.id === id ? { ...item, ...patch } : item)));
  };

  const removeKeyArtistDraft = (id: string) => {
    setKeyArtistDrafts((current) => current.filter((item) => item.id !== id));
  };

  const resetForm = () => {
    setDraft(initialDraft());
    setNewParentDraft(initialNewParentDraft());
    setKeyArtistDrafts([]);
    setError('');
    setCreated(null);
    setActiveLocalizedField(null);
  };

  const validateBeforeSubmit = (): string | null => {
    if (!draft.name.trim()) return 'Genre name is required.';
    if (draft.parentMode === 'existing' && !draft.parentId) return 'Please select an existing parent genre.';
    if (draft.parentMode === 'new' && !newParentDraft.name.trim()) return 'Please enter the new parent genre name.';
    if (draft.parentMode === 'new' && newParentDraft.placementMode === 'existing' && !newParentDraft.ancestorParentId) {
      return 'Please select where the new parent genre should be placed.';
    }
    return null;
  };

  const handleSubmit = async () => {
    const validationError = validateBeforeSubmit();
    if (validationError) {
      setError(validationError);
      return;
    }

    setSaving(true);
    setError('');

    try {
      let resolvedParentId: string | null = null;
      let createdParent: CreatedResult['parent'] = null;

      if (draft.parentMode === 'existing') {
        resolvedParentId = draft.parentId;
      } else if (draft.parentMode === 'new') {
        const parentNode = await genreAdminApi.createNode({
          name: newParentDraft.name.trim(),
          parentId:
            newParentDraft.placementMode === 'existing' && newParentDraft.ancestorParentId
              ? newParentDraft.ancestorParentId
              : null,
          slug: newParentDraft.slug.trim() || null,
          sortOrder: newParentDraft.sortOrder.trim() ? Number(newParentDraft.sortOrder) : null,
        });
        resolvedParentId = parentNode.id;
        createdParent = {
          id: parentNode.id,
          name: parentNode.name,
          path: parentNode.path,
        };
      }

      const node = await genreAdminApi.createNode({
        name: draft.name.trim(),
        parentId: resolvedParentId,
        slug: draft.slug.trim() || null,
        sortOrder: draft.sortOrder.trim() ? Number(draft.sortOrder) : null,
      });

      await genreAdminApi.updateContent(node.id, {
        description: draft.descriptionValue.zh.trim() || null,
        descriptionI18n: draft.descriptionValue,
        example: draft.exampleValue.zh.trim() || null,
        exampleI18n: draft.exampleValue,
        spotifyTrackURL: draft.spotifyTrackURL.trim() || null,
        wikipediaURL: draft.wikipediaURL.trim() || null,
      });

      await genreAdminApi.updateKeyArtists(node.id, {
        keyArtists: keyArtistDrafts.map((item) => item.name.trim()).filter(Boolean),
        bindings: keyArtistDrafts
          .map((item) => ({
            name: item.name.trim(),
            djId: item.djId,
          }))
          .filter((item) => item.name),
      });

      setCreated({
        genre: {
          id: node.id,
          name: node.name,
          path: node.path,
        },
        parent: createdParent,
      });

      await loadTree();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Failed to create genre.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <AdminContentLayout
      title="New Genre"
      description="Create a root node, create under an existing parent, or create a brand-new parent first, then finish the new genre with localized content and DJ bindings."
      actions={
        <>
          <Link
            href="/admin/content"
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            Back to Content Console
          </Link>
          <Link
            href="/admin/content/genres"
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
          >
            Back to Genres
          </Link>
        </>
      }
    >
      {created ? (
        <section className="space-y-5">
          <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] p-6 text-[#2f4027]">
            <div className="text-xs uppercase tracking-[0.14em] text-[#52705c]">Created</div>
            <div className="mt-3 text-[30px] font-semibold tracking-[-0.04em] text-[#111827]">
              Genre created successfully
            </div>
            <div className="mt-4 space-y-2 text-sm leading-7 text-[#4a5b52]">
              <div>Name: {created.genre.name}</div>
              <div>Path: {created.genre.path}</div>
              <div>ID: {created.genre.id}</div>
              {created.parent ? <div>New parent created: {created.parent.path}</div> : null}
            </div>
          </div>

          <div className="flex flex-wrap gap-3">
            <Link
              href="/admin/content/genres"
              className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white"
            >
              Back to Genres
            </Link>
            <button
              type="button"
              onClick={resetForm}
              className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]"
            >
              Create another genre
            </button>
          </div>
        </section>
      ) : (
        <section className="space-y-5">
          {error ? (
            <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)] p-4 text-sm text-[#6a3530]">
              {error}
            </div>
          ) : null}

          <section className="admin-reference-card p-6">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <div className="text-xs uppercase tracking-[0.14em] text-black/38">Structure</div>
                <h2 className="mt-2 text-[22px] font-semibold text-[#111827]">Placement and hierarchy</h2>
                <div className="mt-1 text-sm text-black/48">
                  Choose whether this genre is a root node, a child of an existing node, or a child of a new parent created in the same flow.
                </div>
              </div>
              <button
                type="button"
                onClick={() => void handleSubmit()}
                disabled={!canSubmit}
                className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
              >
                {saving ? 'Creating...' : 'Create genre'}
              </button>
            </div>

            <div className="mt-5 grid gap-3 lg:grid-cols-3">
              {[
                {
                  key: 'root',
                  title: 'Root genre',
                  description: 'Create this genre at the top level of the tree.',
                },
                {
                  key: 'existing',
                  title: 'Existing parent',
                  description: 'Attach the new genre to a current node in the tree.',
                },
                {
                  key: 'new',
                  title: 'Create parent first',
                  description: 'Create a parent node in this flow, then create the new genre under it.',
                },
              ].map((item) => (
                <button
                  key={item.key}
                  type="button"
                  onClick={() =>
                    setDraft((current) => ({
                      ...current,
                      parentMode: item.key as ParentMode,
                      parentId: item.key === 'existing' ? current.parentId : '',
                    }))
                  }
                  className={`rounded-[20px] border px-4 py-4 text-left transition ${
                    draft.parentMode === item.key
                      ? 'border-[#c8ded0] bg-[#f6fbf7]'
                      : 'border-[#e8eceb] bg-white hover:border-[#d6ddda]'
                  }`}
                >
                  <div className="text-sm font-semibold text-[#111827]">{item.title}</div>
                  <div className="mt-2 text-sm leading-6 text-black/50">{item.description}</div>
                </button>
              ))}
            </div>

            {draft.parentMode === 'existing' ? (
              <div className="mt-5 grid gap-4 xl:grid-cols-[minmax(0,1fr)_320px]">
                <label className="block">
                  <div className="mb-2 admin-studio-label">Parent genre</div>
                  <select
                    value={draft.parentId}
                    onChange={(event) => setDraft((current) => ({ ...current, parentId: event.target.value }))}
                    className="admin-studio-input"
                  >
                    <option value="">{loadingTree ? 'Loading genre tree...' : 'Select a parent genre'}</option>
                    {flatNodes.map((item) => (
                      <option key={item.id} value={item.id}>
                        {`${'— '.repeat(item.depth)}${item.name}`}
                      </option>
                    ))}
                  </select>
                </label>
                <div className="admin-reference-soft-card p-4 text-sm text-black/55">
                  <div className="text-xs uppercase tracking-[0.14em] text-black/38">Selected parent</div>
                  <div className="mt-2 font-medium text-[#111827]">{selectedParent?.name || 'No parent selected yet'}</div>
                  <div className="mt-1 break-words leading-6">{selectedParent?.path || 'Choose a node from the tree to place this genre underneath it.'}</div>
                </div>
              </div>
            ) : null}

            {draft.parentMode === 'new' ? (
              <div className="mt-5 rounded-[24px] border border-[#e8eceb] bg-[#fbfcfb] p-5">
                <div className="text-sm font-semibold text-[#111827]">New parent genre</div>
                <div className="mt-1 text-sm text-black/48">
                  This parent will be created first, then the new genre will be created underneath it.
                </div>

                <div className="mt-4 grid gap-4 lg:grid-cols-3">
                  <input
                    className="admin-studio-input"
                    placeholder="Parent genre name"
                    value={newParentDraft.name}
                    onChange={(event) =>
                      setNewParentDraft((current) => ({
                        ...current,
                        name: event.target.value,
                      }))
                    }
                  />
                  <input
                    className="admin-studio-input"
                    placeholder="Parent slug (optional)"
                    value={newParentDraft.slug}
                    onChange={(event) =>
                      setNewParentDraft((current) => ({
                        ...current,
                        slug: event.target.value,
                      }))
                    }
                  />
                  <input
                    className="admin-studio-input"
                    placeholder="Parent sort order (optional)"
                    value={newParentDraft.sortOrder}
                    onChange={(event) =>
                      setNewParentDraft((current) => ({
                        ...current,
                        sortOrder: event.target.value,
                      }))
                    }
                  />
                </div>

                <div className="mt-4 grid gap-3 md:grid-cols-2">
                  {[
                    {
                      key: 'root',
                      title: 'New root parent',
                      description: 'Create the new parent at the root level.',
                    },
                    {
                      key: 'existing',
                      title: 'Place parent under existing node',
                      description: 'Create the parent under an existing node, then place this genre below it.',
                    },
                  ].map((item) => (
                    <button
                      key={item.key}
                      type="button"
                      onClick={() =>
                        setNewParentDraft((current) => ({
                          ...current,
                          placementMode: item.key as ParentPlacementMode,
                          ancestorParentId: item.key === 'existing' ? current.ancestorParentId : '',
                        }))
                      }
                      className={`rounded-[18px] border px-4 py-4 text-left transition ${
                        newParentDraft.placementMode === item.key
                          ? 'border-[#c8ded0] bg-white'
                          : 'border-[#e8eceb] bg-white/70 hover:border-[#d6ddda]'
                      }`}
                    >
                      <div className="text-sm font-semibold text-[#111827]">{item.title}</div>
                      <div className="mt-2 text-sm leading-6 text-black/50">{item.description}</div>
                    </button>
                  ))}
                </div>

                {newParentDraft.placementMode === 'existing' ? (
                  <div className="mt-4 grid gap-4 xl:grid-cols-[minmax(0,1fr)_320px]">
                    <label className="block">
                      <div className="mb-2 admin-studio-label">Parent for the new parent</div>
                      <select
                        value={newParentDraft.ancestorParentId}
                        onChange={(event) =>
                          setNewParentDraft((current) => ({
                            ...current,
                            ancestorParentId: event.target.value,
                          }))
                        }
                        className="admin-studio-input"
                      >
                        <option value="">{loadingTree ? 'Loading genre tree...' : 'Select an existing node'}</option>
                        {flatNodes.map((item) => (
                          <option key={item.id} value={item.id}>
                            {`${'— '.repeat(item.depth)}${item.name}`}
                          </option>
                        ))}
                      </select>
                    </label>
                    <div className="admin-reference-soft-card p-4 text-sm text-black/55">
                      <div className="text-xs uppercase tracking-[0.14em] text-black/38">New parent will live under</div>
                      <div className="mt-2 font-medium text-[#111827]">
                        {selectedAncestorParent?.name || 'No node selected yet'}
                      </div>
                      <div className="mt-1 break-words leading-6">
                        {selectedAncestorParent?.path || 'Choose an existing node if the new parent should not live at the root level.'}
                      </div>
                    </div>
                  </div>
                ) : null}
              </div>
            ) : null}
          </section>

          <section className="admin-reference-card p-6">
            <div className="text-xs uppercase tracking-[0.14em] text-black/38">Details</div>
            <h2 className="mt-2 text-[22px] font-semibold text-[#111827]">Genre profile</h2>
            <div className="mt-1 text-sm text-black/48">
              Fill the structural fields, multilingual content, and reference links that should exist at create time.
            </div>

            <div className="mt-5 grid gap-4 lg:grid-cols-3">
              <input
                className="admin-studio-input"
                placeholder="Genre name"
                value={draft.name}
                onChange={(event) => setDraft((current) => ({ ...current, name: event.target.value }))}
              />
              <input
                className="admin-studio-input"
                placeholder="Slug (optional)"
                value={draft.slug}
                onChange={(event) => setDraft((current) => ({ ...current, slug: event.target.value }))}
              />
              <input
                className="admin-studio-input"
                placeholder="Sort order (optional)"
                value={draft.sortOrder}
                onChange={(event) => setDraft((current) => ({ ...current, sortOrder: event.target.value }))}
              />
            </div>

            <div className="mt-4 grid gap-4 lg:grid-cols-2">
              <input
                className="admin-studio-input"
                placeholder="Spotify track URL (optional)"
                value={draft.spotifyTrackURL}
                onChange={(event) => setDraft((current) => ({ ...current, spotifyTrackURL: event.target.value }))}
              />
              <input
                className="admin-studio-input"
                placeholder="Wikipedia URL (optional)"
                value={draft.wikipediaURL}
                onChange={(event) => setDraft((current) => ({ ...current, wikipediaURL: event.target.value }))}
              />
            </div>

            <div className="mt-4 grid gap-4 xl:grid-cols-2">
              <LocalizedTextField
                label="Description"
                kind="textarea"
                value={draft.descriptionValue}
                placeholder="Primary Chinese description"
                hint="Use the language button to add English, Japanese, and full English variants."
                onPrimaryChange={(value) =>
                  setDraft((current) => ({
                    ...current,
                    descriptionValue: { ...current.descriptionValue, zh: value },
                  }))
                }
                onOpenOverlay={() => setActiveLocalizedField('description')}
              />
              <LocalizedTextField
                label="Example"
                kind="textarea"
                value={draft.exampleValue}
                placeholder="Primary Chinese example"
                hint="Add example phrases or representative context for this genre."
                onPrimaryChange={(value) =>
                  setDraft((current) => ({
                    ...current,
                    exampleValue: { ...current.exampleValue, zh: value },
                  }))
                }
                onOpenOverlay={() => setActiveLocalizedField('example')}
              />
            </div>
          </section>

          <section className="admin-reference-card p-6">
            <div className="flex items-center justify-between gap-3">
              <div>
                <div className="text-xs uppercase tracking-[0.14em] text-black/38">Bindings</div>
                <h2 className="mt-2 text-[22px] font-semibold text-[#111827]">Key artists</h2>
                <div className="mt-1 text-sm text-black/48">
                  Keep one artist per row, preserve the visible artist name, and optionally bind each row to a DJ in the library.
                </div>
              </div>
              <button
                type="button"
                onClick={addKeyArtistDraft}
                className="rounded-full border border-[#d7ded9] bg-white px-4 py-2 text-sm text-[#18211f]"
              >
                <span className="inline-flex items-center gap-2">
                  <Plus className="h-4 w-4" />
                  Add artist
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
                  <div key={item.id} className="rounded-[18px] border border-[#e8eceb] bg-white p-4">
                    <div className="flex items-center justify-between gap-3">
                      <div className="text-sm font-semibold text-[#111827]">Key artist #{index + 1}</div>
                      <button
                        type="button"
                        className="rounded-full border border-[#ead6d6] bg-white p-2 text-[#8b3a3a]"
                        onClick={() => removeKeyArtistDraft(item.id)}
                        aria-label="Remove key artist"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>

                    <input
                      className="admin-reference-soft-card mt-3 w-full px-4 py-3 text-sm"
                      placeholder="Artist name"
                      value={item.name}
                      onChange={(event) => updateKeyArtistDraft(item.id, { name: event.target.value })}
                    />

                    <div className="mt-3">
                      <EntityBindingField
                        kind="dj"
                        mode="single"
                        seedQuery={item.name}
                        items={currentBinding ? [currentBinding] : []}
                        title="Bound DJ"
                        emptyLabel="This artist is not bound to a DJ yet."
                        onAdd={(value) =>
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
                        onRemove={() =>
                          updateKeyArtistDraft(item.id, {
                            djId: null,
                            dj: null,
                          })
                        }
                      />
                    </div>
                  </div>
                );
              })}

              {!keyArtistDrafts.length ? (
                <div className="rounded-[16px] border border-dashed border-[#d7ded9] px-4 py-6 text-sm text-black/48">
                  No key artists yet. Add rows only if this genre needs representative artists at create time.
                </div>
              ) : null}
            </div>
          </section>
        </section>
      )}

      <MultilingualEditorOverlay
        open={activeLocalizedField === 'description'}
        title="Genre Description"
        kind="textarea"
        value={draft.descriptionValue}
        onChange={(locale, value) => updateLocalizedValue('description', locale, value)}
        onClose={() => setActiveLocalizedField(null)}
      />

      <MultilingualEditorOverlay
        open={activeLocalizedField === 'example'}
        title="Genre Example"
        kind="textarea"
        value={draft.exampleValue}
        onChange={(locale, value) => updateLocalizedValue('example', locale, value)}
        onClose={() => setActiveLocalizedField(null)}
      />
    </AdminContentLayout>
  );
}
