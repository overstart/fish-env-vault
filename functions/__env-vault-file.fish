# 返回密钥库路径: 参数 > ENV_VAULT_FILE > $XDG_DATA_HOME/env-vault/vault.gpg。
function __env-vault-file
    if test (count $argv) -ge 1 -a -n "$argv[1]"
        echo $argv[1]
    else if set -q ENV_VAULT_FILE[1]
        echo $ENV_VAULT_FILE
    else
        set -l data_home (set -q XDG_DATA_HOME[1]; and echo $XDG_DATA_HOME; or echo "$HOME/.local/share")
        echo "$data_home/env-vault/vault.gpg"
    end
end
