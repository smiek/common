#!/bin/bash

##下载地址
download="https://raw.githubusercontent.com/smiek/common/master/mtp/mtp"
##获取ip接口
get_ip="4.ipw.cn"
##版本号
version="1.0"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && yellow_font_prefix="\033[33m" && Font_color_suffix="\033[0m"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${yellow_font_prefix}[注意]${Font_color_suffix}"

#开始菜单
start_menu() {
	clear
	echo && echo -e " 🚀 mtproto 一键安装管理脚本 🚀 (当前版本: ${version})

 ${Green_font_prefix}0.${Font_color_suffix} 升级脚本
————————————基本管理————————————
 ${Green_font_prefix}1.${Font_color_suffix} 一键安装 mtproto
 ${Green_font_prefix}2.${Font_color_suffix} 更改密钥 
 ${Green_font_prefix}3.${Font_color_suffix} 更改端口
 ${Green_font_prefix}4.${Font_color_suffix} 查看代理信息
 ${Green_font_prefix}5.${Font_color_suffix} 卸载脚本
 ${Green_font_prefix}6.${Font_color_suffix} 退出脚本
————————————————————————————————" && check_status && echo

	read -p "请输入数字 [0-6]:" num
	case "$num" in
	0)
		update
		;;
	1)
		install
		;;
	2)
		change_secret
		;;
	3)
		change_port
		;;
	4)
		check_info
		;;
	5)
		uninstall
		;;
	6)
		exit 1
		;;
	*)
		clear
		echo -e "${Error}:请输入正确数字 [0-6]"
		sleep 5s
		start_menu
		;;
	esac
}

#更新脚本
update() {
	echo -e "\n${Green_font_prefix}当前版本为 ${version} 开始检测最新版本...${Font_color_suffix}\n"
	new_version=$(wget -qO- "${download}.sh" 2>&1 | grep 'version="' | awk -F '"' '{print $2}' | head -n 1)
	if [[ $? -ne 0 || -z ${new_version} ]]; then
		echo -e "${Error}检测最新版本失败 !" && exit 1
	fi

	if [[ ${new_version} > ${version} ]]; then
		echo -e "发现新版本 ${new_version} 是否更新？[Y/n]"
		read -p "(默认: y):" yn
		[[ -z "${yn}" ]] && yn="y"
		if [[ ${yn} == [Yy] ]]; then
			wget -N --no-check-certificate ${download}.sh && chmod +x mtp.sh
			echo -e "${Green_font_prefix}脚本已更新为最新版本 ${new_version} ! ${Font_color_suffix}"
			version=${new_version}
			sleep 5s && start_menu
		else
			echo && echo -e "${Error}操作已取消..." && echo
		fi
	else
		echo -e "${Tip}当前已是最新版本 ${new_version} !"
		sleep 5s && start_menu
	fi
}

check_status() {
	if systemctl status mtp &>/dev/null; then
		echo -e "当前状态：${Green_font_prefix}已安装${Font_color_suffix} \c"
		if systemctl is-enabled mtp &>/dev/null; then
			echo -e "开机自启：${Green_font_prefix}已开启${Font_color_suffix}"
		else
			echo -e "开机自启：${Red_font_prefix}未开启${Font_color_suffix}"
		fi
	else
		echo -e "当前状态：${Red_font_prefix}未安装${Font_color_suffix}"
	fi
}

