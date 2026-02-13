# upstash-keepalive

这是一个 **基础设施专用仓库**，用于通过 GitHub Actions 运行轻量级定时任务，
当前主要用途是对 **Upstash Redis** 进行定时访问，以降低实例因长期空闲而被归档的风险。

本仓库不承载任何业务代码，仅作为稳定、低成本的 cron 承载点存在。

---

## 功能说明

- 使用 GitHub Actions 的 `schedule` 触发器
- 定期调用 Upstash Redis REST API（均为只读）：
  - `PING`（连通性探测）
  - `DBSIZE`（读取当前 key 数量）
  - `TIME`（读取服务器时间）
- `PING` 每次都会执行；`DBSIZE` / `TIME` 每次随机执行一个
- 纯只读保活：不写入业务数据，不新增 key

---

## 工作方式

GitHub Actions 会按 cron 规则每天执行 workflow：

- 向 Upstash Redis REST 接口发送 `PING`
- 在 `DBSIZE` 和 `TIME` 中随机执行一个只读请求
- 日志中出现 `PONG` 且随机读操作返回合法结果即表示成功

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
- 日志中出现 `PONG`，并且出现 `Selected read op: DBSIZE` 或 `Selected read op: TIME`，表示配置正确
- 定时任务会每天自动执行，无需人工干预

---

## 设计原则

- 单一职责：只做定时与保活
- 最低复杂度：不引入额外服务或运行时
- 生命周期清晰：与业务仓库解耦，独立存在

---

如需新增其他基础设施类定时任务（如健康检查等），
可在本仓库中新增独立 workflow。
