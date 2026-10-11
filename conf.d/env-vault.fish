# Fish 启动时自动加载 GPG 加密密钥库。
# 管道解密直接 source：明文只流经管道，不写入磁盘。
# 解密失败（无密钥库 / 取消 pinentry）静默跳过，不阻断启动。
function __env-vault-autoload
    set -l file (__env-vault-file)
    test -f $file; or return 0
    __env-vault-decrypt $file 2>/dev/null | source
end

# 仅在“交互式 shell 启动”时自动加载：
# - bin/env-vault 等非交互子进程不弹密码；
# - fisher 安装/更新时会在其函数内 source 本文件（调用栈无 during startup），同样跳过。
if status is-interactive
    set -l trace (status stack-trace 2>/dev/null; or status print-stack-trace 2>/dev/null)
    if string match -q -- '*called during startup*' -- $trace
        __env-vault-autoload
    end
end
