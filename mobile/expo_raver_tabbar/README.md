# Expo Raver Tab Bar

一个最小的 Expo 复现工程，只先做主页底部 Tab Bar。

当前包含 5 个入口：

- 发现
- 圈子
- 搜索
- 收件箱
- 我的

## 启动

```bash
cd /Users/blackie/Projects/raver/mobile/expo_raver_tabbar
npm install
npm run web
```

也可以直接运行：

```bash
npm run ios
npm run android
```

## 当前范围

这个目录现在只做两件事：

1. 先把底部 tab 的结构和交互壳子跑起来
2. 给后续真实页面留占位

下一步很适合继续做：

- 把 `发现` 换成真实首页布局
- 把中间 `搜索` 改成搜索浮层
- 把 `收件箱` 接通知/消息入口
- 把配色、图标和间距继续往你 iOS 版本靠
