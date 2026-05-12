# Backend Infrastructure

This directory is for adapters around external systems and platform infrastructure.

Target subdomains:

```text
infrastructure/
  prisma/
  redis/
  oss/
  apns/
  tencent-im/
  sms/
  external-music/
```

Rules:

- Infrastructure code should not own business decisions.
- Domain modules call infrastructure through small adapters.
- Third-party SDK configuration belongs here or in shared config.
- Do not place HTTP route handlers here.

Current code will be moved gradually from existing service directories.
