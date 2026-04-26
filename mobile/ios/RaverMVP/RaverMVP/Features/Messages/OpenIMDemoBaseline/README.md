# OpenIMDemoBaseline

这个目录用于承载 `openim-ios-demo` 1:1 基线迁移版本。

目标：

- 优先直接迁入 demo 原文件
- 尽量保留 demo 原目录与原职责
- Raver 只在外层做 bridge / adapter

当前目录说明：

- `Vendor/OpenIMIOSDemo/`: 放 demo 原始源码快照
- `Chat/`: 聊天域页面与控制器
- `Conversation/`: 会话列表与会话相关页面
- `Contact/`: 联系人域
- `ChatSetting/`: 聊天设置 / 群设置
- `CommonWidgets/`: 迁入的通用组件
- `Adapters/`: 模型与接口桥接
- `ThemeBridge/`: 主题资源桥接
- `RoutingBridge/`: 页面跳转桥接
- `ServiceBridge/`: 服务层桥接

规则：

- 不把这里当“再造一套更像 demo 的实现”
- 这里的目标是“让 demo 基线在 Raver 工程里原生运行起来”

