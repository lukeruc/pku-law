# pku-law

北大法宝法律检索 Skill：为 Claude Code 等 AI Agent 提供 [pkulaw-mcp CLI](https://www.npmjs.com/package/@pkulaw/mcp-cli) 的完整用法知识，并附带**多密钥故障转移**包装器。

Agent 加载本 skill 后即可掌握北大法宝 MCP CLI 的全部能力：

- **法律法规检索**：关键词（law-keyword）/ 语义（law-semantic）
- **司法案例检索**：关键词（case-keyword）/ 语义（case-semantic）
- **精准取法条原文**（fatiao：法规名 + 条号）
- **案号识别与溯源**（case-number）
- **法条识别与溯源**（law-recognition）
- **法规超链**（doc-link）
- **法条引注幻觉校验**（citation-validator：返回权威条文原文，防模型编造法条）

## 目录结构

```
pku-law/
├── SKILL.md            # Skill 入口：基础功能、快速调用、密钥配置（Agent 加载后常驻上下文）
├── reference.md        # 完整参考手册：10 个服务、全部工具参数、传参规则、排障
├── auth.env.example    # 多密钥配置模板（复制为 auth.env 使用）
├── scripts/
│   └── pkulaw.sh       # 多密钥故障转移包装器
└── .gitignore          # 排除 auth.env（含真实密钥，禁止入库）
```

## 快速开始

### 1. 安装 CLI 并配置密钥

```bash
npm install -g @pkulaw/mcp-cli
pkulaw-mcp init --authorization "Bearer <你的Token>"   # 写入 ~/.pkulaw/mcp/config.json
pkulaw-mcp check
```

Token 在 [北大法宝 MCP 服务平台](https://mcp.pkulaw.com) 获取，需订阅相应 MCP 服务。

### 2. （推荐）配置多密钥故障转移

```bash
cp auth.env.example auth.env
# 编辑 auth.env，每行一个密钥：
# KEY1='Bearer <最稳定的token>'
# KEY2='<备用token>'          # 裸 token 自动补 Bearer 前缀
```

密钥失效（401/403）、限速（429）或网关异常时，包装器自动切换下一个密钥；全部失败回落到 `~/.pkulaw/mcp/config.json`。

### 3. 使用

```bash
# 多密钥包装器（推荐）
./scripts/pkulaw.sh law-semantic search_article "租房合同纠纷适用哪些法律条款"
./scripts/pkulaw.sh fatiao get_law_item_content --title 民法典 --tiao_num 2
./scripts/pkulaw.sh probe                 # 诊断所有密钥可用性

# 或直接用原生命令（走 config.json 单密钥）
pkulaw-mcp case-semantic search_case --text "房屋租赁合同到期后房东拒绝退还押金"
```

## 密钥优先级

```
PKULAW_MCP_AUTHORIZATION 环境变量  >  auth.env（自上而下）  >  ~/.pkulaw/mcp/config.json
```

## 作为 Claude Code Skill 安装

将本目录放入 `~/.claude/skills/`（或项目 `.claude/skills/`）即可，Claude 会依据 SKILL.md 的 description 自动触发。详见 [SKILL.md](SKILL.md) 与 [reference.md](reference.md)。

## 安全提示

- `auth.env` 已被 `.gitignore` 排除，**严禁**将含真实 Token 的文件提交到仓库
- `pkulaw-mcp init --authorization` 整行命令会进入 shell 历史，公共环境请改用环境变量

## 许可证

MIT
