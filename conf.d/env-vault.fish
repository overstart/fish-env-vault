# Fish 启动时自动加载 GPG 加密密钥库。
# 仅在存在非交互密码（ENV_VAULT_PASSPHRASE）时静默解密 source，明文只流经管道、不落地。
# 绝不主动提示或阻塞：新开终端/tmux 窗口不会弹密码。
# 需要在当前窗口使用变量时执行 env-vault-load：loopback 输入的密码不经 gpg-agent 缓存，
# 变量只注入当前 shell（当前 window/pane），不影响其他窗口。
function __env-vault-autoload
    set -q ENV_VAULT_PASSPHRASE[1]; or return 0
    set -l file (__env-vault-file)
    test -f $file; or return 0
    __env-vault-decrypt $file 2>/dev/null | source
end

__env-vault-autoload
