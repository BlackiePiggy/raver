'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import DJSetPlayer from '@/components/DJSetPlayer';
import { DJSetAPI } from '@/lib/api';
import { Button } from '@/components/ui/Button';
import Navigation from '@/components/Navigation';

export default function DJSetPage() {
  const params = useParams();
  const router = useRouter();
  const [djSet, setDjSet] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchDJSet = async () => {
      try {
        const data = await DJSetAPI.getDJSet(params.id as string);
        setDjSet(data);
      } catch (err) {
        setError((err as Error).message);
      } finally {
        setLoading(false);
      }
    };

    if (params.id) {
      fetchDJSet();
    }
  }, [params.id]);

  if (loading) {
    return (
      <div className="min-h-screen bg-bg-primary flex items-center justify-center">
        <div className="text-text-secondary text-xl">加载中...</div>
      </div>
    );
  }

  if (error || !djSet) {
    return (
      <div className="min-h-screen bg-bg-primary flex items-center justify-center">
        <div className="text-center">
          <div className="text-6xl mb-4">😕</div>
          <div className="text-accent-red text-xl mb-4">
            {error || 'DJ Set 不存在'}
          </div>
          <Button onClick={() => router.push('/djs')}>
            返回DJ列表
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px]">
        <DJSetPlayer djSet={djSet} />
      </div>
    </div>
  );
}