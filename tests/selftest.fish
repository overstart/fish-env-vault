#!/usr/bin/env fish
# env-vault 端到端自检。隔离 GNUPGHOME + 临时密钥库，无任何外部框架。
# 用法: fish tests/selftest.fish

set -g passed 0
set -g failed 0

function check
    set -l desc $argv[1]
    set -l expected $argv[2]
    set -l actual $argv[3]
    if test "$expected" = "$actual"
        set -g passed (math $passed + 1)
    else
        set -g failed (math $failed + 1)
        echo "FAIL: $desc"
        echo "   expected [$expected]"
        echo "   actual   [$actual]"
    end
end

# 成功/失败断言: check_ok <desc> <cmd...>
function check_run
    set -l want $argv[1]
    set -l desc $argv[2]
    $argv[3..] >/dev/null 2>&1
    set -l got (test $status -eq 0; and echo 0; or echo 1)
    check $desc $want $got
end

# ---------- 隔离环境 ----------
set -gx GNUPGHOME (mktemp -d)
chmod 700 $GNUPGHOME
set -gx VAULTDIR (mktemp -d)
set -gx ENV_VAULT_FILE $VAULTDIR/vault.gpg
set -gx ENV_VAULT_PASSPHRASE test-pass
set -l root (status dirname)/..
set -l CLI $root/bin/env-vault
set -l EV $root/bin/ev

# ---------- 默认路径与短别名 ----------
set -l xdgdata (mktemp -d)
check "默认路径遵循 XDG_DATA_HOME" "$xdgdata/env-vault/vault.gpg" \
    (env -u ENV_VAULT_FILE XDG_DATA_HOME=$xdgdata $CLI path)
check "短别名 ev 可用" 0 (env -u ENV_VAULT_FILE XDG_DATA_HOME=$xdgdata $EV path >/dev/null; and echo 0; or echo 1)
check_run 1 "未知命令失败" $CLI bogus
check_run 1 "未知选项失败" $CLI --bogus list

# ---------- init ----------
check_run 0 "init 成功" $CLI init
check "密钥库已创建" 1 (test -f $ENV_VAULT_FILE; and echo 1; or echo 0)
check "权限 600" 600 (stat -c %a $ENV_VAULT_FILE)
check_run 1 "重复 init 失败" $CLI init
check_run 0 "init --force 成功" $CLI init --force

# ---------- set / get ----------
check_run 0 "set FOO" $CLI set FOO bar
check "get FOO" bar ($CLI get FOO)
check_run 1 "set 已存在失败" $CLI set FOO x
check_run 0 "set --force 覆盖" $CLI set --force FOO new
check "get 覆盖值" new ($CLI get FOO)
check_run 1 "set 非法名" $CLI set 1BAD v
check_run 1 "get 不存在" $CLI get NOPE

# 特殊字符 / 多行字节往返（read 承接，不经命令替换以免换行被拆分）
set -l weird "a'b\$c
d\\e	f"
printf '%s' $weird | $CLI set WEIRD >/dev/null 2>&1
set -l gotweird
$CLI get WEIRD | read -fz gotweird
check "特殊字符字节往返(get=值+换行)" "$weird
" $gotweird

# ---------- edit ----------
check_run 0 "edit FOO" $CLI edit FOO edited
check "get edit 值" edited ($CLI get FOO)
check_run 1 "edit 不存在失败" $CLI edit NOPE x

# ---------- list ----------
set -l names ($CLI list)
check "list 含 FOO" FOO (contains FOO $names; and echo FOO)
check "list 含 WEIRD" WEIRD (contains WEIRD $names; and echo WEIRD)
set -l onlynames ($CLI list)
check "list 默认无值" 0 (count (string match -r 'edited|bar|new' -- $onlynames))
set -l withvals ($CLI list --values)
check "list --values 含值" 1 (string match -rq 'FOO=.*edited' -- $withvals; and echo 1; or echo 0)
# list 免密：伪造 gpg 必失败 + 清空密码，仍应能列出 key；--values 必须解密
set -l fakebin (mktemp -d)
printf '#!/bin/sh\necho SHOULD-NOT-CALL-GPG >&2\nexit 99\n' > $fakebin/gpg; chmod +x $fakebin/gpg
function __nopf
    set -lx PATH $fakebin $PATH
    env -u ENV_VAULT_PASSPHRASE $argv
end
set -l nokeynames (__nopf $CLI list)
check "list 无密码含 FOO" FOO (contains FOO $nokeynames; and echo FOO)
check "list 无密码含 WEIRD" WEIRD (contains WEIRD $nokeynames; and echo WEIRD)
check_run 1 "list --values 必须解密" __nopf $CLI list --values
functions -e __nopf
rm -rf $fakebin 2>/dev/null

