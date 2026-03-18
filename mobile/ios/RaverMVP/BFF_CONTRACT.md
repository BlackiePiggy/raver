# BFF Contract (MVP)

该契约用于把 iOS 客户端与 Mastodon/Matrix 解耦。App 仅调用 BFF。

## Auth

### POST /v1/auth/login

Request

```json
{
  "username": "blackie",
  "password": "123456"
}
```

### POST /v1/auth/register

Request

```json
{
  "username": "new_user",
  "email": "new_user@example.com",
  "password": "123456",
  "displayName": "New User"
}
```

Response: same as login

Response

```json
{
  "token": "jwt_or_session_token",
  "user": {
    "id": "u_me",
    "username": "blackie",
    "displayName": "Blackie",
    "avatarURL": null,
    "isFollowing": false
  }
}
```

## Feed

### GET /v1/feed

Response

```json
{
  "posts": [],
  "nextCursor": null
}
```

### GET /v1/feed/search?q=keyword

Response: same as `GET /v1/feed`

### POST /v1/feed/posts

Request

```json
{
  "content": "hello",
  "images": ["https://..."],
  "squadId": "optional_squad_id"
}
```

Response: `Post`

### POST /v1/feed/posts/:id/like

Response: `Post`

### DELETE /v1/feed/posts/:id/like

Response: `Post`

### GET /v1/feed/posts/:id/comments

Response: `Comment[]`

### POST /v1/feed/posts/:id/comments

Request

```json
{
  "content": "nice"
}
```

Response: `Comment`

## Chat

### GET /v1/chat/conversations?type=direct|group

Response: `Conversation[]`

### POST /v1/chat/direct/start

Request

```json
{
  "identifier": "alice"
}
```

Response: `Conversation`

## Search

### GET /v1/users/search?q=alice

Response: `UserSummary[]`

### GET /v1/users/:id/profile

Response: `UserProfile` (includes optional `isFollowing`)

### GET /v1/users/:id/posts

Response: same as `GET /v1/feed`

## Notifications

### GET /v1/notifications?limit=20

Response

```json
{
  "unreadCount": 12,
  "items": [
    {
      "id": "like_xxx",
      "type": "like",
      "createdAt": "2026-03-18T08:20:00.000Z",
      "isRead": false,
      "actor": {
        "id": "u_1",
        "username": "alice",
        "displayName": "Alice",
        "avatarURL": null,
        "isFollowing": false
      },
      "text": "Alice 赞了你的动态",
      "target": {
        "type": "post",
        "id": "p_1",
        "title": "post preview"
      }
    }
  ]
}
```

### GET /v1/notifications/unread-count

Response

```json
{
  "total": 12,
  "follows": 3,
  "likes": 5,
  "comments": 2,
  "squadInvites": 2
}
```

## Squads

### GET /v1/squads/recommended

Response: `SquadSummary[]`

### GET /v1/squads/:id/profile

Response: `SquadProfile`

### POST /v1/squads/:id/join

Response

```json
{
  "success": true,
  "isMember": true
}
```

### GET /v1/chat/conversations/:id/messages

Response: `ChatMessage[]`

### POST /v1/chat/conversations/:id/messages

Request

```json
{
  "content": "hello"
}
```

Response: `ChatMessage`

## Profile & Follow

### GET /v1/profile/me

Response: `UserProfile`

### POST /v1/social/users/:id/follow

Response: `UserSummary`

### DELETE /v1/social/users/:id/follow

Response: `UserSummary`
