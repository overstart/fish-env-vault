# 移除由密钥库管理的全部变量。
# 直接从密钥库获取键名（复用 env-vault list），避免变量已存在于 shell 时差集失效。
# 用法: secrets-unload [FILE]
function secrets-unload
    set -l file (__env-vault-file $argv)
    if not test -f $file
        echo "secrets-unload: 找不到密钥库 $file" >&2
        return 1
    end
    set -l names (env-vault --file $file list 2>/dev/null)
    for n in $names
        set -e $n
    end
end
