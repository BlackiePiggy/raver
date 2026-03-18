'use client';

import { useMemo, useState } from 'react';
import Navigation from '@/components/Navigation';
import { GENRE_TREE, GenreNode } from '@/lib/genres';

interface GenreTreeItemProps {
  node: GenreNode;
  level: number;
  expanded: Set<string>;
  toggle: (id: string) => void;
}

function GenreTreeItem({ node, level, expanded, toggle }: GenreTreeItemProps) {
  const hasChildren = Boolean(node.children?.length);
  const isOpen = expanded.has(node.id);

  return (
    <div className="space-y-2">
      <div
        className="rounded-lg border border-bg-primary bg-bg-tertiary p-3 cursor-pointer hover:border-primary-blue/50 transition-colors"
        style={{ marginLeft: `${level * 16}px` }}
        onClick={() => hasChildren && toggle(node.id)}
      >
        <div className="flex items-center justify-between gap-2">
          <div>
            <p className="text-text-primary font-semibold">{node.name}</p>
            <p className="text-sm text-text-secondary">{node.description}</p>
          </div>
          {hasChildren && (
            <span className="text-text-tertiary text-sm">{isOpen ? '收起' : '展开'}</span>
          )}
        </div>
      </div>

      {hasChildren && isOpen && (
        <div className="space-y-2 animate-fade-in">
          {node.children!.map((child) => (
            <GenreTreeItem key={child.id} node={child} level={level + 1} expanded={expanded} toggle={toggle} />
          ))}
        </div>
      )}
    </div>
  );
}

export default function GenresPage() {
  const [expanded, setExpanded] = useState<Set<string>>(new Set(['house', 'techno']));

  const count = useMemo(() => {
    const walk = (list: GenreNode[]): number =>
      list.reduce((sum, item) => sum + 1 + (item.children ? walk(item.children) : 0), 0);
    return walk(GENRE_TREE);
  }, []);

  const toggle = (id: string) => {
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  const expandAll = () => {
    const ids = new Set<string>();
    const walk = (list: GenreNode[]) => {
      list.forEach((item) => {
        if (item.children?.length) {
          ids.add(item.id);
          walk(item.children);
        }
      });
    };
    walk(GENRE_TREE);
    setExpanded(ids);
  };

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px] max-w-6xl mx-auto p-6 space-y-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h1 className="text-4xl font-bold text-text-primary mb-2">音乐风格介绍</h1>
            <p className="text-text-secondary">用树状结构逐层展开电子音乐流派，共 {count} 个节点。</p>
          </div>
          <div className="flex gap-2">
            <button
              type="button"
              onClick={expandAll}
              className="px-3 py-2 rounded-lg bg-primary-blue text-white hover:bg-primary-purple"
            >
              全部展开
            </button>
            <button
              type="button"
              onClick={() => setExpanded(new Set())}
              className="px-3 py-2 rounded-lg border border-bg-primary text-text-secondary hover:text-text-primary"
            >
              全部收起
            </button>
          </div>
        </div>

        <div className="bg-bg-secondary rounded-xl border border-bg-tertiary p-4 space-y-3">
          {GENRE_TREE.map((node) => (
            <GenreTreeItem key={node.id} node={node} level={0} expanded={expanded} toggle={toggle} />
          ))}
        </div>
      </div>
    </div>
  );
}