check_sys() {

	#检查系统发行版
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif grep -q -E -i "debian" /etc/issue 2>/dev/null; then
		release="debian"
	elif grep -q -E -i "ubuntu" /etc/issue 2>/dev/null; then
		release="ubuntu"
	elif grep -q -E -i "centos|red hat|redhat" /etc/issue 2>/dev/null; then
		release="centos"
	elif grep -q -E -i "debian" /proc/version 2>/dev/null; then
		release="debian"
	elif grep -q -E -i "ubuntu" /proc/version 2>/dev/null; then
		release="ubuntu"
	elif grep -q -E -i "centos|red hat|redhat" /proc/version 2>/dev/null; then
		release="centos"
	else
		echo -e "${Error} 本脚本不支持当前系统!" && exit 1
	fi

	# 获取CPU架构信息
	cpu_arch=$(uname -m)

	# 匹配CPU架构
	if [ "$cpu_arch" = "x86_64" ]; then
		arch="amd64"
	elif [ "$cpu_arch" = "i686" ]; then
		arch="x86"
	elif [ "$cpu_arch" = "aarch64" ]; then
		arch="arm64"
	elif [ "$cpu_arch" = "armv8" ]; then
		arch="armv7"
	elif [ "$cpu_arch" = "armv7l" ]; then
		arch="armv7"
	elif [ "$cpu_arch" = "armv6l" ]; then
		arch="armv6"
	fi
	

	if [ -z "$arch" ]; then
    echo -e "${Error}未能获取到CPU架构信息，脚本终止"
    exit 1
	fi



	#使用apt或者yum
	if [ "$release" = "ubuntu" ] || [ "$release" = "debian" ]; then
		tool="apt"
	else
		tool="yum"
	fi
}

check_config_file() {
	config_file="/etc/mtp.toml" # 定义配置文件路径
	if [ -f "$config_file" ]; then
		# 检查配置文件中是否包含正确格式的密钥和端口设置
		if grep -q -E 'secret\s*=\s*".+"' /etc/mtp.toml && grep -q -E 'bind-to\s*=\s*".+:[0-9]+"' /etc/mtp.toml; then
			return 0 # 文件存在且格式正确
		else
			echo -e "${Error}配置文件格式不正确，请执行第一步并确保安装成功"
			return 1 # 配置文件格式错误
		fi
	else
		echo -e "${Error}未检测到配置文件，请先执行第一步安装"
		return 1 # 文件不存在
	fi
}

