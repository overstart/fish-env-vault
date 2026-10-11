# env-vault 补全

set -l cmds init set edit get list rm import export passwd path
set -l seen "not __fish_seen_subcommand_from $cmds"

complete -c env-vault -s f -l file -r -d '密钥库路径'
complete -c env-vault -l passphrase -r -d '密码'
complete -c env-vault -s h -l help -d '显示帮助'

complete -c env-vault -f -n "$seen" -a 'init' -d '创建密钥库'
complete -c env-vault -f -n "$seen" -a 'set' -d '新增变量'
complete -c env-vault -f -n "$seen" -a 'edit' -d '修改变量值'
complete -c env-vault -f -n "$seen" -a 'get' -d '查看变量值'
complete -c env-vault -f -n "$seen" -a 'list' -d '列出变量名'
complete -c env-vault -f -n "$seen" -a 'rm' -d '删除变量'
complete -c env-vault -f -n "$seen" -a 'import' -d '从 .env/.fish/.gpg 导入'
complete -c env-vault -f -n "$seen" -a 'export' -d '导出密钥库'
complete -c env-vault -f -n "$seen" -a 'passwd' -d '修改密码'
complete -c env-vault -f -n "$seen" -a 'path' -d '显示密钥库路径'

# 变量名补全（读 .keys 索引，免密）
complete -c env-vault -f -n '__fish_seen_subcommand_from get edit rm' \
    -a '(__fish_env_vault_list)' -d '变量名'

# import 补文件
complete -c env-vault -f -n '__fish_seen_subcommand_from import' \
    -a '(__fish_complete_suffix)'

# 各子命令选项
complete -c env-vault -n '__fish_seen_subcommand_from init' -l force -d '覆盖已有密钥库'
complete -c env-vault -n '__fish_seen_subcommand_from set' -l force -d '覆盖已有变量'
complete -c env-vault -n '__fish_seen_subcommand_from list' -l values -d '连同值一起列出（需密码）'
complete -c env-vault -n '__fish_seen_subcommand_from rm' -l force -d '忽略不存在的变量'
complete -c env-vault -n '__fish_seen_subcommand_from import' -l force -d '覆盖已有变量'
complete -c env-vault -n '__fish_seen_subcommand_from export' -l format -x -a 'fish dotenv gpg' -d '导出格式'
complete -c env-vault -n '__fish_seen_subcommand_from export' -s o -l output -r -d '输出到文件'
complete -c env-vault -n '__fish_seen_subcommand_from passwd' -l new-passphrase -r -d '新密码（脚本化）'

function __fish_env_vault_list
    env-vault list 2>/dev/null | string replace -r '^\d+\t' ''
end

# 注入函数：可选密钥库文件参数
for cmd in env-vault-load env-vault-reload env-vault-unload
    complete -c $cmd -f -a '(__fish_complete_suffix)'
end
