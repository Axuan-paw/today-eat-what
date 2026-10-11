# Git 操作手册 · today-eat-what

> 用途：记录本项目的仓库地址、完整上传流程、推送方法、常见问题。
> 生成：2026-10-12 · 维护：每次流程有变化时更新。

---

## 一、仓库地址（双远程）

| 远程名 | 平台 | 地址 | 可见性 |
|---|---|---|---|
| `origin` | GitHub | `git@github.com:Axuan-paw/today-eat-what.git` | 🌐 公开 |
| `gitee` | Gitee | `git@gitee.com:axuanpaw/today-eat-what.git` | 🌐 公开 |

**网页地址：**
- GitHub：https://github.com/Axuan-paw/today-eat-what
- Gitee：https://gitee.com/axuanpaw/today-eat-what

**注意**：地址用的是 **SSH 格式**（`git@` 开头），不是 `https://` 开头。
SSH 用密钥认证，配好后**永久免密**；HTTPS 每次要输 token。

---

## 二、从零搭建的完整流程（已做过，留档参考）

### 阶段 1：SSH 密钥（一辈子一次）

```bash
# 生成密钥对（-C 后面是备注，随便写）
ssh-keygen -t ed25519 -C "Axuan-paw@github" -f ~/.ssh/id_ed25519 -N ""

# 查看公钥（复制这一整串，包括开头的 ssh-ed25519）
cat ~/.ssh/id_ed25519.pub
```

然后把公钥分别粘贴到两个平台：
- GitHub：`Settings → SSH and GPG keys → New SSH key`
- Gitee：`设置 → 安全设置 → SSH 公钥 → 添加公钥`

**验证连接：**
```bash
ssh -T git@github.com     # 期望：Hi Axuan-paw! You've successfully authenticated...
ssh -T git@gitee.com      # 期望：Hi Axuan-paw(@axuanpaw)! You've successfully authenticated...
```

> ⚠️ 首次连接会问 `Are you sure you want to continue connecting (yes/no/[fingerprint])?`
> **必须输入完整的 `yes`**（三个字母），不能只按 y。

### 阶段 2：本地仓库初始化（每个项目一次）

```bash
cd /d/projects/today-eat-what      # 进项目目录
git init -b main                   # 初始化，主分支叫 main
git config --global user.name "Axuan-paw"
# 用 GitHub 专属的 noreply 邮箱，永远不要把真实邮箱（尤其带手机号的）写进公开提交
git config --global user.email "Axuan-paw@users.noreply.github.com"
```

### 阶段 3：连接远程（每个项目一次）

```bash
git remote add origin git@github.com:Axuan-paw/today-eat-what.git
git remote add gitee  git@gitee.com:axuanpaw/today-eat-what.git

git remote -v      # 确认：应该看到 4 行
```

### 阶段 4：首次推送（每个分支一次）

```bash
git add -A
git commit -m "feat: 初次提交"
git push -u origin main     # -u 建立追踪关系，之后只敲 git push
git push -u gitee main
```

---

## 三、日常推送流程（99% 的情况用这个）

```bash
# 1. 看看改了什么
git status
git diff                    # 提交前必看，能发现误改和编码问题

# 2. 暂存
git add -A                  # 或 git add <具体文件>

# 3. 提交
git commit -m "feat: 说明改了什么"

# 4. 推送到两个平台
git push                    # GitHub
git push gitee              # Gitee
```

> **`-u` 只在第一次推送时需要**，配好之后 `git push` 就够了。
> 但推 Gitee 要显式写 `git push gitee`（因为默认追踪的是 origin）。

---

## 四、⚠️ 本项目的三大坑（踩过，务必避开）

### 坑 1：API Key 绝对不能进 git

**已在 `.gitignore` 里挡住了：**
```
config.local.js
.env
.env.local
*.key
*.pem
```

