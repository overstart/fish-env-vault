# env-vault 补全

complete -c env-vault -f -n 'not __fish_seen_subcommand_from init set edit get list rm import export change-passphrase path' \
    -a 'init' -d '创建密钥库'
complete -c env-vault -f -n 'not __fish_seen_subcommand_from init set edit get list rm import export change-passphrase path' \
    -a 'set' -d '新增变量'
complete -c env-vault -f -n 'not __fish_seen_subcommand_from init set edit get list rm import export change-passphrase path' \
    -a 'edit' -d '修改变量值'
complete -c env-vault -f -n 'not __fish_seen_subcommand_from init set edit get list rm import export change-passphrase path' \
    -a 'get' -d '查看变量值'
complete -c env-vault -f -n 'not __fish_seen_subcommand_from init set edit get list rm import export change-passphrase path' \
    -a 'list' -d '列出变量名'
complete -c env-vault -f -n 'not __fish_seen_subcommand_from init set edit get list rm import export change-passphrase path' \
    -a 'rm' -d '删除变量'
complete -c env-vault -f -n 'not __fish_seen_subcommand_from init set edit get list rm import export change-passphrase path' \
    -a 'import' -d '从 .env/.fish/.gpg 导入'
complete -c env-vault -f -n 'not __fish_seen_subcommand_from init set edit get list rm import export change-passphrase path' \
    -a 'export' -d '导出密钥库'
complete -c env-vault -f -n 'not __fish_seen_subcommand_from init set edit get list rm import export change-passphrase path' \
    -a 'change-passphrase' -d '修改密码'
complete -c env-vault -f -n 'not __fish_seen_subcommand_from init set edit get list rm import export change-passphrase path' \
    -a 'path' -d '显示密钥库路径'

# 变量名补全（解密失败则为空）
complete -c env-vault -f -n '__fish_seen_subcommand_from get edit rm' \
    -a '(__fish_env_vault_list)' -d '变量名'

# import 补文件
complete -c env-vault -f -n '__fish_seen_subcommand_from import' \
    -a '(__fish_complete_suffix)'

# 各子命令选项
complete -c env-vault -n '__fish_seen_subcommand_from init' -l force -d '覆盖已有密钥库'
complete -c env-vault -n '__fish_seen_subcommand_from set' -l force -d '覆盖已有变量'
complete -c env-vault -n '__fish_seen_subcommand_from list' -l values -d '连同值一起列出'
complete -c env-vault -n '__fish_seen_subcommand_from rm' -l force -d '忽略不存在的变量'
complete -c env-vault -n '__fish_seen_subcommand_from import' -l force -d '覆盖已有变量'
complete -c env-vault -n '__fish_seen_subcommand_from export' -l format -x -a 'fish dotenv gpg' -d '导出格式'
complete -c env-vault -n '__fish_seen_subcommand_from export' -l to -r -d '输出到文件'

function __fish_env_vault_list
    env-vault list 2>/dev/null
end
