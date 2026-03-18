# 评论系统快速测试指南

## 启动服务

### 1. 启动后端
```bash
cd server
npm run dev
```

### 2. 启动前端
```bash
cd web
npm run dev
```

## 测试流程

### 步骤 1：访问 DJ Set 页面
1. 打开浏览器访问 `http://localhost:3000`
2. 进入任意 DJ Set 播放页面
3. 滚动到视频下方，应该能看到评论区

### 步骤 2：测试未登录状态
- 应该看到"登录后可以发表评论"的提示
- 可以查看已有的评论
- 看不到"回复"、"编辑"、"删除"按钮

### 步骤 3：登录并发表评论
1. 点击"登录"链接
2. 登录你的账号
3. 返回 DJ Set 页面
4. 在评论框输入内容（例如："这个 set 太棒了！"）
5. 点击"发表评论"
6. 评论应该立即出现在列表顶部

### 步骤 4：测试回复功能
1. 点击任意评论下方的"回复"按钮
2. 输入回复内容（例如："同意！"）
3. 点击"发表回复"
4. 回复应该嵌套显示在父评论下方

### 步骤 5：测试编辑功能
1. 找到你刚发表的评论
2. 点击"编辑"按钮
3. 修改内容
4. 点击"保存"
5. 内容应该更新，并显示"(已编辑)"标记

### 步骤 6：测试删除功能
1. 点击你的评论下方的"删除"按钮
2. 确认删除
3. 评论应该从列表中消失

## 预期结果

### ✅ 应该看到的
- 评论总数显示正确
- 评论按时间倒序排列（最新的在上面）
- 回复嵌套显示，有缩进
- 用户头像和昵称正确显示
- 时间显示为相对时间（刚刚、5分钟前等）
- 只能看到自己评论的"编辑"和"删除"按钮
- 字符计数器实时更新

### ❌ 不应该看到的
- 未登录时不应该看到评论输入框
- 不应该看到他人评论的"编辑"和"删除"按钮
- 不应该能发表空评论
- 不应该能发表超过 1000 字符的评论

## 常见问题

### Q: 评论发表后没有出现？
A: 检查浏览器控制台是否有错误，确认后端服务正常运行

### Q: 点击"编辑"后提示超时？
A: 评论只能在发表后 5 分钟内编辑

### Q: 看不到评论输入框？
A: 确认你已经登录

### Q: 删除评论后还能看到？
A: 刷新页面，如果还能看到，检查后端日志

## 数据库验证

### 查看所有评论
```sql
SELECT c.*, u.username, u.display_name
FROM comments c
LEFT JOIN users u ON c.user_id = u.id
ORDER BY c.created_at DESC;
```

### 查看某个 DJ Set 的评论
```sql
SELECT c.*, u.username
FROM comments c
LEFT JOIN users u ON c.user_id = u.id
WHERE c.set_id = 'your-set-id'
ORDER BY c.created_at DESC;
```

### 查看嵌套回复
```sql
SELECT
  c1.id as parent_id,
  c1.content as parent_content,
  c2.id as reply_id,
  c2.content as reply_content
FROM comments c1
LEFT JOIN comments c2 ON c2.parent_id = c1.id
WHERE c1.set_id = 'your-set-id' AND c1.parent_id IS NULL;
```

## 成功标志

如果以上所有测试都通过，说明评论系统已经完全正常工作！🎉
