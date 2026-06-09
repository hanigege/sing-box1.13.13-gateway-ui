# Agent Coding Standards

This repository is a production-oriented sing-box gateway UI and installer. Treat every change as network-critical: a small mistake can break DNS, routing, proxy startup, or a user's LAN.

## Core Principles

- Prefer stable, tested behavior over clever changes.
- Keep changes scoped to the requested feature or bug.
- Read the existing code path before editing it.
- Do not add hidden side effects. If a script changes host networking, services, DNS, routing, or firewall state, the behavior must be explicit in code and documented in `README.md`.
- Do not silently fall back from invalid user input to an old/default value. Reject invalid input with a clear error.
- Do not make UI controls look saved when the backend rejected or normalized the value.

## 程序员写代码统一标准

本仓库的每一次代码修改，都必须像一个合格的维护者接手生产系统一样处理：先理解，再修改；先收敛，再验证；最后留下干净、可读、可追踪的结果。

### 修改前

- 先阅读相关调用链、配置来源、保存路径和启动路径，不允许只看报错位置就局部补丁式修改。
- 生产机已经暴露出来的故障，必须优先在生产边界定位、修复并验证；确认生产恢复后，再把同一逻辑干净回写到仓库，避免仓库修了但现场仍然坏。
- 先确认现有行为是否被 `README.md`、脚本输出、模板配置或前端交互依赖。
- 先检查 `git status --short`，区分用户已有改动和本次需要改动的文件。
- 不确定生产影响时，优先扩大阅读范围，而不是扩大修改范围。

### 修改中

- 每次改动必须围绕一个明确目标，避免顺手重构、顺手改样式、顺手整理无关文件。
- 保持代码结构干净：删除废弃分支、临时变量、调试输出和试验性代码。
- 不留下测试垃圾文件、临时备份、下载残留、生成产物或本地环境文件。
- 不用魔法常量和隐式行为。新增默认值、路径、端口、CIDR、服务名、环境变量时，必须在靠近使用处写清含义。
- 不重复造小工具函数。已有解析、校验、保存、渲染、脏状态、错误提示逻辑时，优先复用。
- 不为了“看起来能跑”吞掉异常。错误必须暴露给调用方或用户界面，并保留足够上下文。
- 不把后端拒绝、修正或回滚后的值伪装成保存成功。

### 中文标注要求

- 凡是改变 DNS、路由、TProxy、FakeIP、IPv6、端口监听、服务启停、防火墙、备份恢复、安装流程的代码，必须在关键位置加简短中文注释，说明“为什么这样做”和“不能随便改什么”。
- 凡是新增兼容逻辑、回滚逻辑、迁移逻辑或危险边界判断，必须有中文注释标明触发条件和保护目的。
- 中文注释要解释业务意图，不要翻译代码。例如写“避免把节点服务器 IP 再次送入 TProxy 形成回环”，不要写“遍历列表并追加规则”。
- 普通变量赋值、简单条件判断、显而易见的 UI 绑定不需要注释，避免把代码注释成噪音。
- 修改用户可见行为时，相关提示文案应清楚、克制、中文可读，不输出内部实现细节。

### 可读性和结构

- 函数应保持单一职责。过长函数要优先抽出已有风格的小函数，但不要为了形式化而制造碎片。
- 命名必须表达业务含义，避免 `tmp`、`data2`、`newConfig2` 这类只能靠猜的名字。
- 前端状态、后端配置、模板字段的命名要尽量一致，减少跨层翻译成本。
- 配置写入路径必须清晰：输入校验、规范化、预检查、写入、服务重载、失败回滚，每一步不要混在一起。
- UI 修改要保证状态来源明确：用户当前输入、内存状态、后端返回值不能互相混淆。

### 测试和临时产物

- 可以创建临时文件验证问题，但必须放在系统临时目录或明确的临时路径，结束前删除或说明。
- 不允许把本地测试产物、日志、缓存、下载包、备份文件、截图等提交进仓库。
- 如果测试需要生成文件，优先使用已有测试目录或 `/tmp`，不要散落在项目根目录。
- 运行检查后要根据结果修复问题；如果因为环境限制无法运行，必须在最终说明中写清楚未运行原因。

### 完成标准

- 代码通过相关静态检查或语法检查。
- 用户可见行为和后端真实保存结果一致。
- 文档已随行为变化同步更新。
- `git status --short` 中只留下本次任务相关改动。
- 最终说明要写清改了什么、验证了什么、还有什么未验证，不能只说“已完成”。

## Project-Specific Boundaries

- The installer must use the bundled repository-tested sing-box binary only.
- Do not add `latest`, `custom`, or upstream sing-box auto-download behavior unless the config compatibility strategy is redesigned first.
- The installer must not point host DNS to sing-box.
- The installer must not write public DNS servers to `/etc/resolv.conf`.
- The installer must not rewrite `/etc/resolv.conf` contents or symlink targets.
- If `systemd-resolved` occupies port 53, the installer may only set `DNSStubListener=no`, restart `systemd-resolved`, and wait for port 53 to be released.
- Do not enable `radvd` or advertise this host as an IPv6 gateway by default.
- `radvd` behavior must remain opt-in through an explicit environment variable.
- TProxy should capture FakeIP ranges and avoid proxying node server IPs back through itself.
- IPv4 and IPv6 FakeIP ranges must stay synchronized across DNS fakeip server settings, route rules, and TProxy rules.
- Auto must be an unattended safety path, not a manual UI action. The default urltest interval should stay short enough for gateway failover, and Auto must interrupt existing connections when its selected node changes.

## UI Rules

- All editable controls must update in-memory state consistently.
- For text inputs that affect saved config, listen to both `input` and `change` unless there is a specific reason not to.
- Before saving, collect current form values into state again. Do not rely only on prior event handlers.
- Disable save only when there are truly no unsaved changes or an operation is busy.
- After a successful save, reload/render from the backend response so the UI reflects actual persisted state.
- If validation fails, show the backend error and keep the user's current edit visible when possible.
- Avoid one-off dirty-state handling. Use shared helpers such as `markChanged()` or a clearly named equivalent.

## Backend Validation

- Validate all user-controlled config before writing files.
- CIDR values must be real network addresses when used as ranges. For example, accept `29.0.0.0/8`; reject `29.1.2.3/8`.
- Ports must be integers from 1 to 65535.
- Speeds, intervals, and numeric limits must reject invalid, negative, or nonsensical values.
- Node tags must remain unique and must not collide with reserved outbounds such as `Proxy`, `Auto`, `direct`, or `block`.
- Keep staged `sing-box check` before applying saved config.
- On restart failure, roll back to the previous working config.

## Installer Rules

- Keep installer output calm and meaningful.
- Intermediate mirror failures should not look like fatal errors if the installer can safely continue.
- Only print warnings when user action may be needed.
- Always print final access information after successful install:
  - Rule UI URL
  - Rule UI token
  - Clash UI URL
  - Clash API URL
  - Clash secret
- Do not expose internal implementation details such as template node bypass IPs in normal install output.

## Documentation

- Update `README.md` when behavior changes in any of these areas:
  - DNS
  - port 53 handling
  - TProxy
  - FakeIP
  - IPv6 routing
  - installer prompts
  - backup/import/export
  - bundled sing-box version
- Documentation must tell users what the installer does and what it deliberately does not do.
- For small users, be explicit about file paths and when manual router/client DNS configuration is required.

## Required Checks

Run the relevant checks before committing:

```bash
bash -n scripts/install.sh scripts/update-sing-box-rules-jsdelivr
python3 -m py_compile singbox-rule-ui/app.py scripts/bootstrap_config.py scripts/sync_tproxy_setup.py scripts/refresh_runtime_config.py
node --check singbox-rule-ui/static/app.js
```

When touching UI save behavior, also test:

- Editing Auto settings marks the page dirty and persists.
- Editing FakeIP settings marks the page dirty and persists.
- Invalid CIDR shows an error and does not fake a successful save.
- Adding/updating/deleting/enabling/disabling nodes persists correctly.
- Backup export/import still works.

When touching installer behavior, test or reason through:

- Fresh install with `systemd-resolved` occupying port 53.
- Fresh install without `systemd-resolved`.
- Fresh install where zashboard mirror probing fails but fallback succeeds.
- Reinstall on a host that already has sing-box installed.

## Git Hygiene

- Keep commits focused and named after the behavior changed.
- Do not commit unrelated generated files or local test artifacts.
- Do not revert user changes unless explicitly requested.
- Check `git status --short` before and after edits.
