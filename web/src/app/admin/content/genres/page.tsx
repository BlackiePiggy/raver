'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import { genreAdminApi, type GenreAdminNode } from '@/features/admin-content/genre-admin';

const flattenTree = (items: GenreAdminNode[]): GenreAdminNode[] =>
  items.flatMap((item) => [item, ...flattenTree(item.children ?? [])]);

function GenreTree({
  items,
  selectedId,
  onSelect,
  level = 0,
}: {
  items: GenreAdminNode[];
  selectedId: string;
  onSelect: (id: string) => void;
  level?: number;
}) {
  return (
    <div className="space-y-2">
      {items.map((item) => (
        <div key={item.id}>
          <button
            type="button"
            onClick={() => onSelect(item.id)}
            className={`admin-reference-soft-card flex w-full items-center justify-between rounded-[18px] px-4 py-3 text-left ${
              selectedId === item.id ? 'border border-[#d7e8dc] bg-[#f6fbf7]' : ''
            }`}
            style={{ marginLeft: `${level * 12}px` }}
          >
            <div>
              <div className="text-sm font-semibold text-[#111827]">{item.name}</div>
              <div className="mt-1 text-xs text-black/45">{item.path}</div>
            </div>
            <span className="admin-reference-chip">{item.children?.length ?? 0}</span>
          </button>
          {item.children?.length ? <div className="mt-2"><GenreTree items={item.children} selectedId={selectedId} onSelect={onSelect} level={level + 1} /></div> : null}
        </div>
      ))}
    </div>
  );
}

