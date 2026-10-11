# env-vault 的短别名；--wraps 继承 env-vault 的补全。
function ev --wraps env-vault
    env-vault $argv
end
