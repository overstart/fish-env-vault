# 统一解密: loopback 模式让 gpg 直接在当前终端提示输入密码，不弹 GUI 窗口（无 GUI 系统也可用）。
# 有 ENV_VAULT_PASSPHRASE 时走非交互；无 tty（如管道）时解密失败，由调用方静默处理。
function __env-vault-decrypt
    set -l file $argv[1]
    if set -q ENV_VAULT_PASSPHRASE[1]
        gpg -d --quiet --batch --pinentry-mode loopback \
            --passphrase-file (printf '%s' $ENV_VAULT_PASSPHRASE | psub -f) -- $file
    else
        gpg -d --quiet --pinentry-mode loopback -- $file
    end
end
