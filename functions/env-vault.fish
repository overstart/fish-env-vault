# env-vault — GPG 对称加密的 fish 环境变量密钥库。
# 本文件既可被 fish 自动加载为 env-vault 命令（fisher 安装 functions/），
# 也可被 bin/env-vault 启动器 source。唯一运行时依赖: fish, gpg。

set -g ENV_VAULT_DEFAULT_FILE "$HOME/.config/fish/secrets/secrets.fish.gpg"

# 告知 gpg-agent 当前终端，pinentry 弹窗才能关联并前置到本窗口；
# 否则 GUI pinentry 无父窗口，常退到后台，切窗口时才看得到。
if not set -q GPG_TTY[1]; and tty >/dev/null 2>&1
    set -gx GPG_TTY (tty)
end

function _vault_die
    echo "env-vault: $argv" >&2
    return 1
end

function _vault_file_path
    if set -q _flag_file[1]
        echo $_flag_file
    else if set -q ENV_VAULT_FILE[1]
        echo $ENV_VAULT_FILE
    else
        echo $ENV_VAULT_DEFAULT_FILE
    end
end

# 密码来源优先级: --passphrase > ENV_VAULT_PASSPHRASE > pinentry。
# 有密码时返回 0，无密码返回 1。
function _vault_has_pass
    set -q _flag_passphrase[1]
    or set -q ENV_VAULT_PASSPHRASE[1]
end

# 解密密钥库到 stdout；失败返回非零。
# 一律 loopback：无密码时 gpg 在当前终端内联提示，不依赖 GUI pinentry。
function _vault_decrypt
    set -l file $argv[1]
    if _vault_has_pass
        set -l pass (set -q _flag_passphrase; and echo $_flag_passphrase; or echo $ENV_VAULT_PASSPHRASE)
        gpg -d --quiet --batch --pinentry-mode loopback \
            --passphrase-file (printf '%s' $pass | psub -f) -- $file 2>/dev/null
    else
        gpg -d --quiet --pinentry-mode loopback -- $file 2>/dev/null
    end
end

# S2K 迭代次数: ENV_VAULT_S2K_COUNT 覆盖，默认 ~3M（约 10ms）。
function _vault_s2k_count
    if set -q ENV_VAULT_S2K_COUNT[1]
        echo $ENV_VAULT_S2K_COUNT
    else
        echo 3145728
    end
end

# 从 stdin 读取明文并加密写入指定文件。
function _vault_encrypt_to
    set -l out $argv[1]
    set -l count (_vault_s2k_count)
    if _vault_has_pass
        set -l pass (set -q _flag_passphrase; and echo $_flag_passphrase; or echo $ENV_VAULT_PASSPHRASE)
        gpg -c --quiet --batch --yes --pinentry-mode loopback \
            --s2k-digest-algo SHA512 --s2k-count $count \
            --passphrase-file (printf '%s' $pass | psub -f) \
            -o $out -- 2>/dev/null
    else
        gpg -c --quiet --yes --pinentry-mode loopback \
            --s2k-digest-algo SHA512 --s2k-count $count \
            -o $out -- 2>/dev/null
    end
end

# 解密密钥库；键名通过物理行扫描写入全局 _vault_keys，值通过 source 设置。
# 不用全局差集：env-vault 子进程会继承父 shell 已导出的同名变量，差集会漏键。
function _vault_load
    set -l file $argv[1]
    set -g _vault_keys
    set -l plain
    _vault_decrypt $file | read -lz plain
    if test $pipestatus[1] -ne 0
        _vault_die "解密失败（密码错误或密钥库损坏）"
        return 1
    end
    for line in (printf '%s\n' $plain)
        if string match -rq '^set\s+-gx\s' -- $line
            set -l name (string replace -r '^set\s+-gx\s+(\S+).*' '$1' -- $line)
            set -ga _vault_keys $name
        end
    end
    printf '%s' $plain | source -
end

# 把密钥库变量渲染为 fish 脚本到 stdout。
# 值始终在管道中流动，不经命令替换（换行不被拆分）。
function _render_fish
    for n in $argv
        printf "set -gx %s '" $n
        printf '%s' $$n | string replace "'" "'\\''"
        printf "'\n"
    end
end

