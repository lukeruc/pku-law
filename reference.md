# pkulaw-mcp 完整参考手册

> 依据：npm 官方 README（v0.2.x）+ 本机 `pkulaw-mcp 0.2.3` 实测输出整理。
> 工具名/参数名线上可能更新，最终以 `pkulaw-mcp tools <serverId>`、`pkulaw-mcp <serverId> <tool> --help` 为准。

**目录**

1. [安装与环境要求](#1-安装与环境要求)
2. [密钥与鉴权（含多密钥故障转移）](#2-密钥与鉴权含多密钥故障转移)
3. [命令一览](#3-命令一览)
4. [调用工具：语法与参数规则](#4-调用工具语法与参数规则)
5. [各服务与工具参数详解](#5-各服务与工具参数详解)
6. [配置文件详解](#6-配置文件详解)
7. [输出格式](#7-输出格式)
8. [排障](#8-排障)
9. [安全注意事项](#9-安全注意事项)

---

## 1. 安装与环境要求

- Node.js ≥ 18（启动阶段即校验）、npm ≥ 9 建议。
- 安装/升级：`npm install -g @pkulaw/mcp-cli`；升级 `npm update -g @pkulaw/mcp-cli`。
- 验证：`pkulaw-mcp -v`、`pkulaw-mcp --help`。
- 需在北大法宝 MCP 服务平台（mcp.pkulaw.com）获取 Access Token 并订阅相应 MCP 服务。

## 2. 密钥与鉴权（含多密钥故障转移）

CLI 原生支持 3 种传入方式（优先级从高到低）：

| 优先级 | 方式 | 做法 | 适用场景 |
|---|---|---|---|
| 1 | 环境变量 | `export PKULAW_MCP_AUTHORIZATION='Bearer <Token>'` | CI/临时换 key，不落盘；**运行时优先于配置文件** |
| 2 | 配置文件 | `pkulaw-mcp init --authorization "Bearer <Token>"` 或 `pkulaw-mcp config set authorization "Bearer <Token>"` → 写入 `~/.pkulaw/mcp/config.json` | 日常本机持久使用 |
| 3 | init 命令行参数 | `pkulaw-mcp init --authorization "Bearer <Token>"`（进入 config.json） | 会进 shell 历史，公共环境慎用 |

格式要求：`Bearer` + **恰好一个空格** + Token，不要漏写/多写。

CLI 原生**不支持** .env 文件。多密钥故障转移由本 skill 的包装器提供：

### scripts/pkulaw.sh（多密钥 failover 包装器）

```
用法:
  pkulaw.sh <serverId> <toolName> [位置参数] [--参数 值 ...] [--md|--json]  # 业务调用
  pkulaw.sh probe                # 探测所有配置密钥的可用性
  pkulaw.sh raw <原生命令...>    # 用选中密钥执行任意 pkulaw-mcp 子命令
```

- 密钥来源优先级：`PKULAW_MCP_AUTHORIZATION` 环境变量 → skill 目录 `auth.env`（自上而下逐个尝试）→ `~/.pkulaw/mcp/config.json`（不设环境变量直接回落）。
- 执行业务调用前先用一次廉价真实调用（默认 `law-keyword get_law_list --title 民法典`）探测密钥；失效（401/403）、限速（429）、网关异常则自动切下一个，全部失败回落 config.json。
- 探测命令可配：环境变量 `PKULAW_PROBE_SERVER` / `PKULAW_PROBE_TOOL` / `PKULAW_PROBE_ARGS`；密钥文件路径可用 `PKULAW_AUTH_FILE` 覆盖。

### auth.env 多密钥文件

编辑 `/home/luke/projects/skills/pku-law/auth.env`（模板见 `auth.env.example`）：

```bash
# 每行一个密钥，编号从 1 递增；值可写完整 'Bearer xxx' 或裸 token（自动补 Bearer）
# 把最稳定/额度最足的密钥放最前面
KEY1='Bearer 27970cd5-6f2a-3b4e-a6d6-228f48c4b78b'
KEY2='11111111-2222-3333-4444-555555555555'
KEY3='bare-token-without-bearer-prefix'
```

## 3. 命令一览

| 命令 | 作用 |
|---|---|
| `pkulaw-mcp init [--gateway-base-url <url>] [--authorization "Bearer …"] [--verbose]` | 写入 `~/.pkulaw/mcp/config.json` 并拉取各服务 tools/list 缓存（需数十秒） |
| `pkulaw-mcp check`（别名 `doctor`） | 检查配置文件、JSON 合法性、必填项齐全 |
| `pkulaw-mcp update`（别名 `refresh`）`[--verbose]` | 重新拉取 tools/list 更新缓存 |
| `pkulaw-mcp tools [serverId]`（别名 `list-tools`、`ls`） | 列出全部服务（含各服务工具数与文档链接），或某服务下工具与参数 |
| `pkulaw-mcp docs [serverId] [--open]` | 打印各服务在线技术文档 URL（无需 init）；`--open` 用浏览器打开（须指定 serverId） |
| `pkulaw-mcp config list / get <key> / set <key> <value> / set-path <serverId> <path>` | 查看/修改配置 |
| `pkulaw-mcp <serverId> <toolName> [参数...]` | 实际调用工具（须该服务缓存中有工具） |

调试环境变量：`PKULAW_MCP_DEBUG=1`（同 `update --verbose`，向 stderr 打印请求 URL、HTTP 状态，不含完整 Token）。

## 4. 调用工具：语法与参数规则

```
pkulaw-mcp <serverId> <toolName> [位置参数] [--参数名 值 ...] [--markdown|--md|-m] [--json]
```

- 工具名、长选项名来自网关 `inputSchema`，**必须与本机 `tools <serverId>` 输出一致**；报 `unknown option '--xxx'` 说明线上字段名变了，用 `--help` 核对。
- **位置参数映射**：schema 含 `searchKey` 时映射到它；否则映射到 `required` 第一个字段；若无必填则映射到 properties 第一个键（易不符预期）。因此：单主文本入参推荐位置参数；多必填或全是可选时只用 `--字段 值`。
- **不要写 `--text * "正文"`**：`*` 会被当成该选项的真实取值（不是通配符）。正确写法 `--text "正文"` 或位置参数。
- **对象/大 JSON 参数**三种写法：
  - `--<字段>-file <路径>`（最稳，跨 shell 通用，CLI 按 UTF-8 读取）
  - `--<字段>=@./x.json` 或 `--<字段> '@./x.json'`（类 curl `@file`，读文件后 JSON.parse）
  - 内联 JSON：`--param '{"key":1}'`；PowerShell 引号陷阱多，优先用 `-file`
  - `--<字段> "b64:<Base64>"`：Base64 内联，避免引号转义（超长 payload 仍建议 `-file`）
  - `--<字段>` 与 `--<字段>-file` 不能同用。
- PowerShell 特别注意：`@` 紧跟空格是 splat 语法，必须写 `--param=@路径` 或 `--param '@路径'`。

## 5. 各服务与工具参数详解

以下为 2026-08 本机实测（CLI 0.2.3）。**（必填）**表示 schema 必填。

### 5.1 law-keyword 检索法律法规-关键词

**`get_law_list`** — 查询法规列表，返回前 20 条

| 参数 | 说明 |
|---|---|
| `--title` | 标题关键词（如 `刑法`）；与 `--fulltext` 至少一个非空 |
| `--fulltext` | 正文关键词（如 `盗窃罪`） |
| `--startImplementDate` / `--endImplementDate` | 施行日期范围，如 `2024.1.1` |
| `--timeliness` | 时效性：`现行有效` `废止或失效` `尚未施行` `已被修改` `部分废止或失效` |
| `--effectiveness` | 效力位阶：`法律` `行政法规` `监察法规` `司法解释` `部门规章` `军事法规规章` `党内法规制度` `行业规定` `团体规定` `地方性法规` `自治条例和单行条例` `地方政府规章` `地方规范性文件` `地方司法文件` `地方工作文件` `行政许可批复` |

```bash
pkulaw-mcp law-keyword get_law_list --title '刑法' --fulltext '盗窃罪'
```

### 5.2 law-semantic 检索法律法规-语义

**`search_article`** — 语义检索法条

| 参数 | 说明 |
|---|---|
| `--text`（必填） | 检索关键词或自然语言文本 |
| `--lib` | 法规库：`中央` `地方` |
| `--timeliness` | 同上时效性枚举 |
| `--issue_department` | 制定机关全称，如 `交通运输部` |
| `--implement_date_start` / `--implement_date_end` | 施行日期范围，ISO `YYYY-MM-DD` |
| `--size` | 返回数量，默认 10，1–20 |

```bash
pkulaw-mcp law-semantic search_article "交通事故后对方全责，保险公司迟迟不赔付怎么办？" --md
```

**`get_article`** — 按法规标题 + 条号取法条内容

| 参数 | 说明 |
|---|---|
| `--title`（必填） | 法规标题（中文） |
| `--number`（必填） | 条号（中文），如 `第四十八条` |

### 5.3 case-keyword 检索司法案例-关键词

**`get_case_list`** — 查询案例列表，返回前 20 条

| 参数 | 说明 |
|---|---|
| `--title` | 标题关键词；与 `--fulltext` 至少一个非空 |
| `--fulltext` | 正文关键词，**多关键词用空格分隔**（如 `合同纠纷 房租纠纷`） |
| `--caseGrade` | 参照级别：`指导性案例` `参考案例` `公报案例` `典型案例` `参阅案例` `评析案例` `优秀案例` `经典案例` `应用案例` `法宝推荐` `普通案例` |
| `--caseClassName` | 案件类型，如 `民事一审` `首次执行` |
| `--documentAttr` | 文书类型：`判决书` `裁定书` `调解书` `决定书` `通知书` `支付令` |
| `--court` | 终审法院，如 `最高人民法院` |
| `--startLastInstanceDate` / `--endLastInstanceDate` | 审结日期范围，如 `2024.1.1` |

### 5.4 case-semantic 检索司法案例-语义

**`search_case`** — 自然语言案情语义检索

| 参数 | 说明 |
|---|---|
| `--text`（必填） | 案情描述或关键词 |
| `--case_type` / `--doc_type` | 案件类型 / 文书类型筛选 |
| `--courthouse_name` | 审理法院，如 `北京市海淀区人民法院` |
| `--courthouse_province` | 法院省份全称，如 `北京市`、`浙江省` |
| `--decision_date_start` / `--decision_date_end` | 审结日期范围，ISO `YYYY-MM-DD` |
| `--size` | 默认 10，1–20 |

### 5.5 fatiao 精准查找法条-关键词

**`get_law_item_content`** — 法规名 + 条号精确取条文全文

| 参数 | 说明 |
|---|---|
| `--title`（必填） | 标题关键词，如 `刑法` |
| `--tiao_num`（必填） | 条号数字：`2` = 第二条；`2.1` = 第二条之一；`2.2` = 第二条之二（整数或小数） |

```bash
pkulaw-mcp fatiao get_law_item_content --title '刑法' --tiao_num 3
```

### 5.6 case-number 案号识别与溯源

**`anhao_recognition`** — 从法律文本中自动识别案号，经法宝案例库标准化验证

| 参数 | 说明 |
|---|---|
| `--text`（必填） | 可能含案号的法律文本 |

返回：识别案号、标准案号、案例标题、审理法院、最终审结日期、链接。

```bash
pkulaw-mcp case-number anhao_recognition --text '（2021）最高法民申4246号'
```

### 5.7 law-recognition 法条识别与溯源

**`law_recognition`** — 从文本中识别法规名称与条款，对齐标准库返回法条全文与来源链接

| 参数 | 说明 |
|---|---|
| `--text`（必填） | 含法规引用的法律文本 |

```bash
pkulaw-mcp law-recognition law_recognition --text "根据《中华人民共和国民法典》第一千二百六十条规定……"
```

### 5.8 doc-link 法宝超链

**`get_linked_content`** — 为文本智能添加法规文档超链接（自动识别法规条文、法律概念、术语）

| 参数 | 说明 |
|---|---|
| `--message`（必填） | 需处理的文本 |

### 5.9 citation-validator 修正生成幻觉-法条

**`adjust_provisions`** — 校验问答中的法条/司法解释引用，返回权威条文原文与引用地址，用于修正模型引注幻觉。仅法条相关问题调用；返回结果为权威依据，**严禁仅凭训练数据编造法条**。

| 参数 | 说明 |
|---|---|
| `--userlaw` | 从用户输入中严格提取的法规名称+法条编号集合 |
| `--answerlaw` | 推测需要检索的法规/条号/检索线索 |
| `--prompt` | 用户原始问题，原样透传 |

`param` 为 object 时支持 `--param-file`、`--param=@路径`、内联 JSON、`b64:`（见第 4 节）。示例文件随 npm 包发布于 `examples/citation-validator-adjust-provisions.param.json`，结构：

```json
{
  "userlaw":   [{"title": "中华人民共和国民法典", "article_number": "第二条"}],
  "answerlaw": [{"title": "中华人民共和国民法典", "article_number": "第二条",
                 "text": "民法调整平等主体的自然人…"}],
  "prompt": "民法典第二条的规定是什么？"
}
```

### 5.10 semantic-nlsql 法宝语义检索（NL-SQL）

需控制台实例专属路径，先配置再使用：

```bash
pkulaw-mcp config set-path semantic-nlsql "/<控制台复制的路径>/mcp"
pkulaw-mcp update
pkulaw-mcp tools semantic-nlsql          # 工具名以此为准（常见 ai_pkulaw_search）
pkulaw-mcp semantic-nlsql ai_pkulaw_search --user_question '查询国务院发布的关于公司的法规有哪些？'
```

## 6. 配置文件详解

`~/.pkulaw/mcp/config.json`（Windows：`C:\Users\<用户名>\.pkulaw\mcp\config.json`）：

| 键 | 含义 |
|---|---|
| `gatewayBaseUrl` | 网关根地址（默认 `https://apim-gateway.pkulaw.com`），**末尾不要带 `/`** |
| `authorization` | 完整 Authorization 头（`Bearer` + 空格 + Token） |
| `timeoutMs` | HTTP 超时毫秒，默认 60000 |
| `serverPaths.<serverId>` | 覆盖某服务网关路径，以 `/` 开头、通常以 `/mcp` 结尾 |

缓存文件：`~/.pkulaw/mcp/cache/tools.json`（init/update 写入）。

内置服务清单随 npm 包发布于包内 `dist/config/servers.json`（含各服务 docUrl），一般无需手动编辑。

```bash
pkulaw-mcp config list
pkulaw-mcp config get gatewayBaseUrl
pkulaw-mcp config set authorization "Bearer <Token>"
pkulaw-mcp config set serverPaths.semantic-nlsql "/路径/mcp"
pkulaw-mcp config set-path semantic-nlsql "/路径/mcp"
```

## 7. 输出格式

- 默认：`JSON.stringify` 缩进格式化 JSON（脚本友好）。
- `--markdown` / `--md` / `-m`：尽量转 Markdown（终端易读）。
- `--json`：与默认相同（供脚本显式声明意图）。

## 8. 排障

| 现象 | 处理 |
|---|---|
| 找不到 `pkulaw-mcp` 命令 | `npm install -g @pkulaw/mcp-cli`；或项目内 `npx pkulaw-mcp …` |
| 401 / 403 / 「认证失败」 | Token 过期或未订阅该服务；确认 `Bearer` + 恰好一个空格；若用环境变量确认当前终端已设置。多密钥场景：`scripts/pkulaw.sh probe` 诊断，切换 auth.env 下一密钥 |
| 429 | 限速 → 切换密钥或稍后重试 |
| 4xx（400/404 等） | 订阅不含该路由 / serverPaths 与控制台不一致 / 请求体校验失败；对照 `pkulaw-mcp check` |
| 某服务工具数为 0 | 先 `pkulaw-mcp update`；仍为 0 检查订阅与网络；`update --verbose` 或 `PKULAW_MCP_DEBUG=1` 看请求详情 |
| `unknown option '--xxx'` | 线上字段名变了：`pkulaw-mcp <serverId> <tool> --help` 查真实选项；单主串用位置参数 |
| `--xxx-file` 与 `--xxx` 冲突 | 同一字段二选一 |
| PowerShell `@` 报错 | 用 `--param=@路径`、`--param '@路径'` 或 `--param-file` |
| PowerShell 内联 JSON 失败 | 依次改试 `--param-file` → `=@路径` → README 给定的 PowerShell 内联写法 → `b64:` |

## 9. 安全注意事项

- 勿将含 Token 的 `config.json`、`auth.env` 提交到 Git 或发到公开渠道。
- `--authorization` 整行命令会进 shell 历史；公共环境用 `PKULAW_MCP_AUTHORIZATION` 环境变量。
- 调试输出（`--verbose` / `PKULAW_MCP_DEBUG=1`）不含完整 Token，但可能含业务关键词与响应正文，勿在公开渠道粘贴完整输出。

---

_在线文档：`pkulaw-mcp docs` 可列出各服务文档 URL；源码 https://gitee.com/pkulaw/pkulaw-mcp-cli_
