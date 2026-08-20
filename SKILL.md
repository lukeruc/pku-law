---
name: pku-law
description: 北大法宝法律检索 CLI（pkulaw-mcp）：检索法律法规/司法案例（关键词与语义）、按标题+条号取法条原文、案号识别溯源、法条识别溯源、法规超链、法条引注幻觉校验。当用户需要查法条、找判例/案例、验证法条引用真伪、识别案号、合同审核中核对法律依据，或提到"北大法宝""pkulaw""查一下法律规定""类似判例"时使用本 skill。
---

# 北大法宝 MCP CLI（pkulaw-mcp）

终端直连北大法宝网关的法律检索工具（`tools/list` + `tools/call`），不经 LLM，结果为权威库数据。本机已全局安装并配置密钥。

## 快速调用（推荐入口）

```bash
# 多密钥故障转移包装器：密钥失效/限速时自动切换 auth.env 中的下一个密钥
/home/luke/projects/skills/pku-law/scripts/pkulaw.sh <serverId> <toolName> [参数...]

# 示例：语义检索法条（自然语言提问）
scripts/pkulaw.sh law-semantic search_article "租房合同纠纷适用哪些法律条款"

# 示例：精准取法条原文
scripts/pkulaw.sh fatiao get_law_item_content --title 民法典 --tiao_num 2
```

也可直接用原生命令（走 `~/.pkulaw/mcp/config.json` 里的单密钥）：

```bash
pkulaw-mcp <serverId> <toolName> [位置参数] [--参数名 值 ...] [--md|--json]
```

## 服务一览

| serverId | 用途 | 常见工具 |
|---|---|---|
| `law-keyword` | 法规关键词检索（标题/正文） | `get_law_list` |
| `law-semantic` | 法规语义检索 + 按条号取法条 | `search_article`、`get_article` |
| `case-keyword` | 案例关键词检索 | `get_case_list` |
| `case-semantic` | 案例语义检索（自然语言描述案情） | `search_case` |
| `fatiao` | 精准查法条原文（标题+条号） | `get_law_item_content` |
| `case-number` | 案号识别与标准化溯源 | `anhao_recognition` |
| `law-recognition` | 文本中法条识别与溯源 | `law_recognition` |
| `doc-link` | 为文本添加法规超链 | `get_linked_content` |
| `citation-validator` | 法条引注幻觉校验（返回权威原文） | `adjust_provisions` |

## 密钥与故障转移

密钥优先级：环境变量 `PKULAW_MCP_AUTHORIZATION` > skill 目录下 `auth.env`（多密钥，自上而下）> `~/.pkulaw/mcp/config.json`。

多密钥配置：编辑 `/home/luke/projects/skills/pku-law/auth.env`，每行 `KEYn='Bearer <token>'`（裸 token 会自动补 Bearer）。诊断密钥可用性：`scripts/pkulaw.sh probe`。

## 关键注意点

- 工具名、参数名**以 `pkulaw-mcp tools <serverId>` 和 `--help` 实时输出为准**，线上可能更新，勿凭记忆猜参数。
- 单主文本入参的工具可直接用位置参数传主文本，避免猜字段名。
- 输出默认 JSON；终端阅读加 `--md`。
- 401/403 = 密钥失效，429 = 限速 → 用包装器或换 `auth.env` 中下一个密钥。

## 完整文档

全部命令、每个工具的完整参数细节、文件传参（`--xxx-file` / `@路径` / `b64:`）、PowerShell 陷阱、NL-SQL 服务、配置项与排障：**阅读本目录 [reference.md](reference.md)**。查具体工具参数时直接 `pkulaw-mcp tools <serverId>` 或 `pkulaw-mcp <serverId> <tool> --help` 最准。