function _render_dotenv
    for n in $argv
        printf '%s=' $n
        set -l v $$n
        if string match -rq "[\n\r#=']" -- $v
            printf "'"
            printf '%s' $v | string replace "'" "'\\''"
            printf "'\n"
        else
            printf '%s\n' $v
        end
    end
end

# 当前作用域中的变量名 + 值全量重写并原子替换密钥库。
function _vault_write
    set -l file $argv[1]
    set -l keys $argv[2..]
    set -l tmp "$file.tmp.(random)"
    begin
        echo '# env-vault managed file — do not edit, use `env-vault`'
        _render_fish $keys
    end | _vault_encrypt_to $tmp
    if test $status -ne 0
        rm -f $tmp
        _vault_die "加密失败，原密钥库未改动"
        return 1
    end
    mv -- $tmp $file
    chmod 600 -- $file
end

function _vault_check_name
    for n in $argv
        string match -rq '^[A-Za-z_][A-Za-z0-9_]*$' -- $n
        or begin
            _vault_die "非法变量名: $n"
            return 1
        end
    end
end

# ------------------------------ 子命令 ------------------------------

function _cmd_init
    argparse 'force' -- $argv
    set -l file (_vault_file_path)
    if test -e $file
        if set -q _flag_force
            echo "警告: 覆盖已有密钥库 $file" >&2
        else
            _vault_die "$file 已存在（--force 覆盖）"
            return 1
        end
    end
    if not set -q _flag_passphrase[1]
        and not set -q ENV_VAULT_PASSPHRASE[1]
        if tty >/dev/null 2>&1
            read -sl -P 'New passphrase: ' p1; echo
            read -sl -P 'Confirm passphrase: ' p2; echo
            test "$p1" = "$p2"; or begin
                _vault_die "两次输入不一致"
                return 1
            end
            test -n "$p1"; or begin
                _vault_die "密码不能为空"
                return 1
            end
            set -g _flag_passphrase $p1
        end
    end
    mkdir -p (dirname $file)
    chmod 700 (dirname $file)
    printf '# env-vault\n' | _vault_encrypt_to $file
    or begin
        _vault_die "初始化失败"
        return 1
    end
    chmod 600 $file
    echo "已创建密钥库: $file"
end

function _cmd_set
    argparse 'force' -- $argv
    set -l name $argv[1]
    _vault_check_name $name; or return 1
    set -l value
    if test (count $argv) -ge 2
        set value $argv[2]
    else if tty >/dev/null 2>&1
        read -sf -P 'Value: ' value
    else
        read -fz value
    end
    set -l file (_vault_file_path)
    test -f $file; or begin
        _vault_die "密钥库不存在，先运行 env-vault init"
        return 1
    end
    _vault_load $file; or return 1
    set -l keys $_vault_keys
    if contains -- $name $keys
        if not set -q _flag_force
            _vault_die "$name 已存在（--force 覆盖）"
            return 1
        end
    else
        set -a keys $name
    end
    set -g $name $value
    _vault_write $file $keys
    echo "已保存 $name"
end

function _cmd_edit
    argparse -- $argv
    set -l name $argv[1]
    _vault_check_name $name; or return 1
    set -l value
    if test (count $argv) -ge 2
        set value $argv[2]
    else if tty >/dev/null 2>&1
        read -sf -P 'Value: ' value
    else
        read -fz value
    end
    set -l file (_vault_file_path)
    _vault_load $file; or return 1
    set -l keys $_vault_keys
    contains -- $name $keys
    or begin
        _vault_die "$name 不存在"
        return 1
    end
    set -g $name $value
    _vault_write $file $keys
    echo "已更新 $name"
end

function _cmd_get
    argparse -- $argv
    set -l name $argv[1]
    set -l file (_vault_file_path)
    _vault_load $file; or return 1
    set -l keys $_vault_keys
    contains -- $name $keys
    or begin
        _vault_die "$name 不存在"
        return 1
    end
    printf '%s\n' $$name
end

function _cmd_list
    argparse 'values' -- $argv
    set -l file (_vault_file_path)
    test -f $file; or return 0
    _vault_load $file; or return 1
    set -l keys $_vault_keys
    for n in $keys
        if set -q _flag_values
            printf "%s='" $n
            printf '%s' $$n | string replace "'" "'\\''"
            printf "'\n"
        else
            echo $n
        end
    end
    return 0
end

