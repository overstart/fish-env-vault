# env-vault

GPG 对称加密的 Fish 环境变量密钥库。磁盘零明文、一份加密文件即可跨机器迁移，提供 CLI 完成密钥的增删改查与导入导出。

## 为什么

- Fish 原生 `set -Ux` 写死在 `fish_variables`，绑定机器、无法迁移、不能纳入 dotfiles。
- 明文 `secrets.fish` 无法安全备份或同步。

env-vault 把所有变量加密进单个文件，需要时管道解密 `source`（明文不落地），变量以 `set -gx` 注入当前 shell。

## 依赖

`fish` + `gpg`（GnuPG）。无其他运行时依赖。

## 安装

### Fisher

一条命令同时安装 `env-vault` 命令、自动加载与插件函数：

```fish
fisher install overstart/fish-env-vault
```

安装后新终端即可直接使用 `env-vault`，无需任何额外的软链或 PATH 设置。

### 手动

```sh
git clone https://github.com/overstart/fish-env-vault
cd fish-env-vault
./install.sh
```

## 快速开始

```fish
env-vault init                          # 创建密钥库，设置密码
env-vault set GITHUB_TOKEN ghp_xxx      # 新增
env-vault list                          # 只列变量名，免密码
env-vault list --values                 # 连值一起看，需要密码
env-vault get GITHUB_TOKEN              # 查看值
```

在需要的窗口执行 `secrets-load` 并输入密码后，`echo $GITHUB_TOKEN` 即可用；变量只注入当前 shell，不影响其他终端或 tmux 的 window/pane。新开窗口不会提示密码，需要时再 `secrets-load`。若希望启动时静默自动加载，可设置 `ENV_VAULT_PASSPHRASE`（见[脚本化](#脚本化)）。

## 命令

| 命令 | 说明 |
| --- | --- |
| `init [--force]` | 创建密钥库 |
| `set NAME [VALUE] [--force]` | 新增变量；省略 VALUE 时安全输入。已存在需 `--force` |
| `edit NAME [VALUE]` | 修改已有变量的值 |
| `get NAME` | 查看变量值 |
| `list [--values]` | 列出变量名（默认无值、免密码，读 `.keys` 索引）；`--values` 才解密需要密码 |
| `rm NAME... [--force]` | 删除变量 |
| `import FILE [--force]` | 从 `.env` / `.fish` / `.gpg` 导入 |
| `export [--format fish\|dotenv\|gpg] [--to FILE]` | 导出 |
| `change-passphrase [--new-passphrase PWD]` | 修改密码；交互时先验证原密码 |
| `path` | 显示密钥库路径 |

全局选项：`--file FILE`、`--passphrase PWD`。

## 插件函数

- `secrets-load [FILE]`：加载密钥库到当前 shell
- `secrets-reload [FILE]`：重新加载
- `secrets-unload [FILE]`：移除由密钥库管理的变量

## 脚本化

避免在命令行传密码（会出现在进程列表），使用环境变量：

```fish
set -x ENV_VAULT_PASSPHRASE 'your-pass'
env-vault set FOO bar
env-vault change-passphrase                 # ENV_VAULT_PASSPHRASE 作原密码，配合 ENV_VAULT_NEW_PASSPHRASE
```

交互终端执行 `change-passphrase` 时，即使已设置 `ENV_VAULT_PASSPHRASE` 或 gpg-agent 有缓存，也会先要求当场输入原密码；非 TTY 脚本环境以 `ENV_VAULT_PASSPHRASE` / `--passphrase` 为原密码。

## 跨机器迁移

1. 新机器安装 `gpg`；
2. 拷贝 `secrets.fish.gpg` 到同路径（可选一并拷贝 `.keys` 索引，不拷也不影响）；
3. 输入密码执行一次 `secrets-load` 或任意需要解密的命令，全部变量恢复；未带索引时首次 `list` 会解密一次并自动重建 `.keys`。

默认密钥库路径：`~/.config/fish/secrets/secrets.fish.gpg`，可用 `ENV_VAULT_FILE` 覆盖。

备份/迁移用加密格式（无需密码即可拷贝）：

```fish
env-vault export --format gpg --to backup.gpg
```

## 安全说明

- 加密：GPG 对称加密（AES-256），S2K SHA-512。
- S2K 迭代默认 ~3M（约 10ms），可用 `ENV_VAULT_S2K_COUNT` 调高（65M 约 89ms，离线爆破抗性更强）。
- 密钥库文件权限 600，目录 700。
- 为支持免密 `list`，变量名（不含值）以明文保存在密钥库旁的 `<密钥库>.keys` 索引文件（权限 600），随每次写入自动重建；删除后下次需解密的命令会再生成。介意变量名泄露者应一并保护好 `secrets/` 目录。
- dotfiles 中建议忽略 `~/.config/fish/secrets/`，仅在私钥/密码受信任时才将加密库纳入版本控制。

## 测试

```fish
fish tests/selftest.fish
```
