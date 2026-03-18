'use client';

import Navigation from '@/components/Navigation';
import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';

export default function SquadsPage() {
  const { user } = useAuth();

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px]">
        <div className="max-w-7xl mx-auto px-6 py-8">
          <div className="mb-8 flex items-center justify-between">
            <div>
              <h1 className="text-4xl font-bold bg-gradient-to-r from-primary-purple to-primary-blue bg-clip-text text-transparent mb-4">
                小队
              </h1>
              <p className="text-text-secondary">
                创建或加入小队，与朋友一起参加电音节
              </p>
            </div>
            {user && (
              <Link
                href="/squads/new"
                className="px-6 py-3 bg-primary-purple hover:bg-primary-blue text-white rounded-lg transition-colors"
              >
                创建小队
              </Link>
            )}
          </div>

          <div className="bg-bg-secondary rounded-xl p-12 border border-bg-tertiary text-center">
            <div className="text-6xl mb-4">🎪</div>
            <h2 className="text-2xl font-bold text-text-primary mb-2">
              小队功能即将上线
            </h2>
            <p className="text-text-secondary mb-6">
              我们正在开发小队创建���聊天室、活动记录、相册等功能，敬请期待！
            </p>
            <div className="flex gap-4 justify-center">
              <Link
                href="/"
                className="px-6 py-3 bg-primary-purple hover:bg-primary-blue text-white rounded-lg transition-colors"
              >
                返回首页
              </Link>
              <Link
                href="/community"
                className="px-6 py-3 bg-bg-tertiary hover:bg-bg-primary border border-bg-primary text-text-primary rounded-lg transition-colors"
              >
                查看圈子
              </Link>
            </div>
          </div>

          <div className="mt-8 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <div className="bg-bg-secondary rounded-xl p-6 border border-bg-tertiary">
              <div className="text-3xl mb-3">👥</div>
              <h3 className="text-lg font-bold text-text-primary mb-2">创建小队</h3>
              <p className="text-sm text-text-secondary">
                邀请朋友加入，一起组队参加电音节
              </p>
            </div>

            <div className="bg-bg-secondary rounded-xl p-6 border border-bg-tertiary">
              <div className="text-3xl mb-3">💬</div>
              <h3 className="text-lg font-bold text-text-primary mb-2">小队聊天</h3>
              <p className="text-sm text-text-secondary">
                实时聊天，讨论活动安排和音乐话题
              </p>
            </div>

            <div className="bg-bg-secondary rounded-xl p-6 border border-bg-tertiary">
              <div className="text-3xl mb-3">🎪</div>
              <h3 className="text-lg font-bold text-text-primary mb-2">活动记录</h3>
              <p className="text-sm text-text-secondary">
                记录每次参加的电音节和参与成员
              </p>
            </div>

            <div className="bg-bg-secondary rounded-xl p-6 border border-bg-tertiary">
              <div className="text-3xl mb-3">📸</div>
              <h3 className="text-lg font-bold text-text-primary mb-2">小队相册</h3>
              <p className="text-sm text-text-secondary">
                按活动分类上传照片，记录美好回忆
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
