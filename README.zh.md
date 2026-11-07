# fh-llmwiki

> 原名 **forge-wiki**(2026-11-07 更名)。旧 GitHub 地址会自动跳转,`fw` 命令不变。

**[English](README.md)** · **[한국어](README.ko.md)** · **[日本語](README.ja.md)** · 中文

为 LLM 智能体 — 以及与它们协作的人 — 打造的内置治理的 Markdown Wiki。

大多数智能体知识工具走向两个极端:要么是全自动记忆(mem0、Zep、Letta — 根本没有
审批概念),要么是人工策展服务。fh-llmwiki 坚守中间地带:
**智能体来写,人来把关,索引自我维护。**

## 三项设计承诺

1. **内容靠策展,新鲜度靠推导。** `INDEX.md` 中的 `AUTO-INDEX` 块由 frontmatter 和
   文件名日期再生成 — 该块的合并冲突通过再生成解决,而非手工合并。经并发多写入者
   模拟验证(见 `tests/` — 最多 50 个写入者,含破坏注入)。
2. **兼容 OKF v0.1。** 文件为 Markdown + YAML frontmatter(`type`、`description`)、
   保留 `index.md`、链接即关系边 — 任何 OKF 消费者都能读取,无锁定。
3. **作用域写入,门控合并。** 每个写入者只拥有自己的文件;跨作者变更是提案
   (PR/交接),而非静默编辑。HITL 不是功能开关,而是写入协议本身。人工门的存在
   是为了叠加**品味** — 个人与组织的判断 — 而不是抓缺陷:功能完整性是机器层的职责,
   在触达评审者之前已由模拟验证。

## 快速开始

无需安装:单个 Python 文件,除 `python3` 外无依赖。clone 一次,放在任意位置,按路径调用。

```sh
git clone https://github.com/chrono-meta/fh-llmwiki.git ~/tools/fh-llmwiki
alias fw='python3 ~/tools/fh-llmwiki/bin/fw.py'   # 可选 —— 下面的示例都用 `fw`

cd your-knowledge-repo   # 承载 Wiki 的仓库 —— 不是上面 clone 的那个
fw init                  # Phase-0 审计 + 非覆盖式脚手架(创建 signals/)
mkdir -p memory          # 其余分区自己建 —— 分区就是一个目录
# 将 Markdown 文件放入分区目录
fw sync --write          # 再生成新鲜度索引 + llms.txt
fw doctor                # 新鲜度 + 失效指针报告
```

**成功的判据**:`INDEX.md` 中出现按分区列出你文件的 `AUTO-INDEX` 块,且 `fw check` 退出码为 0。
`doctor` 是建议性的 —— **非零退出码是一份报告,不是安装失败。**

此时你的仓库长这样:

```
your-knowledge-repo/
├── INDEX.md      上半部是人工策展的指针,下半部是生成的 AUTO-INDEX 块
├── AGENTS.md     init 追加的 Wiki 协议块 —— 面向 Agent 的契约
├── llms.txt      每次 sync --write 时生成
├── memory/
└── signals/
```

`INDEX.md` 出现合并冲突时:任取一方,运行 `fw heal --write`。完事。

## 你的组织实例

`fw init` 给你一个能跑的索引,但它不会告诉你*该往里放什么* —— 那个决定才让这个 Wiki
成为你们的,而且没有任何工具能代劳。

本工具设定的配对:**Harness 承载方法与门控,Wiki 承载组织语境。** 二者不能互相替代。
没有语境落地点的 Harness 每个会话都要重新推导同样的组织事实;没有 Harness 的 Wiki
则对什么能进来毫无门控。

一套经受了约 2 个月日常运营的分区轴(981 个文件 —— 前四个分区占其中 73%):

| 分区 | 存放 | 何时进入 |
|---|---|---|
| `memory/` | 比发现它的那次会话活得更久的事实 | 该事实还会再被需要,且无法从代码推导时 |
| `tracks/<project>/` | 按项目累积的工作记录 | 该项目的工作产出了值得重读的东西 |
| `signals/` | *可能*在日后重要的观察与测量 | 注意到的当下 —— 在知道它是否有价值之前就记下 |
| `handoff/` | 在机器、会话、人之间传递的状态 | 下一个读者不是当前的书写者 |
| `audit/` | 按节奏进行的周期性复查 | 节奏触发时,而非兴之所至时 |
| `digests/` | 重复性的外部扫描 | 自动任务落下其输出时 |

**从两个开始** —— `memory/` 和 `signals/`。其余的,等某个文件确实放不进现有分区的第一刻
再让它出现。加一个目录很便宜。**没人写入的分区,是删除的信号,不是填充的信号。**

**放哪一个?** 两个问题基本就能定。*这个能从代码里重新推导出来吗?* —— 能,就不该进
`memory/`。*已经有结论了吗?* —— 没有,那它就是 `signals/` 条目,而不是决策记录。

`examples/org-instance/` 是最小骨架。把它复制到一个**尚未 `init`** 的仓库 —— 它自带
`INDEX.md`,而 `fw init` 不会覆盖已存在的 INDEX.md:

```sh
cp -r ~/tools/fh-llmwiki/examples/org-instance/. your-knowledge-repo/
cd your-knowledge-repo
fw init          # 保留复制过来的 INDEX.md,只追加 AGENTS.md 块
fw sync --write
```

## 子命令

| cmd | 作用 | 失败方向 |
|---|---|---|
| `init` | 状态审计 + 脚手架(绝不覆盖) | 已有文件则拒绝 |
| `sync [--write]` | 再生成 AUTO-INDEX 块 | 默认 dry-run |
| `heal [--write]` | 清理冲突标记/重复块后 sync | 策展区冲突留给人 |
| `lint` | frontmatter 报告 | 只报告,绝不改写 |
| `doctor` | 新鲜度 + 失效指针报告 | 仅建议 |
| `check` | 索引漂移门 | 漂移时 exit 1(CI 阻断) |

## 多个 wiki — 公司、组织、项目、个人

每个保密边界一个 wiki,wiki 之间只用链接清单(registry)相连,不复制内容。
契约见 [`LAYERS.md`](LAYERS.md)(层 L0–L3、何时拆分仓库、从个人 wiki 提升到组织 wiki);
机器能检查的部分由 `bin/fw_layers.py`(`declare` · `links` · `frontmatter` · `promote` ·
`split-report` · `registry`)负责。数据库或 MCP 网关是条件出现时才添加的适配器,
以操作说明的形式放在 [`adapters/`](adapters/README.md),默认不接入任何一个。

## 状态

v0.1 — 提炼自一个每日运营约 2 个月的私有运营者 Wiki:**981 个 Markdown 文件、57 天中
50 天有提交、多机器**(2026-07-21 实测 — `git ls-files '*.md' | wc -l`;存储库本身不公开)。
`tests/` 中的并发模拟是所有健壮性声明的回归锚:模拟未测量的,这里不做声明。

## 分发表面

- `llms.txt` — 每次 `sync --write` 时生成(与索引同为推导物)。
- `bin/fw_mcp.py` — 零依赖只读 MCP 服务器(`wiki_index` / `wiki_get` / `wiki_search`)。
  读取走 MCP,写入走 git + 门控 — 这种不对称不是缺失的功能,而是写入协议本身。
  `claude mcp add fh-llmwiki -- python3 <abs>/bin/fw_mcp.py <wiki_root>`

完整契约见 `SPEC.md`。
