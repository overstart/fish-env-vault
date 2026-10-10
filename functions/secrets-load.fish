# 解密并加载密钥库到当前 shell。
# 用法: secrets-load [FILE]
function secrets-load
    set -l file (__env-vault-file $argv)
    if not test -f $file
        echo "secrets-load: 找不到密钥库 $file" >&2
        return 1
    end
    __env-vault-decrypt $file | source
end
