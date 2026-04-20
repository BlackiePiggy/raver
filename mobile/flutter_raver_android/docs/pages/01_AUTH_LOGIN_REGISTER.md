# 01. 登录与注册

## iOS 来源

- `Features/Auth/LoginView.swift`
- `Core/AppState.swift`
- `Core/LiveSocialService.swift`
- `Core/SessionTokenStore.swift`

## Flutter 目标路径

```text
lib/features/auth/data/
lib/features/auth/domain/
lib/features/auth/presentation/screens/login_screen.dart
lib/features/auth/presentation/view_models/login_view_model.dart
```

## 页面职责

- 登录。
- 注册。
- 同意协议状态。
- 第三方登录图标预留。
- 成功后写 token 并进入 shell。

## 路由

```text
/login
/register
```

## API

- `POST /v1/auth/login`
- `POST /v1/auth/register`
- `GET /v1/profile/me`

## UI 复刻

- 复用 iOS 登录背景和品牌图。
- 输入框保持深色/浅色主题适配。
- 主按钮使用 `RaverActionButton.primary`。
- 协议勾选状态在提交前校验。
- 错误显示为 snackbar 或 inline error，不清空密码输入。

## 状态模型

```text
AuthFormState
  username
  email
  password
  displayName
  acceptedTerms
  isSubmitting
  error
```

## 实现步骤

1. 建 `AuthApiClient`。
2. 建 `TokenStore`。
3. 建 `AuthRepository`。
4. 建 `LoginUseCase` 和 `RegisterUseCase`。
5. 建 `LoginViewModel`。
6. UI 接入表单校验。
7. 成功后更新 `AppState`。
8. 如果有 pending deep link，登录后恢复。

## 测试

- 空字段校验。
- 未勾选协议不能提交。
- 登录成功写 token。
- 401/400 显示错误。
- App 重启后 token 验证成功进入 shell。

