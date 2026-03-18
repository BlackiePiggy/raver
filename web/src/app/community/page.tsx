'use client';

import { useState } from 'react';
import Navigation from '@/components/Navigation';
import Link from 'next/link';

type Tab = 'feed' | 'squads';

export default function CommunityPage() {
  const [activeTab, setActiveTab] = useState<Tab>('feed');

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px]">
        <div className="max-w-7xl mx-auto px-6 py-8">
          <div className="mb-8">
            <h1 className="text-4xl font-bold bg-gradient-to-r from-primary-purple to-primary-blue bg-clip-text text-transparent mb-4">
              圈子
            </h1>
            <p className="text-text-secondary">
              分享你的电音生活，与志同道合的朋友互动
            </p>
          </div>

          {/* Tab Navigation */}
          <div className="flex gap-2 mb-6 border-b border-bg-tertiary">
            <button
              onClick={() => setActiveTab('feed')}
              className={`px-6 py-3 text-sm font-medium transition-colors relative ${
                activeTab === 'feed'
                  ? 'text-primary-purple'
                  : 'text-text-secondary hover:text-text-primary'
              }`}
            >
              动态
              {activeTab === 'feed' && (
                <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-primary-purple" />
              )}
            </button>
            <button
              onClick={() => setActiveTab('squads')}
              className={`px-6 py-3 text-sm font-medium transition-colors relative ${
                activeTab === 'squads'
                  ? 'text-primary-purple'
                  : 'text-text-secondary hover:text-text-primary'
              }`}
            >
              小队
              {activeTab === 'squads' && (
                <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-primary-purple" />
              )}
            </button>
          </div>

          {/* Feed Tab */}
          {activeTab === 'feed' && (
            <div>
              <div className="bg-bg-secondary rounded-xl p-12 border border-bg-tertiary text-center">
                <div className="text-6xl mb-4">🎵</div>
                <h2 className="text-2xl font-bold text-text-primary mb-2">
                  动态功能即将上线
                </h2>
                <p className="text-text-secondary mb-6">
                  我们正在开发动态发布、点赞评论等功能，敬请期待！
                </p>
              </div>

              <div className="mt-8 grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="bg-bg-secondary rounded-xl p-6 border border-bg-tertiary">
                  <div className="text-3xl mb-3">📝</div>
                  <h3 className="text-lg font-bold text-text-primary mb-2">发布动态</h3>
                  <p className="text-sm text-text-secondary">
                    分享你的电音节体验、DJ Set 推荐、音乐心得
                  </p>
                </div>

                <div className="bg-bg-secondary rounded-xl p-6 border border-bg-tertiary">
                  <div className="text-3xl mb-3">❤️</div>
                  <h3 className="text-lg font-bold text-text-primary mb-2">互动交流</h3>
                  <p className="text-sm text-text-secondary">
                    点赞、评论、分享，与其他电音爱好者互动
                  </p>
                </div>

                <div className="bg-bg-secondary rounded-xl p-6 border border-bg-tertiary">
                  <div className="text-3xl mb-3">👥</div>
                  <h3 className="text-lg font-bold text-text-primary mb-2">关注好友</h3>
                  <p className="text-sm text-text-secondary">
                    关注你喜欢的用户，第一时间看到他们的动态
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Squads Tab */}
          {activeTab === 'squads' && (
            <div>
              <div className="flex justify-end mb-6">
                <Link
                  href="/community/squads/new"
                  className="px-6 py-3 bg-primary-purple hover:bg-primary-blue text-white rounded-lg transition-colors text-sm"
                >
                  创建小队
                </Link>
              </div>
              <Link href="/community/squads">
                <div className="bg-bg-secondary rounded-xl p-12 border border-bg-tertiary text-center hover:border-primary-purple transition-colors cursor-pointer">
                  <div className="text-6xl mb-4">🎪</div>
                  <h2 className="text-2xl font-bold text-text-primary mb-2">
                    查看所有小队
                  </h2>
                  <p className="text-text-secondary">
                    创建或加入小队，与朋友一起参加电音节，私域聊天交流
                  </p>
                </div>
              </Link>

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
          )}
        </div>
      </div>
    </div>
  );
}

