# Raver 数据库设计

## 数据库选择
- **主数据库**: PostgreSQL 15+
- **缓存**: Redis
- **搜索引擎**: Elasticsearch (可选，后期优化)

## 核心表结构

### 1. Users (用户表)
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username VARCHAR(50) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  display_name VARCHAR(100),
  avatar_url TEXT,
  bio TEXT,
  location VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login_at TIMESTAMP,
  is_verified BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  role VARCHAR(20) DEFAULT 'user' -- user, moderator, admin
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
```

### 2. Events (活动表)
```sql
CREATE TABLE events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(255) UNIQUE NOT NULL,
  description TEXT,
  cover_image_url TEXT,
  venue_name VARCHAR(255),
  venue_address TEXT,
  city VARCHAR(100),
  country VARCHAR(100),
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  start_date TIMESTAMP NOT NULL,
  end_date TIMESTAMP NOT NULL,
  ticket_url TEXT,
  official_website TEXT,
  status VARCHAR(20) DEFAULT 'upcoming', -- upcoming, ongoing, completed, cancelled
  is_verified BOOLEAN DEFAULT FALSE,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_events_start_date ON events(start_date);
CREATE INDEX idx_events_city ON events(city);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_slug ON events(slug);
```

### 3. DJs (DJ表)
```sql
CREATE TABLE djs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(255) UNIQUE NOT NULL,
  bio TEXT,
  avatar_url TEXT,
  banner_url TEXT,
  country VARCHAR(100),
  spotify_id VARCHAR(100),
  apple_music_id VARCHAR(100),
  soundcloud_url TEXT,
  instagram_url TEXT,
  twitter_url TEXT,
  is_verified BOOLEAN DEFAULT FALSE,
  follower_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_djs_name ON djs(name);
CREATE INDEX idx_djs_slug ON djs(slug);
```

### 4. Genres (风格表)
```sql
CREATE TABLE genres (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL UNIQUE,
  slug VARCHAR(100) UNIQUE NOT NULL,
  description TEXT,
  parent_id UUID REFERENCES genres(id), -- 用于树状结构
  color VARCHAR(7), -- HEX颜色代码
  icon_url TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_genres_parent_id ON genres(parent_id);
CREATE INDEX idx_genres_slug ON genres(slug);
```

### 5. Event_DJs (活动-DJ关联表)
```sql
CREATE TABLE event_djs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  dj_id UUID REFERENCES djs(id) ON DELETE CASCADE,
  performance_date TIMESTAMP,
  stage_name VARCHAR(100),
  set_duration INTEGER, -- 分钟
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(event_id, dj_id, performance_date)
);

CREATE INDEX idx_event_djs_event_id ON event_djs(event_id);
CREATE INDEX idx_event_djs_dj_id ON event_djs(dj_id);
```

### 6. Event_Genres (活动-风格关联表)
```sql
CREATE TABLE event_genres (
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  genre_id UUID REFERENCES genres(id) ON DELETE CASCADE,
  PRIMARY KEY (event_id, genre_id)
);
```

### 7. DJ_Genres (DJ-风格关联表)
```sql
CREATE TABLE dj_genres (
  dj_id UUID REFERENCES djs(id) ON DELETE CASCADE,
  genre_id UUID REFERENCES genres(id) ON DELETE CASCADE,
  is_primary BOOLEAN DEFAULT FALSE, -- 是否为主要风格
  PRIMARY KEY (dj_id, genre_id)
);
```

### 8. Check_Ins (打卡记录表)
```sql
CREATE TABLE check_ins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  check_in_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  notes TEXT,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  is_public BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, event_id)
);

CREATE INDEX idx_check_ins_user_id ON check_ins(user_id);
CREATE INDEX idx_check_ins_event_id ON check_ins(event_id);
```

### 9. Check_In_Photos (打卡照片表)
```sql
CREATE TABLE check_in_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  check_in_id UUID REFERENCES check_ins(id) ON DELETE CASCADE,
  photo_url TEXT NOT NULL,
  caption TEXT,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_check_in_photos_check_in_id ON check_in_photos(check_in_id);
```

### 10. DJ_Check_Ins (DJ打卡记录)
```sql
CREATE TABLE dj_check_ins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  dj_id UUID REFERENCES djs(id) ON DELETE CASCADE,
  event_id UUID REFERENCES events(id) ON DELETE SET NULL,
  check_in_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  set_type VARCHAR(100), -- Mainstage, B2B, Closing Set, etc.
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, dj_id, event_id)
);

