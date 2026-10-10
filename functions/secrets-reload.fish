# 先卸载再加载，使当前 shell 的变量与密钥库同步。
# 用法: secrets-reload [FILE]
function secrets-reload
    set -l file (__env-vault-file $argv)
    secrets-unload $file
    and secrets-load $file
end
