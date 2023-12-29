#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Add some basic function here
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}

# check root
[[ $EUID -ne 0 ]] && LOGE "错误：您必须是 root 才能运行此脚本！\n" && exit 1

# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "检查系统操作系统失败，请联系作者！" >&2
    exit 1
fi

echo "操作系统版本是: $release"

os_version=""
os_version=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)

if [[ "${release}" == "centos" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用CentOS 8或更高版本 ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "ubuntu" ]]; then
    if [[ ${os_version} -lt 20 ]]; then
        echo -e "${red}请使用Ubuntu 20或更高版本！ ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "fedora" ]]; then
    if [[ ${os_version} -lt 36 ]]; then
        echo -e "${red}请使用Fedora 36或更高版本！ ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "debian" ]]; then
    if [[ ${os_version} -lt 10 ]]; then
        echo -e "${red} 请使用 Debian 10 或更高版本${plain}\n" && exit 1
    fi
elif [[ "${release}" == "almalinux" ]]; then
    if [[ ${os_version} -lt 9 ]]; then
        echo -e "${red} 请使用Almalinux 9或更高版本 ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "arch" ]]; then
    echo "操作系统:ArchLinux"
elif [[ "${release}" == "manjaro" ]]; then
    echo "操作系统:Manjaro"
elif [[ "${release}" == "armbian" ]]; then
    echo "操作系统:Armbian"
fi


# Declare Variables
log_folder="${XUI_LOG_FOLDER:=/var/log}"
iplimit_log_path="${log_folder}/3xipl.log"
iplimit_banned_log_path="${log_folder}/3xipl-banned.log"


confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [Default $2]: " temp
        if [[ "${temp}" == "" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ "${temp}" == "y" || "${temp}" == "Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Restart the panel, Attention: Restarting the panel will also restart xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}按 Enter 键返回主菜单：${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/xxf185/3x-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "该功能将强制重新安装最新版本，并且数据不会丢失。 你想继续吗?" "n"
    if [[ $? != 0 ]]; then
        LOGE "取消"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/xxf185/3x-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        LOGI "更新完成，面板已自动重启 "
        exit 0
    fi
}

custom_version() {
    echo "输入面板版本（如2.0.0）："
    read panel_version

    if [ -z "$panel_version" ]; then
        echo "面板版本不能为空。 退出。"
    exit 1
    fi

    download_link="https://raw.githubusercontent.com/xxf185/3x-ui/master/install.sh"

    # Use the entered panel version in the download link
    install_command="bash <(curl -Ls $download_link) v$panel_version"

    echo "下载并安装面板版本$panel_version..."
    eval $install_command
}

uninstall() {
    confirm "您确定要卸载面板吗？xray也将被卸载!" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf

    echo ""
    echo -e "卸载成功，如果要删除此脚本，则退出脚本后运行${green}rm /usr/bin/x-ui -f${plain} 删除它。"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "您确定重置面板的用户名和密码吗?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    read -rp "请设置登录用户名【默认为随机用户名】: " config_account
    [[ -z $config_account ]] && config_account=$(date +%s%N | md5sum | cut -c 1-8)
    read -rp "请设置登录密码【默认为随机密码】: " config_password
    [[ -z $config_password ]] && config_password=$(date +%s%N | md5sum | cut -c 1-8)
    /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password} >/dev/null 2>&1
    /usr/local/x-ui/x-ui setting -remove_secret >/dev/null 2>&1
    echo -e "面板登录用户名已重置为: ${green} ${config_account} ${plain}"
    echo -e "面板登录密码已重置为: ${green} ${config_password} ${plain}"
    echo -e "${yellow} 面板登录密码已禁用${plain}"
    echo -e "${green} 请使用新的登录用户名和密码访问X-UI面板。 也记住他们! ${plain}"
    confirm_restart
}

reset_config() {
    confirm "您确定要重置所有面板设置，帐户数据不会丢失，用户名和密码不会更改" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "所有面板设置已重置为默认值，请立即重新启动面板，并使用默认 ${green}2053${plain}访问Web面板的端口"
    confirm_restart
}

check_config() {
    info=$(/usr/local/x-ui/x-ui setting -show true)
    if [[ $? != 0 ]]; then
        LOGE "设置错误，请检查日志"
        show_menu
    fi
    LOGI "${info}"
}