create_domain() {
	read -p "请输入要伪装的域名(默认baidu.com): " input_domain

	# 如果用户未输入任何内容，则将 domain 变量赋值为默认值
	if [ -z "$input_domain" ]; then
		domain="baidu.com"
	else
		# 检查域名格式
		if [[ $input_domain =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
			domain="$input_domain"
		else
			echo -e "${Error}无效的域名格式"
			exit 1
		fi
	fi
}

create_port() {
	while true; do
		read -p "请输入端口(默认4096):" input_port

		# 如果用户未输入任何内容，则将 port 变量赋值为默认值4096
		if [ -z "$input_port" ]; then
			input_port="4096"
		fi

		# 检查输入是否符合条件
		if [[ $input_port =~ ^[0-9]+$ ]] && ((input_port >= 1)) && ((input_port <= 65535)); then
			if lsof -i :$input_port >/dev/null; then
				echo -e "${Tip}端口 $input_port 已被占用，请重新输入"
			else
				port="$input_port"
				break
			fi
		else
			echo -e "${Tip}端口号必须为数字且在1到65535之间"
		fi
	done
}

check_info() {
	# 检查配置文件是否存在
	if check_config_file; then
		# 读取配置文件
		secret=$(awk -F' = ' '/secret/ {print $2}' $config_file | tr -d '"')
		port=$(awk -F'[: ]+' '/bind-to/ {print $4}' $config_file)
		# 去除端口号中可能包含的引号
		port=$(echo $port | tr -d '"')
		# 输出信息
		ip=$(curl -s ${get_ip})
		if ! [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
			ip="${Tip}获取ip地址失败"
		fi
		echo -e "\nip：$ip\n端口：$port\n密钥：$secret\n电报链接：tg://proxy?server=${ip}&port=${port}&secret=${secret}"
	fi
}

install() {

	$tool update -y && $tool install wget curl lsof -y

	##下载程式文件
	echo -e "\n${Green_font_prefix}开始下载程式${Font_color_suffix}\n"
	if wget -O "mtp" "${download}-${arch}"; then
		mv mtp /etc && chmod +x /etc/mtp
	else
		echo -e "${Error}下载文件失败"
		exit 1
	fi

	##创建域名
	create_domain

	##创建端口
	create_port

	echo -e "\n${Green_font_prefix}正在生成密钥${Font_color_suffix}"
	secret=$(/etc/mtp generate-secret --hex "$domain")
	echo "$secret"

	echo -e "\n${Green_font_prefix}正在写入配置文件${Font_color_suffix}"
	if [ -f "/etc/mtp.toml" ]; then
		echo -e "${Tip}检测到旧配置文件已经存在，是否覆盖？[Y/n]"
		read -p "(默认: y):" yn
		[[ -z "${yn}" ]] && yn="y"
		if [[ ${yn} == [Yy] ]]; then
			echo -e "secret = \"$secret\"\nbind-to = \"0.0.0.0:$port\"" >/etc/mtp.toml
		else
			echo -e  "${Error}操作已取消..." && exit 1
		fi
	else
		echo -e "secret = \"$secret\"\nbind-to = \"0.0.0.0:$port\"" >/etc/mtp.toml
	fi

	create_service_file() {
		cat <<EOF >$1
			[Unit]
			Description=mtproto proxy server
			After=network.target

			[Service]
			ExecStart=/etc/mtp run /etc/mtp.toml
			Restart=always
			RestartSec=3
			DynamicUser=true
			AmbientCapabilities=CAP_NET_BIND_SERVICE

			[Install]
			WantedBy=multi-user.target
EOF
	}
	mtp_status() {
		#检查服务是否启动成功
		if systemctl show --property=SubState mtp.service | grep -q "SubState=running"; then
			echo -e "\n${Green_font_prefix}程式启动成功${Font_color_suffix}"
		else
			echo -e "\n${Error}程式启动出错，请检查启动项日志"
			exit 1
		fi
		ip=$(curl -s ${get_ip})
		if ! [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
			ip="${Tip}获取ip地址失败"
		fi
		echo -e "ip：$ip\n端口：$port\n密钥：$secret\n电报链接：tg://proxy?server=${ip}&port=${port}&secret=${secret}"

	}
	if [[ $release == "ubuntu" || $release == "debian" ]]; then
		service_file_path="/etc/systemd/system/mtp.service"
	elif [[ $release == "centos" ]]; then
		service_file_path="/usr/lib/systemd/system/mtp.service"
	else
		echo -e "${Error}写入失败"
		exit 1
	fi

	create_service_file "$service_file_path"
	systemctl daemon-reload
	systemctl enable mtp.service
	systemctl restart mtp.service
	mtp_status

}

change_secret() {
	if check_config_file; then
		create_domain
		new_secret=$(/etc/mtp generate-secret --hex "$domain")
		sed -i "s|^\(secret\s*=\s*\"\).*\(\".*\)$|\1${new_secret}\2|g" /etc/mtp.toml
		systemctl restart mtp.service
		echo "密钥已成功更新为：$new_secret"
	else
		exit 1
	fi
}

change_port() {
	if check_config_file; then
		create_port
		new_port=$port
		sed -i "s/^\(bind-to\s*=\s*\"[0-9.]*:\)[0-9]*\(\".*\)$/\1$new_port\2/g" /etc/mtp.toml
		systemctl restart mtp.service
		echo "端口已成功更新为：$new_port"
	else
		exit 1
	fi
}

uninstall() {
	if [[ $release == "ubuntu" || $release == "debian" ]]; then
		{
			systemctl disable mtp.service
			systemctl stop mtp.service
			systemctl daemon-reload
			rm -fr /etc/systemd/system/mtp.service /etc/mtp /etc/mtp.toml
		} 2>/dev/null
		echo -e "\n${Green_font_prefix}程式已卸载完成${Font_color_suffix}\n"

	elif [[ $release == "centos" ]]; then
		{
			systemctl disable mtp.service
			systemctl stop mtp.service
			systemctl daemon-reload
			rm -fr /usr/lib/systemd/system/mtp.service /etc/mtp /etc/mtp.toml
		} 2>/dev/null
		echo -e "\n${Green_font_prefix}程式已卸载完成${Font_color_suffix}\n"
	fi
}

check_sys
start_menu