**每次推送前自检：**
```bash
git status                              # 列表里不该出现 config.local.js
git check-ignore -v config.local.js     # 有输出 = 被忽略，安全
```

**三条铁律（`config.example.js` 里也写了）：**
1. 绝不把真实 key 写进 `index.html`
2. 绝不把 `config.local.js` 提交到 git
3. 绝不把 key 粘贴到任何聊天窗口（包括 AI 对话）

### 坑 2：PowerShell 会毁掉 UTF-8 中文

```powershell
# ❌ 千万别这样改含中文的文件
(Get-Content index.html) -replace 'a','b' | Set-Content index.html -Encoding utf8
```

**原因**：Windows PowerShell 5.1 的 `Get-Content` 默认按 GBK 读，`Set-Content -Encoding utf8` 会写 BOM。
**后果**：文件里的中文全变乱码（曾把「原神，启动！」变成「鍘熺锛屽惎鍔紒」）。

**正确做法**：用 Node 或 VS Code 编辑。
```powershell
# ✅ 用 Node 替换（UTF-8 安全）
node -e "const fs=require('fs');const p='index.html';let s=fs.readFileSync(p,'utf8');s=s.replace('旧','新');fs.writeFileSync(p,s,'utf8');"
```

**如果不小心弄坏了**：`git diff` 会立刻显示乱码 → `git checkout HEAD -- 文件名` 回滚。

### 坑 3：国内访问 GitHub 不稳定

| 通道 | 稳定性 |
|---|---|
| `git push`（SSH） | 较稳，偶尔失败重试即可 |
| 浏览器开 github.com | **时好时坏**（TIMEOUT / ECONNRESET） |
| `api.github.com` | 往往比网页版更通 |

**推送失败时**：不要慌，隔几分钟重试。或先推 Gitee（通常更快）。

---

## 五、发布/部署方式

### GitHub Pages（静态托管，免费）

```
仓库 → Settings → Pages
→ Source: Deploy from a branch
→ Branch: main，目录 /（root）
→ Save → 等 1-2 分钟
→ 网址：https://axuan-paw.github.io/today-eat-what/
```

> **限制**：私有库开 Pages 需付费，所以本仓库已改为公开。
> **国内访问**：github.io 时好时坏。

### Vercel（纯网页操作，不用敲命令）

```
vercel.com → Sign up with GitHub（授权）
→ Import Git Repository → 选 today-eat-what → Deploy
→ 网址：https://today-eat-what-xxx.vercel.app
```

> **注意**：`vercel.app` 在国内访问**同样不稳**。Vercel 的优势是部署方便、适合给国外的人看，
> **它不能解决国内访问问题**。

### Gitee Pages —— ❌ 已停服

2025 年起 Gitee 服务菜单里已经没有 Pages 了，不要去找。

---

## 六、排查速查表

| 报错 | 原因 | 解决 |
|---|---|---|
| `not a git repository` | 不在项目目录 | `cd` 到项目目录，用 `pwd` 确认 |
| `Permission denied (publickey)` | 平台没登记你的公钥 | 把 `~/.ssh/id_ed25519.pub` 内容贴到该平台 |
| `! [rejected] ... (fetch first)` | 远程有本地没有的提交 | `git push --force`（自己的库、确认远程内容不要了） |
| `Unable to create index.lock` | 有残留锁文件 | 删掉 `.git/index.lock` 再试 |
| `fatal: unable to access ... schannel` | Windows TLS 问题 | `git config --global http.sslBackend openssl`（已配过） |
| 中文变乱码 | 用了 `Get-Content`/`Set-Content` | `git checkout HEAD -- 文件` 回滚，改用 Node 编辑 |

---

## 七、当前状态（2026-10-12 记录）

```
本地最新提交：3587338 docs: 添加项目交接文档
未推送内容：  V1.0 全部改动（index.html 重写、docs/ 7 个文档、tests/）
待执行：      git add -A && git commit && git push && git push gitee
```