CREATE INDEX idx_dj_check_ins_user_id ON dj_check_ins(user_id);
CREATE INDEX idx_dj_check_ins_dj_id ON dj_check_ins(dj_id);
```

### 11. Setlists (歌单表)
```sql
CREATE TABLE setlists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dj_id UUID REFERENCES djs(id) ON DELETE CASCADE,
  event_id UUID REFERENCES events(id) ON DELETE SET NULL,
  title VARCHAR(255) NOT NULL,
  performance_date TIMESTAMP,
  venue VARCHAR(255),
  duration INTEGER, -- 分钟
  video_url TEXT,
  is_verified BOOLEAN DEFAULT FALSE,
  view_count INTEGER DEFAULT 0,
  save_count INTEGER DEFAULT 0,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_setlists_dj_id ON setlists(dj_id);
CREATE INDEX idx_setlists_event_id ON setlists(event_id);
CREATE INDEX idx_setlists_created_by ON setlists(created_by);
```

### 12. Tracks (曲目表)
```sql
CREATE TABLE tracks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  artist VARCHAR(255),
  spotify_id VARCHAR(100),
  apple_music_id VARCHAR(100),
  release_date DATE,
  duration INTEGER, -- 秒
  is_unreleased BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_tracks_title ON tracks(title);
CREATE INDEX idx_tracks_artist ON tracks(artist);
```

### 13. Setlist_Tracks (歌单-曲目关联表)
```sql
CREATE TABLE setlist_tracks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  setlist_id UUID REFERENCES setlists(id) ON DELETE CASCADE,
  track_id UUID REFERENCES tracks(id) ON DELETE CASCADE,
  position INTEGER NOT NULL, -- 播放顺序
  timestamp_start INTEGER, -- 开始时间(秒)
  timestamp_end INTEGER, -- 结束时间(秒)
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_setlist_tracks_setlist_id ON setlist_tracks(setlist_id);
CREATE INDEX idx_setlist_tracks_position ON setlist_tracks(setlist_id, position);
```

### 14. Posts (帖子表 - 未发ID讨论区)
```sql
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  content TEXT,
  audio_url TEXT,
  video_url TEXT,
  is_solved BOOLEAN DEFAULT FALSE,
  view_count INTEGER DEFAULT 0,
  like_count INTEGER DEFAULT 0,
  comment_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX idx_posts_is_solved ON posts(is_solved);
```

### 15. Post_Tags (帖子标签表)
```sql
CREATE TABLE post_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(50) NOT NULL UNIQUE,
  usage_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE post_tag_relations (
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  tag_id UUID REFERENCES post_tags(id) ON DELETE CASCADE,
  PRIMARY KEY (post_id, tag_id)
);
```

### 16. Comments (评论表)
```sql
CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES comments(id) ON DELETE CASCADE, -- 用于回复
  content TEXT NOT NULL,
  like_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_comments_post_id ON comments(post_id);
CREATE INDEX idx_comments_user_id ON comments(user_id);
CREATE INDEX idx_comments_parent_id ON comments(parent_id);
```

### 17. Badges (徽章表)
```sql
CREATE TABLE badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  description TEXT,
  icon_url TEXT,
  badge_type VARCHAR(50), -- event_count, dj_count, genre_master, etc.
  requirement_value INTEGER, -- 达成条件的数值
  rarity VARCHAR(20), -- common, rare, epic, legendary
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 18. User_Badges (用户徽章关联表)
```sql
CREATE TABLE user_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  badge_id UUID REFERENCES badges(id) ON DELETE CASCADE,
  earned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, badge_id)
);

CREATE INDEX idx_user_badges_user_id ON user_badges(user_id);
```

### 19. Fan_Badges (粉丝牌表)
```sql
CREATE TABLE fan_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  dj_id UUID REFERENCES djs(id) ON DELETE CASCADE,
  genre_id UUID REFERENCES genres(id) ON DELETE CASCADE,
  badge_type VARCHAR(20) NOT NULL, -- dj, genre
  level INTEGER DEFAULT 1,
  experience_points INTEGER DEFAULT 0,
  is_displayed BOOLEAN DEFAULT TRUE, -- 是否在个人主页展示
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CHECK (
    (badge_type = 'dj' AND dj_id IS NOT NULL AND genre_id IS NULL) OR
    (badge_type = 'genre' AND genre_id IS NOT NULL AND dj_id IS NULL)
  )
);

CREATE INDEX idx_fan_badges_user_id ON fan_badges(user_id);
CREATE INDEX idx_fan_badges_dj_id ON fan_badges(dj_id);
CREATE INDEX idx_fan_badges_genre_id ON fan_badges(genre_id);
```

### 20. Follows (关注关系表)
```sql
CREATE TABLE follows (
  follower_id UUID REFERENCES users(id) ON DELETE CASCADE,
  following_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (follower_id, following_id),
  CHECK (follower_id != following_id)
);

CREATE INDEX idx_follows_follower_id ON follows(follower_id);
CREATE INDEX idx_follows_following_id ON follows(following_id);
```

