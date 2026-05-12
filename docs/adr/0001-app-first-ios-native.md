# ADR-0001 App-first iOS Native

## Status

Accepted

## Context

Raver 当前的核心产品体验集中在 iOS App。仓库中仍存在历史 Web 入口、旧移动端口径和 Android parity 计划，但真实主线已经是 `mobile/ios/RaverMVP/` 下的原生 iOS App。

旧 README 中曾将移动端描述为 React Native，这已经不符合当前项目状态。

## Decision

Raver 当前采用 App-first 的产品口径，iOS Native 是主客户端。

核心客户端路径：

```text
mobile/ios/RaverMVP/
```

iOS 架构主线：

- SwiftUI + UIKit 混合
- Coordinator / MVVM 演进
- Feature-based modules
- Tencent IM SDK integration
- Widget 和 Notification Service Extension

## Consequences

- 新功能优先考虑 iOS App 的体验和接口需求。
- Web 不再被视为主产品客户端。
- `web/` 更适合定位为 Admin Console、CMS、预报名、公网页和 fallback 页面。
- 文档、README 和架构介绍需要修正旧的 React Native / Web-first 口径。

## Migration Notes

- 更新 README 中移动端技术栈。
- 在架构改造中将 iOS 目标结构整理为 `App/Core/DesignSystem/Modules/Infrastructure/Shared/Legacy`。
- Android parity 作为后续计划，不阻塞当前 iOS 主线。