set_port() {
    echo && echo -n -e "输入端口号[1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        LOGD "取消"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "端口已设置，请立即重启面板，并使用新端口 ${green}${port}${plain} 访问网页面板"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        LOGI "面板正在运行，无需再次启动，如需重新启动，请选择重新启动"
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            LOGI "x-ui启动成功"
        else
            LOGE "面板启动失败，可能是启动时间超过两秒，请稍后查看日志信息"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        LOGI "面板已停止"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            LOGI "x-ui 和 xray 成功停止"
        else
            LOGE "面板停止失败，可能是停止时间超过两秒，请稍后查看日志信息"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        LOGI "x-ui 和 xray 重新启动成功"
    else
        LOGE "面板重启失败，可能是启动时间超过两秒，请稍后查看日志信息"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui 设置启动成功后自动启动"
    else
        LOGE "x-ui 设置自动启动失败"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui 自动启动已成功取消"
    else
        LOGE "x-ui 取消自动启动失败"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_banlog() {
  if test -f "${iplimit_banned_log_path}"; then
    if [[ -s "${iplimit_banned_log_path}" ]]; then
      cat ${iplimit_banned_log_path}
    else
      echo -e "${red}日志文件为空。${plain}\n"  
    fi
  else
    echo -e "${red}未找到日志文件。 请先安装 Fail2ban 和 IP Limit。${plain}\n"
  fi
}

enable_bbr() {
    if grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf && grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
        echo -e "${green}BBR 已启用！${plain}"
        exit 0
    fi

    # Check the OS and install necessary packages
    case "${release}" in
        ubuntu|debian)
            apt-get update && apt-get install -yqq --no-install-recommends ca-certificates
            ;;
        centos)
            yum -y update && yum -y install ca-certificates
            ;;
        fedora)
            dnf -y update && dnf -y install ca-certificates
            ;;
        *)
            echo -e "${red}不支持的操作系统。 请检查脚本并手动安装必要的软件包。${plain}\n"
            exit 1
            ;;
    esac

    # Enable BBR
    echo "net.core.default_qdisc=fq" | tee -a /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" | tee -a /etc/sysctl.conf

    # Apply changes
    sysctl -p

    # Verify that BBR is enabled
    if [[ $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}') == "bbr" ]]; then
        echo -e "${green}BBR已成功启用。${plain}"
    else
        echo -e "${red}启用 BBR 失败。 请检查您的系统配置。${plain}"
    fi
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://github.com/xxf185/3x-ui/raw/master/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        LOGE "下载脚本失败，请检查是否可以连接Github"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        LOGI "更新脚本成功，请重新运行脚本" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ "${temp}" == "running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ "${temp}" == "enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        LOGE "面板已安装，请勿重新安装"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        LOGE "请先安装面板"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
    0)
        echo -e "面板状态：${green}运行${plain}"
        show_enable_status
        ;;
    1)
        echo -e "面板状态: ${yellow}未运行${plain}"
        show_enable_status
        ;;
    2)
        echo -e "面板状态: ${red}未安装${plain}"
        ;;
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "自动启动: ${green}Yes${plain}"
    else
        echo -e "自动启动: ${red}No${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray状态: ${green}运行${plain}"
    else
        echo -e "xray状态: ${red}未运行${plain}"
    fi
}

open_ports() {
    if ! command -v ufw &>/dev/null; then
        echo "ufw防火墙未安装。 正在安装..."
        apt-get update
        apt-get install -y ufw
    else
        echo "ufw防火墙已经安装"
    fi

    # Check if the firewall is inactive
    if ufw status | grep -q "Status: active"; then
        echo "防火墙已经开启"
    else
        # Open the necessary ports
        ufw allow ssh
        ufw allow http
        ufw allow https
        ufw allow 2053/tcp

        # Enable the firewall
        ufw --force enable
    fi

    # Prompt the user to enter a list of ports
    read -p "输入您要打开的端口（例如 80,443,2053 或范围 400-500）：" ports

    # Check if the input is valid
    if ! [[ $ports =~ ^([0-9]+|[0-9]+-[0-9]+)(,([0-9]+|[0-9]+-[0-9]+))*$ ]]; then
        echo "错误：输入无效。 请输入以逗号分隔的端口列表或端口范围（例如 80,443,2053 或 400-500）。" >&2
        exit 1
    fi

    # Open the specified ports using ufw
    IFS=',' read -ra PORT_LIST <<<"$ports"
    for port in "${PORT_LIST[@]}"; do
        if [[ $port == *-* ]]; then
            # Split the range into start and end ports
            start_port=$(echo $port | cut -d'-' -f1)
            end_port=$(echo $port | cut -d'-' -f2)
            # Loop through the range and open each port
            for ((i = start_port; i <= end_port; i++)); do
                ufw allow $i
            done
        else
            ufw allow "$port"
        fi
    done

    # Confirm that the ports are open
    ufw status | grep $ports
}