### 21. DJ_Follows (DJ关注表)
```sql
CREATE TABLE dj_follows (
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  dj_id UUID REFERENCES djs(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, dj_id)
);

CREATE INDEX idx_dj_follows_user_id ON dj_follows(user_id);
CREATE INDEX idx_dj_follows_dj_id ON dj_follows(dj_id);
```

### 22. Likes (点赞表)
```sql
CREATE TABLE likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  target_type VARCHAR(20) NOT NULL, -- post, comment, setlist
  target_id UUID NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, target_type, target_id)
);

CREATE INDEX idx_likes_user_id ON likes(user_id);
CREATE INDEX idx_likes_target ON likes(target_type, target_id);
```

### 23. Saves (收藏表)
```sql
CREATE TABLE saves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  target_type VARCHAR(20) NOT NULL, -- event, dj, setlist, track
  target_id UUID NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, target_type, target_id)
);

CREATE INDEX idx_saves_user_id ON saves(user_id);
CREATE INDEX idx_saves_target ON saves(target_type, target_id);
```

### 24. New_Releases (新歌速递表)
```sql
CREATE TABLE new_releases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  track_id UUID REFERENCES tracks(id) ON DELETE CASCADE,
  release_date DATE NOT NULL,
  genre_id UUID REFERENCES genres(id),
  is_featured BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_new_releases_release_date ON new_releases(release_date DESC);
CREATE INDEX idx_new_releases_genre_id ON new_releases(genre_id);
```

### 25. Notifications (通知表)
```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL, -- follow, like, comment, event_reminder, etc.
  title VARCHAR(255),
  content TEXT,
  link_url TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(user_id, is_read);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);
```

## 视图 (Views)

### 用户统计视图
```sql
CREATE VIEW user_stats AS
SELECT
  u.id,
  u.username,
  COUNT(DISTINCT ci.id) as event_count,
  COUNT(DISTINCT dci.id) as dj_count,
  COUNT(DISTINCT f.following_id) as following_count,
  COUNT(DISTINCT f2.follower_id) as follower_count
FROM users u
LEFT JOIN check_ins ci ON u.id = ci.user_id
LEFT JOIN dj_check_ins dci ON u.id = dci.user_id
LEFT JOIN follows f ON u.id = f.follower_id
LEFT JOIN follows f2 ON u.id = f2.following_id
GROUP BY u.id, u.username;
```

### DJ统计视图
```sql
CREATE VIEW dj_stats AS
SELECT
  d.id,
  d.name,
  COUNT(DISTINCT df.user_id) as follower_count,
  COUNT(DISTINCT dci.id) as check_in_count,
  COUNT(DISTINCT s.id) as setlist_count,
  COUNT(DISTINCT ed.event_id) as event_count
FROM djs d
LEFT JOIN dj_follows df ON d.id = df.dj_id
LEFT JOIN dj_check_ins dci ON d.id = dci.dj_id
LEFT JOIN setlists s ON d.id = s.dj_id
LEFT JOIN event_djs ed ON d.id = ed.dj_id
GROUP BY d.id, d.name;
```

## 触发器 (Triggers)

### 更新updated_at时间戳
```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ language 'plpgsql';

-- 应用到需要的表
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON events
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ... 其他表类似
```

### 自动更新计数器
```sql
-- 更新DJ关注数
CREATE OR REPLACE FUNCTION update_dj_follower_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE djs SET follower_count = follower_count + 1 WHERE id = NEW.dj_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE djs SET follower_count = follower_count - 1 WHERE id = OLD.dj_id;
  END IF;
  RETURN NULL;
END;
$$ language 'plpgsql';

CREATE TRIGGER dj_follows_count_trigger
AFTER INSERT OR DELETE ON dj_follows
FOR EACH ROW EXECUTE FUNCTION update_dj_follower_count();
```

## 索引优化建议

1. **全文搜索索引**
```sql
-- 为活动名称和描述创建全文搜索索引
CREATE INDEX idx_events_fulltext ON events
USING gin(to_tsvector('english', name || ' ' || COALESCE(description, '')));

-- 为DJ名称创建全文搜索索引
CREATE INDEX idx_djs_fulltext ON djs
USING gin(to_tsvector('english', name || ' ' || COALESCE(bio, '')));
```

2. **复合索引**
```sql
-- 活动查询常用组合
CREATE INDEX idx_events_date_status ON events(start_date, status);
CREATE INDEX idx_events_city_date ON events(city, start_date);
```

## 数据迁移策略

1. 使用Prisma Migrate进行版本控制
2. 每次schema变更创建新的migration文件
3. 生产环境部署前在staging环境测试
4. 保留回滚脚本

## 备份策略

1. 每日全量备份
2. 每小时增量备份
3. 保留30天备份历史
4. 异地备份存储
