# 返回密钥库路径: 参数 > ENV_VAULT_FILE > 默认路径。
function __env-vault-file
    if test (count $argv) -ge 1 -a -n "$argv[1]"
        echo $argv[1]
    else if set -q ENV_VAULT_FILE[1]
        echo $ENV_VAULT_FILE
    else
        echo "$HOME/.config/fish/secrets/secrets.fish.gpg"
    end
end