update_geo() {
    local defaultBinFolder="/usr/local/x-ui/bin"
    read -p "请输入 x-ui bin 文件夹路径。 默认留空。(默认: '${defaultBinFolder}')" binFolder
    binFolder=${binFolder:-${defaultBinFolder}}
    if [[ ! -d ${binFolder} ]]; then
        LOGE "文件夹 ${binFolder} 不存在！"
        LOGI "新建 bin 文件夹：${binFolder}..."
        mkdir -p ${binFolder}
    fi

    systemctl stop x-ui
    cd ${binFolder}
    rm -f geoip.dat geosite.dat geoip_IR.dat geosite_IR.dat geoip_VN.dat geosite_VN.dat
    wget -N https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
    wget -N https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
    wget -O geoip_IR.dat -N https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/geoip.dat
    wget -O geosite_IR.dat -N https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/geosite.dat
    wget -O geoip_VN.dat https://github.com/vuong2023/vn-v2ray-rules/releases/latest/download/geoip.dat
    wget -O geosite_VN.dat https://github.com/vuong2023/vn-v2ray-rules/releases/latest/download/geosite.dat
    systemctl start x-ui
    echo -e "${green}Geosite.dat + Geoip.dat + geoip_IR.dat + geosite_IR.dat have been updated successfully in bin folder '${binfolder}'!${plain}"
    before_show_menu
}

install_acme() {
    cd ~
    LOGI "安装acme..."
    curl https://get.acme.sh | sh
    if [ $? -ne 0 ]; then
        LOGE "安装 acme 失败"
        return 1
    else
        LOGI "安装acme成功"
    fi
    return 0
}

ssl_cert_issue_main() {
    echo -e "${green}\t1.${plain} 获取证书"
    echo -e "${green}\t2.${plain} 删除证书"
    echo -e "${green}\t3.${plain} 更新证书"
    echo -e "${green}\t0.${plain} 返回主菜单"
    read -p "选择: " choice
    case "$choice" in
        0)
            show_menu ;;
        1) 
            ssl_cert_issue ;;
        2) 
            local domain=""
            read -p "请输入您的域名以删除证书：" domain
            ~/.acme.sh/acme.sh --revoke -d ${domain}
            LOGI "证书已删除"
            ;;
        3)
            local domain=""
            read -p "请输入您的域名以更新SSL 证书: " domain
            ~/.acme.sh/acme.sh --renew -d ${domain} --force ;;
        *) echo "选择无效" ;;
    esac
}

