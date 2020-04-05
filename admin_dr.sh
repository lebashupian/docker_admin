#!/bin/bash 
source /etc/profile
source ~/.bash_profile
stty erase '^H'


function exit_msg() {
	echo "$1"
	exit 1
}

[[ $1 == help || $1 == '' ]] && {
	echo "help 显示帮助"
	echo "net 查看docker网络列表,第二个参数可以跟具体的网络名称，会看到这个网络更为详细的信息"
	echo "create 创建主机"
	echo ""
	exit
}

function show_ip() {
	docker ps -a --format "{{.Names}}"|sort|while read line
	do
		echo ----------------$line
		docker inspect $line|grep IPAddress|grep -o -E '[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}'
	done	
}

function show_bonding_port() {
	docker ps -a --format "{{.Names}}"|sort|while read line
	do
		docker port $line
	done
}

[[ $1 == ip ]] && {
	show_ip
	exit
}

[[ $1 == net ]] && {
	docker network ls
	[[ ! -z $2 ]] && docker network inspect $2
	exit
}
[[ $1 == create || $1 == c ]] && {
	docker ps -a --format "{{.Names}}"
	read -p "容器名称:"  name
	read -p "主机名称:"  host_name
	docker network ls
	read -p "桥接网络:" net_name
	show_ip
	read -p "ip地址：" ipaddr
	docker images
	read -p "镜像名称:" image_name
	show_bonding_port
	read -p "端口映射:" port_mapping
	port=''
	for i in $port_mapping
	do
		port=$port" -p $i"
	done
	ping -c 4 -i 0.01 -w 1 $ipaddr > /dev/null && exit_msg "ip是通的，可能被占用"
	
	str="docker create -it --name $name --hostname $host_name --net $net_name --ip $ipaddr $port $image_name /bin/bash"
	echo $str
	eval $str
	exit
}
