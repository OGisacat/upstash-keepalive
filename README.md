# upstash-keepalive

这是一个 **基础设施专用仓库**，用于通过 GitHub Actions 运行轻量级定时任务，
当前主要用途是对 **Upstash Redis** 进行定时访问，以避免实例因长期空闲而进入休眠状态。

本仓库不承载任何业务代码，仅作为稳定、低成本的 cron 承载点存在。

---

## 功能说明

- 使用 GitHub Actions 的 `schedule` 触发器
- 定期调用 Upstash Redis REST API（`PING`）
- 保持实例处于活跃状态，避免冷启动或休眠

---

## 工作方式

GitHub Actions 会按照设定的 cron 规则运行 workflow：

- 向 Upstash Redis REST 接口发送 `PING` 请求
- 只进行最轻量的访问，不写入业务数据
- 执行日志中返回 `PONG` 即表示成功

---

## 依赖的 Secrets

在仓库的 **Settings → Secrets and variables → Actions** 中配置以下 Repository Secrets：

- `UPSTASH_REDIS_REST_URL`  
  Upstash Redis 的 REST URL（不包含引号）

- `UPSTASH_REDIS_REST_TOKEN`  
  Upstash Redis 的 REST Token

---

## 运行与验证

- Workflow 支持 `workflow_dispatch`，可在 Actions 页面手动运行
- 日志中出现 `PONG` 表示配置正确
- 定时任务将按 cron 规则自动执行，无需人工干预

---

## 设计原则

- 单一职责：只做定时与保活
- 最低复杂度：不引入额外服务或运行时
- 生命周期清晰：与业务仓库解耦，独立存在

---

如需新增其他基础设施类定时任务（如数据库保活、健康检查等），
可在本仓库中新增独立 workflow。
