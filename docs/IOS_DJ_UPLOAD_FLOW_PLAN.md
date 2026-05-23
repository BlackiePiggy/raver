# iOS DJ Upload/Edit Flow Plan

## 目标

将 iOS 端 DJ 上传/编辑收口成一套独立的 `DJUploadFlow`，交互和数据生命周期对齐新的 `EventUploadFlow`：

- 只支持手动创建 DJ。
- 普通用户创建 DJ 一律提交审核，不直接入库。
- 创建/编辑流程完整替换旧 DJ import/edit sheet。
- 图片选择后立即上传 OSS，后续草稿、提交、展示都只使用 OSS URL。
- 草稿闭环完整：退出未提交保留草稿，下次进入询问继续或重新开始，重新开始时清理未提交 OSS 图片。
- 提交必填：`name`、`avatar`、以及至少一个平台链接；如果平台链接全空，则必须上传一张证明图片。
- `avatar` 不允许删空。
- 多语言字段第一版支持。

## 当前需求决策

- [x] 普通用户创建 DJ 一律提交审核。
- [x] 第一版只支持手动创建，不做 Spotify/Discogs 创建入口。
- [x] 创建 DJ 前选图也必须立即上传 OSS。
- [x] 不允许删除 avatar 到空状态。
- [x] 必填 `name`、`avatar`、平台链接或证明图。
- [x] 第一版支持多语言字段。
- [x] 旧 DJ 创建/编辑入口完整替换到新 flow。

## 已完成

### 后端

- [x] `POST /v1/djs/upload-image` 支持 `draftId` 上传。
- [x] DJ draft 图片支持 `avatar`、`banner`、`proof` 三种 usage。
- [x] DJ draft 图片直接上传 OSS，不依赖本地 uploads。
- [x] 新增 `POST /v1/djs/delete-images`，用于删除未提交草稿图片。
- [x] `manual/import` 增加提交前校验：必须有 `avatarUrl`。
- [x] `manual/import` 增加提交前校验：平台链接全空时必须有 `proofImageUrl`。
- [x] 普通用户 `manual/import` 继续进入 content submission 审核流。
- [x] 审核提交时，将 draft 图片 media asset 从 `dj-draft` 迁移到 `content-submission` 归属。
- [x] 审核通过创建 DJ 时写入 `avatarUrl`、`avatarSourceUrl`、`bannerUrl`。
- [x] 审核通过创建 DJ 时写入 `nameI18n`、`bioI18n`、`countryI18n`、`aliases`、`genres`、平台链接。
- [x] 审核通过创建 DJ 时写入 festival-viewer 平台数据字段：Spotify 粉丝、SoundCloud ID、曲目数、歌单数、SoundCloud 粉丝/收藏。
- [x] 审核通过创建 DJ 时自动创建 DJ contributor。
- [x] `PATCH /v1/djs/:id` 支持通过 OSS URL 更新 `avatarUrl` 和 `bannerUrl`。
- [x] 编辑 DJ 替换 avatar/banner 时，后端会标记旧图 replaced 并删除旧 OSS object。

### iOS Service/Repository

- [x] `WebFeatureService.uploadDJImage` 支持 `djID` 或 `draftID`。
- [x] `LiveWebFeatureService.uploadDJImage` 传递 `draftId` 到 BFF。
- [x] 新增 `deleteDJUploadedImages(draftID:urls:)`。
- [x] `DJMediaRepository` 暴露 DJ draft 图片删除能力。
- [x] `ImportManualDJInput` 增加多语言、图片、genres、平台链接、证明图字段。
- [x] `UpdateDJInput` 增加 `genres`、`avatarUrl`、`bannerUrl`、更多平台链接字段。
- [x] iOS 创建/编辑 DJ 对齐 festival-viewer 手动创建字段：`spotifyId`、`spotifyFollowers`、`soundcloudId`、`trackCount`、`playlistCount`、`soundCloudFollowers`、`soundCloudFavorites`。
- [x] Mock service 补齐 draft 上传/删除接口，保证本地 mock 编译通过。

### iOS UploadFlow

- [x] 新增 `DJUploadDraft`。
- [x] 新增 `DJUploadDraftStore`。
- [x] 新增 `DJUploadValidation`。
- [x] 新增 `DJUploadFlowViewModel`。
- [x] 新增 `DJUploadFlowView`。
- [x] Flow 步骤：身份、资料、链接、检查。
- [x] 链接页支持 festival-viewer 的外部 ID 和平台统计字段。
- [x] 每次点击下一步保存本地草稿。
- [x] 进入页面发现草稿时提示继续草稿或重新开始。
- [x] 重新开始时删除草稿里未提交的 OSS 图片。
- [x] 选 avatar/banner/proof 后立即上传 OSS。
- [x] 上传中显示图片区域 loading overlay。
- [x] avatar 必填且不允许删空。
- [x] banner/proof 可删除，删除时清理未提交 OSS 图片。
- [x] 提交创建 DJ 时走 `importManualDJ`，普通用户进入审核。
- [x] 编辑 DJ 时走 `updateDJ`，提交 OSS URL。