# ---------- rm ----------
check_run 0 "rm FOO" $CLI rm FOO
check "rm 后不含 FOO" 0 (contains FOO ($CLI list); and echo 1; or echo 0)
check_run 1 "rm 不存在失败" $CLI rm FOO
check_run 0 "rm --force 忽略" $CLI rm --force FOO
check_run 0 "rm WEIRD" $CLI rm WEIRD
check "空库 list" 0 (count ($CLI list))
check_run 0 "空库后可再 set" $CLI set LATER v

# ---------- import ----------
printf 'IM_A=x\nexport IM_B=y\n# c\n\n' > $VAULTDIR/in.env
check_run 0 "import dotenv" $CLI import $VAULTDIR/in.env
check "import IM_A" x ($CLI get IM_A)
check "import IM_B" y ($CLI get IM_B)
check_run 0 "import 冲突跳过(退出0)" $CLI import $VAULTDIR/in.env
check "冲突时值未变" x ($CLI get IM_A)
check_run 0 "import --force 覆盖" $CLI import --force $VAULTDIR/in.env

printf "set -gx IM_C 'hello'\n" > $VAULTDIR/in.fish
check_run 0 "import fish" $CLI import $VAULTDIR/in.fish
check "import IM_C" hello ($CLI get IM_C)

$CLI export --format gpg -o $VAULTDIR/in.gpg >/dev/null
check_run 0 "import gpg" $CLI import --force $VAULTDIR/in.gpg

# ---------- export ----------
$CLI export --format fish > $VAULTDIR/out.fish
check_run 0 "export fish 可 source" fish $VAULTDIR/out.fish
set -l dotout ($CLI export --format dotenv)
check "export dotenv 含键" 1 (string match -rq 'IM_A=x' -- $dotout; and echo 1; or echo 0)
check_run 0 "export gpg 到文件" $CLI export --format gpg -o $VAULTDIR/bak.gpg
check "gpg 备份可解密" x ($CLI --passphrase test-pass get IM_A)
check_run 0 "-f 短选项等价 --file" $CLI -f $VAULTDIR/bak.gpg --passphrase test-pass list --values

# ---------- passwd ----------
set -gx ENV_VAULT_NEW_PASSPHRASE new-pass
check_run 0 "改密" $CLI passwd
set -gx ENV_VAULT_PASSPHRASE new-pass
check "新密码可读" x ($CLI get IM_A)
check_run 1 "错误原密码改密被拒" $CLI --passphrase wrong passwd --new-passphrase x
check "被拒后现密码仍有效" x ($CLI get IM_A)
set -gx ENV_VAULT_PASSPHRASE test-pass
check_run 1 "旧密码失效" $CLI list --values
check_run 1 "旧命令名 change-passphrase 已移除" $CLI change-passphrase
check_run 1 "旧参数 --to 已移除" $CLI export --format gpg --to $VAULTDIR/x.gpg

# ---------- 插件函数 ----------
set -gx PATH (dirname $CLI) $PATH
set -gx ENV_VAULT_PASSPHRASE new-pass
for f in $root/functions/*.fish
    source $f
end
check_run 0 "env-vault-load" env-vault-load
check "load 后变量可见" x $IM_A
check_run 0 "env-vault-reload" env-vault-reload
check "reload 后变量可见" y $IM_B
env-vault-unload
check "unload 后变量消失" 0 (set -q IM_A; and echo 1; or echo 0)
check_run 0 "再次 load" env-vault-load

# CLI 以函数方式运行在当前 shell（fisher 模型）后，解密出的密钥变量不得残留在调用 shell
env-vault --passphrase new-pass get IM_A >/dev/null 2>&1
check "函数模式 get 后密钥不残留" 0 (set -q IM_A; and echo 1; or echo 0)
check "函数模式 _vault_keys 不残留" 0 (set -q _vault_keys[1]; and echo 1; or echo 0)

# ---------- 全局状态不泄漏（fisher 把 env-vault 装进持久 shell，set -g 状态不得跨命令残留）----------
# 预置脏状态：残留密码/路径必须在命令入口被清掉，否则会用错文件或跳过改密验证。
set -g _flag_passphrase stale-pass
set -g _flag_file /nonexistent/stale-vault
check_run 0 "脏路径被忽略、本次命令仍成功" env-vault --passphrase new-pass list --values
check "密码不残留 _flag_passphrase" 0 (set -q _flag_passphrase[1]; and echo 1; or echo 0)
check "路径不残留 _flag_file" 0 (set -q _flag_file[1]; and echo 1; or echo 0)
check "键名不残留 _vault_keys" 0 (set -q _vault_keys[1]; and echo 1; or echo 0)

# ---------- 汇总 ----------
echo "----------------------------------------"
echo "通过 $passed，失败 $failed"
rm -rf $GNUPGHOME $VAULTDIR
test $failed -eq 0
