# `openim-ios-demo` Baseline Freeze

> 用途：给后续 1:1 迁移提供唯一参照物，避免“参考目标漂移”。

## Baseline

- Source repository: [openimsdk/openim-ios-demo](https://github.com/openimsdk/openim-ios-demo)
- Baseline branch: `main`
- Freeze date: `2026-04-25`
- Freeze policy:
  - 本项目后续所有“是否一致”的判断，都以 `2026-04-25` 当天看到的 `main` 分支公开仓库状态为准
  - 后续即使 demo 仓库继续演进，当前迁移计划也不自动追新
  - 如果未来要切到新的 demo 版本，必须重新开一轮 baseline freeze

## Baseline Scope

当前冻结范围优先覆盖聊天域相关目录与页面：

- `OUIIM/Classes`
- `OUIIM/Classes/OIMUIChat`
- `OUICore/Classes`

## First-Pass Import Targets

根据当前公开仓库结构，首轮重点关注这些能力面：

- Conversation
- Chat
- Contact
- ChatSetting
- Core controller / event / model / widget support

## Current Migration Rule

- 优先迁入 demo 原始文件，而不是按 demo 逻辑重写
- 优先保留 demo 原目录、原页面组织、原控制器职责
- Raver 只在以下边界做桥接：
  - routing
  - theme
  - service facade
  - current user / profile mapping
  - app-specific business entry

## Local Target Skeleton

已在本工程内创建目标迁入目录：

```text
mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/
```

当前骨架：

- `Chat/`
- `Conversation/`
- `Contact/`
- `ChatSetting/`
- `CommonWidgets/`
- `Adapters/`
- `ThemeBridge/`
- `RoutingBridge/`
- `ServiceBridge/`
- `Vendor/OpenIMIOSDemo/`

## Notes

- 当前这份 freeze 文档不是在锁定“功能想法”，而是在锁定“对照答案”
- 如果后面出现“看起来和 demo 不一样”的讨论，默认先回到这份 baseline
- 后续每一轮源码迁入都应该引用本文件