### 入口替换

- [x] DJ 列表浮动 `+` 入口打开新的 `DJUploadFlow(mode: .create)`。
- [x] 初始导入名称入口打开新的创建 flow。
- [x] DJ 详情里的编辑入口打开新的 `DJUploadFlow(mode: .edit)`。

### 验证

- [x] `server` TypeScript build 通过：`npm run build --if-present`。
- [x] iOS workspace build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -sdk iphonesimulator -configuration Debug build`。

## 待继续

### 旧代码清理

- [x] 删除或收敛 `DJsModuleView.swift` 中旧的 DJ import sheet UI。
- [x] 删除或收敛 `DJsModuleView.swift` 中旧的 DJ edit sheet UI。
- [x] 删除旧 sheet 使用的 state：`manualAvatarData`、`editAvatarData`、Spotify/Discogs import draft state 等不再需要的字段。
- [x] 删除旧的 `confirmManualImport` 图片后置上传逻辑。
- [x] 删除旧的 `saveDJProfileEdits` 图片后置上传逻辑。
- [x] 确认是否保留 Spotify/Discogs 搜索能力给其他入口使用；当前保留 DJ 详情页的 Spotify 补全当前 DJ 入口，列表页创建 DJ 只走新手动 flow。

### 产品体验补强

- [ ] 创建 flow 如果传入初始 DJ 名称，应自动填到 `draft.name` 当前语言。
- [ ] 草稿恢复弹窗文案可补充展示上次保存时间。
- [ ] 图片上传进度目前是 indeterminate loading，后续如 BFF/client 支持 upload progress，可改成真实百分比圆环。
- [ ] 提交成功后可以用统一 operation banner 展示“已提交审核/已更新”，而不是只 dismiss。
- [ ] 链接校验可以按平台做更精细规则，例如 Instagram/SoundCloud 域名提示。
- [ ] `otherPlatformUrl` 可以补一个平台名称输入，例如 `otherPlatformName`，方便审核台识别来源。

### 审核后台/数据闭环

- [ ] 审核台需要展示 `proofImageUrl`。
- [ ] 审核台需要展示 `otherPlatformUrl`。
- [ ] 审核通过后，`content-submission` 关联的 media asset 是否需要迁移到最终 DJ 归属，需要再做一次后台资产生命周期确认。
- [ ] 审核拒绝时，是否立即删除 `content-submission` 关联 OSS 图片，或进入定期清理队列，需要确定策略。

### OSS/媒体治理

- [ ] 对 DJ draft 图片增加定期清理策略，清理长期未提交且不再有本地草稿引用的 OSS 图片。
- [ ] 对 `content-submission` 图片增加审核拒绝/过期后的清理策略。
- [ ] 确认 DJ banner 删除范围：当前删除工具函数名叫 `isDjAvatarOssObjectKey`，实际判断 DJ 文件夹前缀，可删除 banner，但建议后续重命名成更准确的 `isDJOssObjectKey`。

### 测试建议

- [ ] 手动测试：创建 DJ，上传 avatar，填写一个平台链接，退出，重新进入继续草稿，提交审核。
- [ ] 手动测试：创建 DJ，上传 avatar，不填任何链接，上传 proof，提交审核。
- [ ] 手动测试：创建 DJ，上传 avatar/proof 后选择重新开始，确认 OSS draft 图片被删除。
- [ ] 手动测试：创建 DJ，不上传 avatar，确认无法进入/提交。
- [ ] 手动测试：创建 DJ，无链接且无 proof，确认无法提交。
- [ ] 手动测试：编辑 DJ，更换 avatar，确认后端旧 OSS avatar 被删除，新 URL 生效。
- [ ] 手动测试：编辑 DJ，尝试删除 avatar，确认不允许删空。
- [ ] 手动测试：审核通过 DJ submission，确认 DJ 入库字段完整。

## 文件索引

- iOS flow：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/UploadFlow/`
- iOS DJ 入口：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift`
- iOS service/model：`mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureService.swift`
- iOS live service：`mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift`
- iOS models：`mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureModels.swift`
- iOS repositories：`mobile/ios/RaverMVP/RaverMVP/Features/Discover/Shared/DiscoverRepositories.swift`
- BFF DJ routes：`server/src/routes/bff.web.routes.ts`
- 审核创建逻辑：`server/src/routes/content-submission.routes.ts`