export default function AdminGenresPage() {
  const [tree, setTree] = useState<GenreAdminNode[]>([]);
  const [selectedId, setSelectedId] = useState('');
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [newNodeDraft, setNewNodeDraft] = useState({ name: '', parentId: '' });
  const [contentDraft, setContentDraft] = useState({
    description: '',
    descriptionZh: '',
    descriptionEn: '',
    example: '',
    exampleZh: '',
    exampleEn: '',
    keyArtists: '',
  });

  const flatNodes = useMemo(() => flattenTree(tree), [tree]);
  const selectedNode = flatNodes.find((item) => item.id === selectedId) ?? null;

  const loadTree = async (preferredId?: string) => {
    setLoading(true);
    setError('');
    try {
      const payload = await genreAdminApi.fetchTree();
      setTree(payload.items);
      const nextFlat = flattenTree(payload.items);
      const nextId = preferredId ?? selectedId ?? nextFlat[0]?.id ?? '';
      setSelectedId(nextId);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '加载流派树失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadTree();
  }, []);

  useEffect(() => {
    if (!selectedNode) return;
    setContentDraft({
      description: selectedNode.description || '',
      descriptionZh: selectedNode.descriptionI18n?.zh || '',
      descriptionEn: selectedNode.descriptionI18n?.en || '',
      example: selectedNode.example || '',
      exampleZh: selectedNode.exampleI18n?.zh || '',
      exampleEn: selectedNode.exampleI18n?.en || '',
      keyArtists: selectedNode.keyArtists.join(', '),
    });
  }, [selectedNode]);

  const handleCreateNode = async () => {
    setSaving(true);
    setError('');
    setNotice('');
    try {
      const created = await genreAdminApi.createNode({
        name: newNodeDraft.name,
        parentId: newNodeDraft.parentId || null,
      });
      setNotice(`已创建流派节点：${created.name}`);
      setNewNodeDraft({ name: '', parentId: '' });
      await loadTree(created.id);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '创建流派节点失败');
    } finally {
      setSaving(false);
    }
  };

  const handleSaveContent = async () => {
    if (!selectedNode) return;
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await genreAdminApi.updateContent(selectedNode.id, {
        description: contentDraft.description,
        descriptionI18n: {
          zh: contentDraft.descriptionZh,
          en: contentDraft.descriptionEn,
          fallback: contentDraft.description,
        },
        example: contentDraft.example,
        exampleI18n: {
          zh: contentDraft.exampleZh,
          en: contentDraft.exampleEn,
          fallback: contentDraft.example,
        },
      });
      await genreAdminApi.updateKeyArtists(selectedNode.id, {
        keyArtists: contentDraft.keyArtists
          .split(',')
          .map((item) => item.trim())
          .filter(Boolean),
      });
      setNotice('流派内容已更新');
      await loadTree(selectedNode.id);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '更新流派内容失败');
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
      setNotice('流派节点已删除');
      await loadTree();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '删除流派节点失败');
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
      setNotice(`自动匹配完成：匹配 ${result.matched} / ${result.totalArtists}，更新 ${result.updatedGenres} 个流派`);
      await loadTree(selectedId);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '自动匹配失败');
    } finally {
      setSaving(false);
    }
  };

  return (
    <AdminContentLayout
      title="流派管理"
      description="以树状结构维护 Genre 层级、文案、多语言与代表艺人绑定，支持节点级创建、移动与删除。"
      actions={
        <Link href="/admin/content" className="rounded-full border border-[#ececec] bg-white px-5 py-3 text-sm text-[#18211f]">
          返回内容控制台
        </Link>
      }
    >
      <section className="space-y-5">
        {error ? <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)] p-4 text-sm text-[#6a3530]">{error}</div> : null}
        {notice ? <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] p-4 text-sm text-[#2f4027]">{notice}</div> : null}
        <div className="grid gap-5 xl:grid-cols-[420px_minmax(0,1fr)]">
          <section className="admin-reference-card p-5">
            <div className="flex items-center justify-between gap-3">
              <h2 className="text-[20px] font-semibold text-[#111827]">流派树</h2>
              <button type="button" className="rounded-full border border-[#d7ded9] px-4 py-2 text-sm" onClick={handleAutoMatch} disabled={saving}>
                Key Artists 自动匹配
              </button>
            </div>
            <div className="mt-4 admin-reference-soft-card p-4">
              <div className="text-sm font-semibold text-[#111827]">新增节点</div>
              <input className="mt-3 w-full rounded-[16px] border border-[#e8eceb] bg-white px-3 py-2 text-sm" placeholder="流派名称" value={newNodeDraft.name} onChange={(event) => setNewNodeDraft((prev) => ({ ...prev, name: event.target.value }))} />
              <select className="mt-3 w-full rounded-[16px] border border-[#e8eceb] bg-white px-3 py-2 text-sm" value={newNodeDraft.parentId} onChange={(event) => setNewNodeDraft((prev) => ({ ...prev, parentId: event.target.value }))}>
                <option value="">作为根节点</option>
                {flatNodes.map((item) => (
                  <option key={item.id} value={item.id}>
                    {item.path}
                  </option>
                ))}
              </select>
              <button type="button" className="mt-3 rounded-full bg-[#071110] px-4 py-2 text-sm font-semibold text-white" disabled={saving} onClick={handleCreateNode}>
                创建节点
              </button>
            </div>
            <div className="mt-4 max-h-[720px] overflow-auto">
              {tree.length ? <GenreTree items={tree} selectedId={selectedId} onSelect={setSelectedId} /> : <div className="admin-reference-soft-card p-4 text-sm text-black/48">{loading ? '加载中...' : '暂无流派数据。'}</div>}
            </div>
          </section>

          <section className="admin-reference-card p-5">
            <div className="flex items-center justify-between gap-3">
              <div>
                <h2 className="text-[20px] font-semibold text-[#111827]">节点编辑</h2>
                <div className="mt-1 text-sm text-black/48">{selectedNode ? selectedNode.path : '请选择左侧节点'}</div>
              </div>
              <button type="button" className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm" disabled={!selectedNode || saving} onClick={handleDeleteNode}>
                删除节点
              </button>
            </div>
            {selectedNode ? (
              <div className="mt-4 space-y-4">
                <div className="admin-reference-soft-card p-4 text-sm text-black/65">
                  <div>名称：{selectedNode.name}</div>
                  <div className="mt-1">路径：{selectedNode.path}</div>
                </div>
                <div className="grid gap-4 xl:grid-cols-2">
                  <textarea className="admin-reference-soft-card min-h-[150px] px-4 py-3 text-sm" placeholder="默认描述" value={contentDraft.description} onChange={(event) => setContentDraft((prev) => ({ ...prev, description: event.target.value }))} />
                  <textarea className="admin-reference-soft-card min-h-[150px] px-4 py-3 text-sm" placeholder="中文描述" value={contentDraft.descriptionZh} onChange={(event) => setContentDraft((prev) => ({ ...prev, descriptionZh: event.target.value }))} />
                  <textarea className="admin-reference-soft-card min-h-[120px] px-4 py-3 text-sm" placeholder="默认示例" value={contentDraft.example} onChange={(event) => setContentDraft((prev) => ({ ...prev, example: event.target.value }))} />
                  <textarea className="admin-reference-soft-card min-h-[120px] px-4 py-3 text-sm" placeholder="中文示例" value={contentDraft.exampleZh} onChange={(event) => setContentDraft((prev) => ({ ...prev, exampleZh: event.target.value }))} />
                </div>
                <textarea className="admin-reference-soft-card min-h-[90px] w-full px-4 py-3 text-sm" placeholder="英文描述" value={contentDraft.descriptionEn} onChange={(event) => setContentDraft((prev) => ({ ...prev, descriptionEn: event.target.value }))} />
                <textarea className="admin-reference-soft-card min-h-[90px] w-full px-4 py-3 text-sm" placeholder="英文示例" value={contentDraft.exampleEn} onChange={(event) => setContentDraft((prev) => ({ ...prev, exampleEn: event.target.value }))} />
                <textarea className="admin-reference-soft-card min-h-[90px] w-full px-4 py-3 text-sm" placeholder="Key Artists（逗号分隔）" value={contentDraft.keyArtists} onChange={(event) => setContentDraft((prev) => ({ ...prev, keyArtists: event.target.value }))} />
                <button type="button" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white" disabled={saving} onClick={handleSaveContent}>
                  {saving ? '保存中...' : '保存节点内容'}
                </button>
              </div>
            ) : (
              <div className="admin-reference-soft-card mt-4 p-4 text-sm text-black/48">{loading ? '加载中...' : '请选择一个流派节点。'}</div>
            )}
          </section>
        </div>
      </section>
    </AdminContentLayout>
  );
}
