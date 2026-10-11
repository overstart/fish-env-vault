# 先卸载再加载，使当前 shell 的变量与密钥库同步。
# 用法: env-vault-reload [FILE]
function env-vault-reload
    set -l file (__env-vault-file $argv)
    env-vault-unload $file
    and env-vault-load $file
end