ssl_cert_issue() {
    # check for acme.sh first
    if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
        echo "acme.sh 未找到.安装中"
        install_acme
        if [ $? -ne 0 ]; then
            LOGE "安装acme失败，请检查日志"
            exit 1
        fi
    fi
    # install socat second
    case "${release}" in
        ubuntu|debian|armbian)
            apt update && apt install socat -y ;;
        centos)
            yum -y update && yum -y install socat ;;
        fedora)
            dnf -y update && dnf -y install socat ;;
        *)
            echo -e "${red}不支持的操作系统。 请检查脚本并手动安装必要的软件包。${plain}\n"
            exit 1 ;;
    esac
    if [ $? -ne 0 ]; then
        LOGE "安装socat失败，请检查日志"
        exit 1
    else
        LOGI "安装socat成功..."
    fi

    # get the domain here,and we need verify it
    local domain=""
    read -p "请输入您的域名：" domain
    LOGD "您的域名:${domain},check it..."
    # here we need to judge whether there exists cert already
    local currentCert=$(~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}')

    if [ ${currentCert} == ${domain} ]; then
        local certInfo=$(~/.acme.sh/acme.sh --list)
        LOGE "系统已经有证书，无法再次颁发，当前证书详细信息:"
        LOGI "$certInfo"
        exit 1
    else
        LOGI "您的域名现在已准备好颁发证书..."
    fi

    # create a directory for install cert
    certPath="/root/cert/${domain}"
    if [ ! -d "$certPath" ]; then
        mkdir -p "$certPath"
    else
        rm -rf "$certPath"
        mkdir -p "$certPath"
    fi

    # get needed port here
    local WebPort=80
    read -p "请选择端口，默认为 80 端口：" WebPort
    if [[ ${WebPort} -gt 65535 || ${WebPort} -lt 1 ]]; then
        LOGE "您输入的 ${WebPort} 无效，将使用默认端口"
    fi
    LOGI "将使用端口：${WebPort} 来颁发证书，请确保此端口已开放"
    # NOTE:This should be handled by user
    # open the port and kill the occupied progress
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --issue -d ${domain} --standalone --httpport ${WebPort}
    if [ $? -ne 0 ]; then
        LOGE "颁发证书失败，请检查日志"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        LOGE "颁发证书成功，正在安装证书..."
    fi
    # install cert
    ~/.acme.sh/acme.sh --installcert -d ${domain} \
        --key-file /root/cert/${domain}/privkey.pem \
        --fullchain-file /root/cert/${domain}/fullchain.pem

    if [ $? -ne 0 ]; then
        LOGE "安装证书失败，退出"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        LOGI "安装证书成功，启用自动更新"
    fi

    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        LOGE "自动更新失败，证书详细信息:"
        ls -lah cert/*
        chmod 755 $certPath/*
        exit 1
    else
        LOGI "自动更新成功，证书详细信息:"
        ls -lah cert/*
        chmod 755 $certPath/*
    fi
}

ssl_cert_issue_CF() {
    echo -E ""
    LOGD "******使用说明******"
    LOGI "该脚本将使用Acme脚本申请证书,使用时需保证:"
    LOGI "1.知晓Cloudflare 注册邮箱"
    LOGI "2.知晓Cloudflare Global API Key"
    LOGI "3.域名已通过Cloudflare进行解析到当前服务器"
    LOGI "4.该脚本申请证书默认安装路径为/root/cert目录"
    confirm "我已确认以上内容[y/n]" "y"
    if [ $? -eq 0 ]; then
        # check for acme.sh first
        if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
            echo "acme安装中"
            install_acme
            if [ $? -ne 0 ]; then
                LOGE "安装acme失败，请检查日志"
                exit 1
            fi
        fi
        CF_Domain=""
        CF_GlobalKey=""
        CF_AccountEmail=""
        certPath=/root/cert
        if [ ! -d "$certPath" ]; then
            mkdir $certPath
        else
            rm -rf $certPath
            mkdir $certPath
        fi
        LOGD "请设置域名:"
        read -p "Input your domain here:" CF_Domain
        LOGD "你的域名设置为:${CF_Domain}"
        LOGD "请设置API密钥:"
        read -p "Input your key here:" CF_GlobalKey
        LOGD "你的API密钥为:${CF_GlobalKey}"
        LOGD "请设置注册邮箱:"
        read -p "Input your email here:" CF_AccountEmail
        LOGD "你的注册邮箱为:${CF_AccountEmail}"
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE "修改默认CA为Lets'Encrypt失败,脚本退出"
            exit 1
        fi
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
        if [ $? -ne 0 ]; then
            LOGE "证书签发失败,脚本退出."
            exit 1
        else
            LOGI "证书签发成功,安装中..."
        fi
        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
        --fullchain-file /root/cert/fullchain.cer
        if [ $? -ne 0 ]; then
            LOGE "证书安装失败,脚本退出"
            exit 1
        else
            LOGI "证书安装成功,开启自动更新..."
        fi
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
        if [ $? -ne 0 ]; then
            LOGE "自动更新设置失败,脚本退出"
            ls -lah cert
            chmod 755 $certPath
            exit 1
        else
            LOGI "证书已安装且已开启自动更新,具体信息如下"
            ls -lah cert
            chmod 755 $certPath
        fi
    else
        show_menu
    fi
}

warp_cloudflare() {
    echo -e "${green}\t1.${plain} 安装 WARPocks5 代理"
    echo -e "${green}\t2.${plain} 帐户类型（免费、附加、团队）"
    echo -e "${green}\t3.${plain} 打开/关闭 WireProxy"
    echo -e "${green}\t4.${plain} 卸载WARP"
    echo -e "${green}\t0.${plain} 返回主菜单"
    read -p "选择：" choice
    case "$choice" in
        0)
            show_menu ;;
        1) 
            bash <(curl -sSL https://raw.githubusercontent.com/hamid-gh98/x-ui-scripts/main/install_warp_proxy.sh)
            ;;
        2) 
            warp a
            ;;
        3)
            warp y
            ;;
        4)
            warp u
            ;;
        *) echo "Invalid choice" ;;
    esac
}

run_speedtest() {
    # Check if Speedtest is already installed
    if ! command -v speedtest &> /dev/null; then
        # If not installed, install it
        local pkg_manager=""
        local speedtest_install_script=""
        
        if command -v dnf &> /dev/null; then
            pkg_manager="dnf"
            speedtest_install_script="https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh"
        elif command -v yum &> /dev/null; then
            pkg_manager="yum"
            speedtest_install_script="https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh"
        elif command -v apt-get &> /dev/null; then
            pkg_manager="apt-get"
            speedtest_install_script="https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh"
        elif command -v apt &> /dev/null; then
            pkg_manager="apt"
            speedtest_install_script="https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh"
        fi
        
        if [[ -z $pkg_manager ]]; then
            echo "错误：找不到包管理器。 您可能需要手动安装 Speedtest。"
            return 1
        else
            curl -s $speedtest_install_script | bash
            $pkg_manager install -y speedtest
        fi
    fi

    # Run Speedtest
    speedtest
}

create_iplimit_jails() {
    # Use default bantime if not passed => 5 minutes
    local bantime="${1:-5}"

    cat << EOF > /etc/fail2ban/jail.d/3x-ipl.conf
[3x-ipl]
enabled=true
filter=3x-ipl
action=3x-ipl
logpath=${iplimit_log_path}
maxretry=4
findtime=60
bantime=${bantime}m
EOF

    cat << EOF > /etc/fail2ban/filter.d/3x-ipl.conf
[Definition]
datepattern = ^%%Y/%%m/%%d %%H:%%M:%%S
failregex   = \[LIMIT_IP\]\s*Email\s*=\s*<F-USER>.+</F-USER>\s*\|\|\s*SRC\s*=\s*<ADDR>
ignoreregex =
EOF

    cat << EOF > /etc/fail2ban/action.d/3x-ipl.conf
[INCLUDES]
before = iptables-common.conf

[Definition]
actionstart = <iptables> -N f2b-<name>
              <iptables> -A f2b-<name> -j <returntype>
              <iptables> -I <chain> -p <protocol> -j f2b-<name>

actionstop = <iptables> -D <chain> -p <protocol> -j f2b-<name>
             <actionflush>
             <iptables> -X f2b-<name>

actioncheck = <iptables> -n -L <chain> | grep -q 'f2b-<name>[ \t]'

actionban = <iptables> -I f2b-<name> 1 -s <ip> -j <blocktype>
            echo "\$(date +"%%Y/%%m/%%d %%H:%%M:%%S")   BAN   [Email] = <F-USER> [IP] = <ip> banned for <bantime> seconds." >> ${iplimit_banned_log_path}

actionunban = <iptables> -D f2b-<name> -s <ip> -j <blocktype>
              echo "\$(date +"%%Y/%%m/%%d %%H:%%M:%%S")   UNBAN   [Email] = <F-USER> [IP] = <ip> unbanned." >> ${iplimit_banned_log_path}

[Init]
EOF

    echo -e "${green}Created Ip Limit jail files with a bantime of ${bantime} minutes.${plain}"
}

iplimit_remove_conflicts() {
    local jail_files=(
        /etc/fail2ban/jail.conf
        /etc/fail2ban/jail.local
    )

    for file in "${jail_files[@]}"; do
        # Check for [3x-ipl] config in jail file then remove it
        if test -f "${file}" && grep -qw '3x-ipl' ${file}; then
            sed -i "/\[3x-ipl\]/,/^$/d" ${file}
            echo -e "${yellow}Removing conflicts of [3x-ipl] in jail (${file})!${plain}\n"
        fi
    done
}

iplimit_main() {
    echo -e "\n${green}\t1.${plain} 安装Fail2ban和IP限制"
    echo -e "${green}\t2.${plain} 更改限制期限"
    echo -e "${green}\t3.${plain} 幸运数字图片"
    echo -e "${green}\t4.${plain} 查看日志"
    echo -e "${green}\t5.${plain} fail2ban状态"
    echo -e "${green}\t6.${plain} 解除IP限制"
    echo -e "${green}\t0.${plain} 返回主菜单"
    read -p "选择 " choice
    case "$choice" in
        0)
            show_menu ;;
        1)
            confirm "安装 Fail2ban 和 IP 限制?" "y"
            if [[ $? == 0 ]]; then
                install_iplimit
            else
                iplimit_main
            fi ;;
        2)
            read -rp "请输入新的限制持续时间（以分钟为单位）[默认 5]: " NUM
            if [[ $NUM =~ ^[0-9]+$ ]]; then
                create_iplimit_jails ${NUM}
                systemctl restart fail2ban
            else
                echo -e "${red}${NUM} 不是一个数字！ 请再试一次。${plain}"
            fi
            iplimit_main ;;
        3)
            confirm "解除所有人的 IP 限制" "y"
            if [[ $? == 0 ]]; then
                fail2ban-client reload --restart --unban 3x-ipl
                echo -e "${green}所有用户已成功解除${plain}"
                iplimit_main
            else
                echo -e "${yellow}取消。${plain}"
            fi
            iplimit_main ;;
        4)
            show_banlog
            ;;
        5)
            service fail2ban status
            ;;

        6)
            remove_iplimit ;;
        *) echo "Invalid choice" ;;
    esac
}

install_iplimit() {
    if ! command -v fail2ban-client &>/dev/null; then
        echo -e "${green}未安装 Fail2ban。 正在安装...!${plain}\n"
        # Check the OS and install necessary packages
        case "${release}" in
            ubuntu|debian)
                apt update && apt install fail2ban -y ;;
            centos)
                yum -y update && yum -y install fail2ban ;;
            fedora)
                dnf -y update && dnf -y install fail2ban ;;
            *)
                echo -e "${red}不支持的操作系统。 请检查脚本并手动安装必要的软件包.${plain}\n"
                exit 1 ;;
        esac
        echo -e "${green}Fail2ban安装成功!${plain}\n"
    else
        echo -e "${yellow}Fail2ban 已安装。${plain}\n"
    fi

    echo -e "${green}配置 IP 限制...${plain}\n"

    # make sure there's no conflict for jail files
    iplimit_remove_conflicts

    # Check if log file exists
    if ! test -f "${iplimit_banned_log_path}"; then
        touch ${iplimit_banned_log_path}
    fi

    # Check if service log file exists so fail2ban won't return error
    if ! test -f "${iplimit_log_path}"; then
        touch ${iplimit_log_path}
    fi

    # Create the iplimit jail files
    # we didn't pass the bantime here to use the default value
    create_iplimit_jails

    # Launching fail2ban
    if ! systemctl is-active --quiet fail2ban; then
        systemctl start fail2ban
    else
        systemctl restart fail2ban
    fi
    systemctl enable fail2ban

    echo -e "${green}IP 限制安装并配置成功!${plain}\n"
    before_show_menu
}

remove_iplimit(){
    echo -e "${green}\t1.${plain} 仅删除 IP 限制配置"
    echo -e "${green}\t2.${plain} 卸载 Fail2ban 和 IP 限制"
    echo -e "${green}\t0.${plain} 中止"
    read -p "选择: " num
    case "$num" in
        1) 
            rm -f /etc/fail2ban/filter.d/3x-ipl.conf
            rm -f /etc/fail2ban/action.d/3x-ipl.conf
            rm -f /etc/fail2ban/jail.d/3x-ipl.conf
            systemctl restart fail2ban
            echo -e "${green}IP限制成功解除!${plain}\n"
            before_show_menu ;;
        2)  
            rm -rf /etc/fail2ban
            systemctl stop fail2ban
            case "${release}" in
                ubuntu|debian)
                    apt-get purge fail2ban -y;;
                centos)
                    yum remove fail2ban -y;;
                fedora)
                    dnf remove fail2ban -y;;
                *)
                    echo -e "${red}不支持的操作系统。 请手动卸载 Fail2ban。${plain}\n"
                    exit 1 ;;
            esac
            echo -e "${green}Fail2ban 和 IP 限制删除成功！${plain}\n"
            before_show_menu ;;
        0) 
            echo -e "${yellow}取消。${plain}\n"
            iplimit_main ;;
        *) 
            echo -e "${red}选择错误${plain}\n"
            remove_iplimit ;;
    esac
}

show_usage() {
    echo "x-ui 管理脚本使用方法: "
    echo "------------------------------------------"
    echo -e "x-ui              - 显示管理菜单 (功能更多)"
    echo -e "x-ui start        - 启动 x-ui 面板"
    echo -e "x-ui stop         - 停止 x-ui 面板"
    echo -e "x-ui restart      - 重启 x-ui 面板"
    echo -e "x-ui status       - 查看 x-ui 状态"
    echo -e "x-ui enable       - 设置 x-ui 开机自启"
    echo -e "x-ui disable      - 取消 x-ui 开机自启"
    echo -e "x-ui log          - 查看 x-ui 日志"
    echo -e "x-ui banlog       - 查看 Fail2ban 日志"
    echo -e "x-ui update       - 更新 x-ui 面板"
    echo -e "x-ui install      - 安装 x-ui 面板"
    echo -e "x-ui uninstall    - 卸载 x-ui 面板"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}3x-ui 面板管理脚本${plain}
  ${green}0.${plain} 退出脚本
————————————————
  ${green}1.${plain} 安装 x-ui
  ${green}2.${plain} 更新 x-ui
  ${green}3.${plain} 定制版本
  ${green}4.${plain} 卸载 x-ui
————————————————
  ${green}5.${plain} 重置用户名密码
  ${green}6.${plain} 重置面板设置
  ${green}7.${plain} 设置面板端口
  ${green}8.${plain} 查看当前面板设置
————————————————
  ${green}9.${plain} 启动 x-ui
  ${green}10.${plain} 停止 x-ui
  ${green}11.${plain} 重启 x-ui
  ${green}12.${plain} 查看 x-ui 状态
  ${green}13.${plain} 查看 x-ui 日志
————————————————
  ${green}14.${plain} 设置 x-ui 开机自启
  ${green}15.${plain} 取消 x-ui 开机自启
————————————————
  ${green}16.${plain} SSL证书管理
  ${green}17.${plain} Cloudflare SSL 证书
  ${green}18.${plain} IP限制管理
  ${green}19.${plain} WARP 管理
————————————————
  ${green}20.${plain} 一键安装 bbr (最新内核)
  ${green}21.${plain} 更新Geo文件
  ${green}22.${plain} 防火墙管理
  ${green}23.${plain} 速度测试
"
    show_status
    echo && read -p "选择 [0-23]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && custom_version
        ;;
    4)
        check_install && uninstall
        ;;
    5)
        check_install && reset_user
        ;;
    6)
        check_install && reset_config
        ;;
    7)
        check_install && set_port
        ;;
    8)
        check_install && check_config
        ;;
    9)
        check_install && start
        ;;
    10)
        check_install && stop
        ;;
    11)
        check_install && restart
        ;;
    12)
        check_install && status
        ;;
    13)
        check_install && show_log
        ;;
    14)
        check_install && enable
        ;;
    15)
        check_install && disable
        ;;
    16)
        ssl_cert_issue_main
        ;;
    17)
        ssl_cert_issue_CF
        ;;
    18)
        iplimit_main
        ;;
    19)
        warp_cloudflare
        ;;
    20)
        enable_bbr
        ;;
    21)
        update_geo
        ;;
    22)
        open_ports
        ;;
    23)
        run_speedtest
        ;;    
    *)
        LOGE "选择 [0-23]"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "log")
        check_install 0 && show_log 0
        ;;
    "banlog")
        check_install 0 && show_banlog 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi
