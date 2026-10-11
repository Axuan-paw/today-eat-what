# 项目交接文档 · today-eat-what

> 给**新会话的 AI**：读完这份文档你就能直接接手开发，不需要人类重新解释背景。
> 人类是计算机本科生，想把这个项目从"随机抽菜"升级成"**基于 LLM 的个性化健康营养师助手**"。
> 生成时间：2026-10-04 · 上一会话负责网络/部署，本会话负责开发。

---

## 1. 项目现状（一句话）

一个**单文件网页**（`index.html`，约 300 行，11 KB），黑底卡片 UI，点击按钮从内置菜单里随机抽一道菜。数据存 localStorage，无后端、无构建、无依赖。

**技术栈：纯 HTML + CSS + 原生 JS。没有框架、没有 npm、没有打包。**

---

## 2. 目录与仓库状态

```
D:\projects\today-eat-what\
├── index.html      # 全部代码（HTML/CSS/JS 都在这一个文件里）
├── .gitignore
└── HANDOFF.md      # 本文件
```

### Git 双远程（同一个本地仓库推两个平台）

| 远程名 | 地址 | 状态 |
|---|---|---|
| `origin` | `git@github.com:Axuan-paw/today-eat-what.git` | ✅ 已推送 |
| `gitee` | `git@gitee.com:axuanpaw/today-eat-what.git` | ✅ 已推送 |

**提交历史：**
```
29887f1  feat: 今天吃什么 —— 随机抽菜小网页（含自定义菜单与历史）
```

**推送方式：SSH 密钥**（`~/.ssh/id_ed25519`，公钥已登记到 GitHub + Gitee 两个平台）。
**改完代码要推两次：**
```bash
git add . && git commit -m "说明"
git push          # GitHub
git push gitee    # Gitee
```

### 本地预览方式（重要）
**不要用 `file://` 直接打开**——localStorage 在 file 协议下行为不稳定。
用一个临时静态服务器：
```powershell
# 在项目目录下
npx serve .        # 或
python -m http.server 5173
```

---

## 3. 现有代码结构（改之前先看这段）

`index.html` 内部按这个顺序组织：

| 区块 | 内容 |
|---|---|
| `<style>` | 全部样式。CSS 变量在 `:root` 里（`--bg` `--card` `--accent` 等） |
| `<body>` | 三个区：**抽取区**（`.stage`）、**菜单管理区**（`.panel`）、**历史区**（`.panel`） |
| `<script>` | 见下表 |

### JS 关键函数（现在都在这一个 `<script>` 里）

| 函数 | 作用 | 改 LLM 版时的处理 |
|---|---|---|
| `STORAGE_KEY` | `"today-eat-what:v1"` | **升版到 v2**（数据结构要变） |
| `DEFAULT_DISHES` | 12 道默认菜，字段：`{name, tags[], price}` | ➕ 要扩展字段（见第 5 节） |
| `load()` / `save()` | localStorage 读写 | 需要**数据迁移**逻辑（v1 → v2） |
| `pick()` | **核心**：`setInterval` 每 60ms 换一个名字，14 次后停下 = 滚动动画 | 🔄 改造点：改成"先异步请求 LLM → 拿到结果再播放动画" |
| `addDish()` / `removeDish()` | 增删菜品 | 保留，字段要扩展 |
| `renderAll()` / `renderList()` / `renderHistory()` | 渲染三个区 | UI 要大改 |
| `esc()` | HTML 转义，防 XSS | **保留，LLM 返回的文本必须过它** |

### 当前交互流程
```
点「抽一个」→ 60ms 间隔滚动 14 次 → 随机停在一道菜 → 记入 history（保留 8 条）
```

---

## 4. ⚠️ 已知的坑（踩过了，别再踩）

| 坑 | 说明 | 规避方式 |
|---|---|---|
| **PowerShell 编码** | Windows PowerShell 5.1 里 `Get-Content` 默认按 GBK 读 UTF-8 文件，`Set-Content -Encoding utf8` 会写 BOM → **中文全变乱码**（曾把"原神，启动！"变成"鍘熺锛屽惎鍔紒"） | 处理中文文件用 **Node**（`fs.readFileSync(p,'utf8')`）或 VS Code，**避开 `Get-Content`/`Set-Content` 组合** |
| **Gitee Pages 已停服** | 2025 年起 Gitee 服务菜单里没有 Pages 了，别去找 | 静态托管用 GitHub Pages，或直接发 HTML 文件给朋友 |
| **GitHub Pages 未开** | `has_pages: false`。私有库开 Pages 需付费，已把仓库改公开 | 等人有空去 Settings → Pages 开启（3 分钟） |
| **国内访问 github.com 不稳定** | 频繁 TIMEOUT/ECONNRESET，`api.github.com` 反而常通 | 推送失败时重试；必要时等网络窗口期 |
| **Gitee 首次 SSH 连接** | 会问 `Are you sure you want to continue connecting?` | 输入完整的 `yes` |

---

## 5. 🎯 下一步目标：LLM 个性化营养师助手

### 人类原话
> "让 AI 根据用户的**地域、口味习惯、心情**等等去个性化推荐饮食"

### 现有数据结构 → 目标结构

**现在：**
```js
{ name: "麻辣烫", tags: ["川味","汤"], price: 18 }
```

**建议扩展为：**
```js
{
  name: "麻辣烫",
  tags: ["川味", "汤"],
  price: 18,
  calories: 550,        // 热量 kcal（营养师核心字段）
  spicy: 3,             // 辣度 0-5
  heaviness: "heavy",   // 清淡/适中/重口
  suitableMood: ["低落","想解压"]   // 适配心情（可选）
}
```

### 需要新增的用户画像（localStorage）
```js
profile = {
  region: "四川",          // 地域 → 影响口味倾向
  taste: ["辣","重口"],     // 口味习惯
  goals: ["减脂"],         // 健康目标（减脂/增肌/控糖/无）
  avoid: ["香菜","内脏"],   // 忌口
  budget: 25,              // 单餐预算
  mood: "疲惫"             // 当前心情（每次可改）
}
```

### LLM 集成方案（**推荐 A**）

**方案 A：纯前端 fetch 调 API**（小项目首选）
```js
const res = await fetch("https://api.deepseek.com/chat/completions", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "Authorization": "Bearer " + API_KEY
  },
  body: JSON.stringify({
    model: "deepseek-chat",
    messages: [
      { role: "system", content: "你是营养师，根据用户画像从候选菜单里选一道菜，只返回菜名。" },
      { role: "user", content: JSON.stringify({ profile, candidates }) }
    ]
  })
});
```

**⚠️ 方案 A 的致命问题**：API Key 写在前端 = **任何人打开网页都能看到你的 key**。
**所以必须二选一：**
- **仅本地玩**：key 不提交到 git（加进 `.gitignore`），或者每次运行手动输入
- **要公开部署**：必须加**后端代理**（一个极简 Node 服务转发请求，key 放服务端环境变量）

**方案 B：后端代理**（要公开就必须用这个）
```
前端 → 你的 Node 服务（持 key）→ DeepSeek API → 返回结果
```

### 实现步骤建议（给新会话的 AI）
1. **先确认 API Key 怎么来**（人类需要去 platform.deepseek.com 申请）
2. 写 `profile` 的数据结构 + 一个设置界面（让人类填地域/口味/心情）
3. 写 `localStorage` **数据迁移**（v1 的 12 道菜要能升到 v2，别丢用户数据）
4. 加**降级逻辑**：LLM 调用失败/超时 → 回退到现在的纯随机 `pick()`（**保证网页永远能用**）
5. LLM 返回结果要 **`esc()` 转义**后再插 DOM
6. 用 `try/catch` 包住网络请求，失败时给用户友好提示

### 测试要点
- 断网时网页是否仍能随机抽菜（降级是否生效）
- localStorage 里已有 v1 数据时，升级后是否正常
- LLM 返回了菜单里没有的菜名时怎么处理（建议：拒绝并回退）

---

## 6. 可用的工具（人类已给 DSH 装好）

| 工具 | 用途 |
|---|---|
| `archify` skill | 画架构图/时序图/数据流图（写文档、答辩用） |
| `genui` | 回复里直接渲染图表/表格（对话中可视化） |
| `find-plugins` skill | 找 DSH 插件 |
| `planning-with-files` skill | 长任务落盘计划（多文件重构时有用） |
| `agent-teams` | 多智能体协作（大改造时可拆任务并行） |

---

## 7. 需要向人类确认的问题（新会话开场就问）

1. **DeepSeek API Key 有了吗？** 没有的话，是否愿意去申请（有免费额度）
2. **这个助手是"只自己用"还是"要公开给别人用"？**
   - 自己用 → 方案 A 够，key 别提交 git
   - 给别人用 → 必须做后端代理（方案 B）
3. **要不要保留"纯随机"作为默认行为？**（LLM 推荐 vs 随机抽，建议做成可切换）
4. **UI 想保留现在的黑底卡片风，还是重做？**

---

## 8. 一句话总结给新会话

> 这是一个**单文件、无构建**的个人网页项目，已有可用的 v1（随机抽菜）和双远程 git。
> 要做的是**在不破坏现有可用性的前提下**，加入 LLM 个性化推荐。
> **最大的风险是 API Key 泄露**，**最重要的设计是"LLM 失败要能降级到随机"**。