function _cmd_rm
    argparse 'force' -- $argv
    set -l targets $argv
    test (count $targets) -ge 1; or begin
        _vault_die "用法: env-vault rm NAME..."
        return 1
    end
    _vault_check_name $targets; or return 1
    set -l file (_vault_file_path)
    _vault_load $file; or return 1
    set -l keys $_vault_keys
    set -l keep
    for n in $keys
        if contains -- $n $targets
            set -e $n
        else
            set -a keep $n
        end
    end
    if not set -q _flag_force
        for t in $targets
            contains -- $t $keys
            or begin
                _vault_die "$t 不存在（--force 忽略）"
                return 1
            end
        end
    end
    _vault_write $file $keep
    echo "已删除: $targets"
end

function _cmd_import
    argparse 'force' -- $argv
    set -l src $argv[1]
    test -f $src; or begin
        _vault_die "文件不存在: $src"
        return 1
    end
    set -l file (_vault_file_path)
    test -f $file; or begin
        _vault_die "密钥库不存在，先运行 env-vault init"
        return 1
    end
    _vault_load $file; or return 1
    set -l keys $_vault_keys
    set -l newkeys
    switch (path extension $src)
        case '.env'
            while read -l line
                switch $line
                    case '' '#' ' #*'
                        continue
                end
                set line (string replace -r '^\s*export\s+' '' -- $line)
                set -l parts (string split -m1 '=' -- $line)
                test (count $parts) -eq 2; or continue
                set -l name (string trim -- $parts[1])
                printf '%s' $parts[2] \
                    | string replace -r "^'" "" \
                    | string replace -r "'\$" "" \
                    | string replace -r '^"' '' \
                    | string replace -r '"$' '' \
                    | string replace -r '\\n' '\n' \
                    | read -fz value
                _vault_check_name $name; or return 1
                if contains -- $name $keys
                    if set -q _flag_force
                        set -g $name $value
                    else
                        echo "跳过已存在: $name" >&2
                    end
                else
                    set -g $name $value
                    set -a keys $name
                    set -a newkeys $name
                end
            end < $src
        case '*'
            # 读取内容（gpg 先解密），扫描 set 语句首行取变量名，再 source 取值。
            set -f content
            if string match -q '*.gpg' -- $src
                _vault_decrypt $src | read -fz content
                test $pipestatus[1] -eq 0; or begin
                    _vault_die "导入文件解密失败"
                    return 1
                end
            else
                read -fz content < $src
            end
            set -f imported
            for line in (printf '%s\n' $content)
                string match -rq '^set\s' -- $line; or continue
                set -a imported (string replace -r '^set\s+(?:-\w+\s+)*(\S+).*' '$1' -- $line)
            end
            printf '%s' $content | source -
            for n in $imported
                _vault_check_name $n; or return 1
                if contains -- $n $keys
                    if not set -q _flag_force
                        echo "跳过已存在: $n" >&2
                        continue
                    end
                else
                    set -a keys $n
                    set -a newkeys $n
                end
            end
    end
    _vault_write $file $keys
    echo "已导入: $newkeys"
end

function _cmd_export
    argparse 'format=' 'to=' -- $argv
    set -q _flag_format; or set _flag_format fish
    set -l file (_vault_file_path)
    _vault_load $file; or return 1
    set -l keys $_vault_keys
    switch $_flag_format
        case gpg
            if set -q _flag_to[1]
                cp -- $file $_flag_to
                chmod 600 $_flag_to
                echo "已备份到 $_flag_to"
                return
            end
            cat $file
            return
        case fish dotenv
        case '*'
            _vault_die "未知格式: $_flag_format（fish|dotenv|gpg）"
            return 1
    end
    if set -q _flag_to[1]
        if test $_flag_format = fish
            _render_fish $keys > $_flag_to
        else
            _render_dotenv $keys > $_flag_to
        end
        chmod 600 $_flag_to
        echo "已导出到 $_flag_to"
    else
        if test $_flag_format = fish
            _render_fish $keys
        else
            _render_dotenv $keys
        end
    end
end

