# OpenIM 压测方案与本地结果

> 目标：验证 Raver 接入 OpenIM 后，聊天发送链路在本地 Docker 环境下的稳定性，并给后续 1k 在线连接压测留下可重复执行入口。

## 1. 当前压测覆盖范围

当前脚本覆盖：

- Raver DB 创建/复用压测用户；
- OpenIM 用户镜像注册；
- 创建 OpenIM 群；
- OpenIM REST `send_msg` 单聊文本发送；
- OpenIM REST `send_msg` 群聊文本发送；
- 并发发送、延迟统计、错误样本记录；
- 自动生成 Markdown 报告。

当前脚本不覆盖：

- 1000 个 WebSocket 客户端同时在线；
- iOS SDK 真实收消息、拉历史、已读回执；
- APNs 离线推送；
- 图片/语音/视频消息的上传与审核；
- 长时间 soak test；
- 生产机器、生产网络、生产数据库配置下的容量。

因此，本地结果可以证明“OpenIM 服务端发消息链路在当前开发环境没有明显阻塞”，但不能直接等价于“生产 1000 在线用户保证”。

## 2. 运行前置条件

1. OpenIM Docker 服务已启动。
2. Raver Postgres / Redis 已启动。
3. `server/.env` 中 OpenIM 配置有效。
4. `OPENIM_ENABLED=true`。
5. 已安装 server 依赖。

快速确认：

```bash
cd /Users/blackie/Projects/raver
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
pnpm -C server build
```

## 3. 默认压测命令

```bash
cd /Users/blackie/Projects/raver
OPENIM_ENABLED=true pnpm -C server openim:load-test
```

默认参数：

```dotenv
OPENIM_LOAD_TEST_USERS=20
OPENIM_LOAD_TEST_DIRECT_MESSAGES=100
OPENIM_LOAD_TEST_GROUP_MESSAGES=100
OPENIM_LOAD_TEST_GROUP_SIZE=10
OPENIM_LOAD_TEST_CONCURRENCY=10
OPENIM_LOAD_TEST_RUN_ID=
OPENIM_LOAD_TEST_REPORT_PATH=
```

报告默认输出到：

```text
docs/reports/openim-load-test-*.md
```

## 4. 推荐压测梯度

### 4.1 小规模 smoke

用于确认链路是否正常：

```bash
OPENIM_ENABLED=true \
OPENIM_LOAD_TEST_USERS=20 \
OPENIM_LOAD_TEST_DIRECT_MESSAGES=100 \
OPENIM_LOAD_TEST_GROUP_MESSAGES=100 \
OPENIM_LOAD_TEST_GROUP_SIZE=10 \
OPENIM_LOAD_TEST_CONCURRENCY=10 \
pnpm -C server openim:load-test
```

### 4.2 本地开发 burst

用于验证当前每日 1000 消息量级的短时间并发：

```bash
OPENIM_ENABLED=true \
OPENIM_LOAD_TEST_USERS=50 \
OPENIM_LOAD_TEST_DIRECT_MESSAGES=500 \
OPENIM_LOAD_TEST_GROUP_MESSAGES=500 \
OPENIM_LOAD_TEST_GROUP_SIZE=30 \
OPENIM_LOAD_TEST_CONCURRENCY=25 \
pnpm -C server openim:load-test
```

### 4.3 较高本地 burst

用于验证更激进的本机短时压力：

```bash
OPENIM_ENABLED=true \
OPENIM_LOAD_TEST_USERS=100 \
OPENIM_LOAD_TEST_DIRECT_MESSAGES=1000 \
OPENIM_LOAD_TEST_GROUP_MESSAGES=1000 \
OPENIM_LOAD_TEST_GROUP_SIZE=100 \
OPENIM_LOAD_TEST_CONCURRENCY=50 \
pnpm -C server openim:load-test
```

## 5. 本地实测结果

测试日期：2026-04-22 MYT  
环境：本机 Docker OpenIM + Raver 本地服务依赖  
测试类型：OpenIM REST `send_msg` 单聊/群聊文本发送

| 轮次 | users | groupSize | direct | group | concurrency | attempted | succeeded | failed | p50 | p95 | p99 | max | report |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| smoke | 20 | 10 | 100 | 100 | 10 | 200 | 200 | 0 | 5.27ms | 17.32ms | 44.98ms | 45.52ms | [report](/Users/blackie/Projects/raver/docs/reports/openim-load-test-2026-04-22T01-34-30-128Z.md) |
| burst-1k | 50 | 30 | 500 | 500 | 25 | 1000 | 1000 | 0 | 8.79ms | 23.8ms | 33.93ms | 37.79ms | [report](/Users/blackie/Projects/raver/docs/reports/openim-load-test-2026-04-22T01-34-36-002Z.md) |
| burst-2k | 100 | 100 | 1000 | 1000 | 50 | 2000 | 2000 | 0 | 14.93ms | 33.78ms | 46.24ms | 77.18ms | [report](/Users/blackie/Projects/raver/docs/reports/openim-load-test-2026-04-22T01-35-36-577Z.md) |

第三轮压测后 Docker 资源快照：

```text
openim-chat   CPU 1.36%   MEM 300MiB
openim-server CPU 8.51%   MEM 1.466GiB
mongo         CPU 1.07%   MEM 364.2MiB
kafka         CPU 3.43%   MEM 1.209GiB
redis         CPU 0.36%   MEM 27.39MiB
etcd          CPU 0.68%   MEM 83.93MiB
```

## 6. 当前结论

- 当前本地 OpenIM REST 发消息链路在 2000 条消息、50 并发、100 人群的 burst 下 0 失败。
- 单聊发送延迟高于群聊发送，但仍处在本地可接受范围：第三轮单聊 p95 为 38.66ms，群聊 p95 为 21.68ms。
- 对你当前设定的“注册用户 1k、日活 1k、同时在线 1k、每日消息量 1000”来说，本地 REST 发送容量不是当前最明显风险点。
- 真正还需要验证的是“1000 个在线 WebSocket 客户端 + iOS SDK 实时收发 + 推送 + 长时间运行”。

## 7. 下一步压测

### 7.1 真实在线连接压测

目标：

- 1000 个 OpenIM user token；
- 1000 个 WebSocket 客户端同时登录；
- 保持在线 30-60 分钟；
- 每分钟按比例发送单聊/群聊消息；
- 统计连接掉线、消息送达延迟、OpenIM server CPU/Mem、Kafka/Mongo/Redis 压力。

建议新增独立脚本：

```text
server/src/scripts/openim-ws-soak-test.ts
```

如果 OpenIM 官方 Node/Web SDK 在当前项目可稳定运行，则优先用 SDK 模拟客户端；否则用 iOS 多模拟器和少量真实设备做端到端验收，再用服务端脚本做 WebSocket 连接层压测。

### 7.2 iOS 端到端验收

目标：

- 两个或多个模拟器登录不同账号；
- 单聊实时收发；
- 小队群聊实时收发；
- 离线后重新上线拉取历史；
- 未读数与会话列表一致；
- OpenIM 不可用时 fallback 行为可观测。

### 7.3 生产前压测

生产前至少跑：

- 1k WebSocket 在线 60 分钟；
- 100 人群连续发消息；
- 200 人群消息发送与拉历史；
- OpenIM 容器重启后的恢复；
- Redis/Kafka/Mongo 单点重启或故障恢复演练；
- APNs 离线推送验收。