function _cmd_change_passphrase
    argparse 'new-passphrase=' -- $argv
    set -l file (_vault_file_path)
    # 交互时强制当场验证原密码，防止仅凭 ENV_VAULT_PASSPHRASE 或 gpg-agent 缓存直接改密。
    if tty >/dev/null 2>&1
        and not set -q _flag_passphrase[1]
        read -sl -P 'Current passphrase: ' oldpass; echo
        set -g _flag_passphrase $oldpass
    end
    _vault_load $file; or return 1
    set -l keys $_vault_keys
    set -l newpass
    if set -q _flag_new_passphrase[1]
        set newpass $_flag_new_passphrase
    else if set -q ENV_VAULT_NEW_PASSPHRASE[1]
        set newpass $ENV_VAULT_NEW_PASSPHRASE
    else if tty >/dev/null 2>&1
        read -sl -P 'New passphrase: ' p1; echo
        read -sl -P 'Confirm passphrase: ' p2; echo
        test "$p1" = "$p2"; or begin
            _vault_die "两次输入不一致"
            return 1
        end
        test -n "$p1"; or begin
            _vault_die "密码不能为空"
            return 1
        end
        set newpass $p1
    else
        _vault_die "需提供新密码: --new-passphrase 或 ENV_VAULT_NEW_PASSPHRASE"
        return 1
    end
    set -g _flag_passphrase $newpass
    _vault_write $file $keys
    echo "密码已更新"
end

function __vault_help
    printf '%s\n' \
'env-vault — GPG 加密的 fish 环境变量密钥库' \
'' \
'用法: env-vault [--file FILE] [--passphrase PWD] <命令> [参数]' \
'' \
'命令:' \
'  init [--force]                      创建密钥库' \
'  set NAME [VALUE] [--force]          新增变量（无 VALUE 时安全输入）' \
'  edit NAME [VALUE]                   修改已有变量的值' \
'  get NAME                            查看变量值' \
'  list [--values]                     列出变量名（默认不显示值）' \
'  rm NAME... [--force]                删除变量' \
'  import FILE [--force]               从 .env / .fish / .gpg 导入' \
'  export [--format fish|dotenv|gpg] [--to FILE]' \
'  change-passphrase [--new-passphrase PWD]  修改密码（交互时先验证原密码）' \
'  path                                显示密钥库路径' \
'' \
'环境变量:' \
'  ENV_VAULT_FILE          密钥库路径' \
'  ENV_VAULT_PASSPHRASE    密码（脚本化场景）'
end

# 错误用法：帮助信息输出到 stderr 并返回非零。
function _usage
    __vault_help >&2
    return 1
end


# ------------------------------ 主命令 ------------------------------

function env-vault
    set -l cmd_args $argv
    set -e argv
    while test (count $cmd_args) -gt 0
        switch $cmd_args[1]
            case --file --file='*'
                if string match -q -- '--file=*' $cmd_args[1]
                    set -g _flag_file (string replace -- '--file=' '' $cmd_args[1])
                    set -e cmd_args[1]
                else
                    set -g _flag_file $cmd_args[2]
                    set -e cmd_args[1..2]
                end
            case --passphrase --passphrase='*'
                if string match -q -- '--passphrase=*' $cmd_args[1]
                    set -g _flag_passphrase (string replace -- '--passphrase=' '' $cmd_args[1])
                    set -e cmd_args[1]
                else
                    set -g _flag_passphrase $cmd_args[2]
                    set -e cmd_args[1..2]
                end
            case -h --help
                __vault_help
                return 0
            case --
                set -e cmd_args[1]
                break
            case '-*'
                _vault_die "未知全局选项: $cmd_args[1]"
                return 1
            case '*'
                break
        end
        set cmd_args $cmd_args
    end
    test (count $cmd_args) -ge 1
    or begin
        _usage
        return 1
    end
    set -l cmd $cmd_args[1]
    set -e cmd_args[1]
    set argv $cmd_args
    switch $cmd
        case init; _cmd_init $argv
        case set; _cmd_set $argv
        case edit add; _cmd_edit $argv
        case get show; _cmd_get $argv
        case list ls; _cmd_list $argv
        case rm del delete; _cmd_rm $argv
        case import; _cmd_import $argv
        case export; _cmd_export $argv
        case change-passphrase passwd; _cmd_change_passphrase $argv
        case path; _vault_file_path
        case '*'
            _usage
            return 1
    end
end

# 被 bin/env-vault 启动器 source 时不自动执行（函数已定义）；
# fish 自动加载本文件时函数尚未定义，求值后立即以原参数调用。
if not functions -q env-vault
    env-vault $argv
end
