#!/bin/bash 
source /etc/profile
source ~/.bash_profile

DIR="$( cd "$( dirname "$0"  )" && pwd  )"

cd $DIR

stty erase '^H'


function exit_msg() {
	echo "$1"
	exit 1
}

[[ $1 == help || $1 == '' ]] && {
	echo "help 显示帮助，以下都是自定义命令。同时脚本可以接受所有的docke命令"
	echo "net show_net sn查看ocker网络列表,第二个参数可以跟具体的网络名称，会看到这个网络更为详细的信息"
	echo "create c 创建主机"
	echo "create_net cn 创建网络" 
	echo "show_ip si 展示所有容器的ip分配"
	echo "show_bonding_port sbp 展示容器和主机的绑定信息"
	echo "show_vol sv 显示主机目录和容器目录的映射"
	echo "export 导出容器"
	echo "import 导入容器"
	echo "save   导出镜像"
	echo "load   导入镜像"
	echo "always_restart 容器名称  随服务启动"
	echo "bash   启动一个bash来和docker交互"
	echo "loopdo 跟一个主机列表别名, 别名定义在container_list.txt文件中"
	exit
}

function show_ip() {
	docker ps -a --format "{{.Names}}"|sort|while read line
	do
		echo ----------------$line
		docker inspect $line|grep IPAddress|grep -o -E '[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}'
	done	
}

[[ $1 == show_ip || $1 == si ]] && {
	show_ip
	exit 
}

function show_bonding_port() {
	docker ps -a --format "{{.Names}}"|sort|while read line
	do
		docker port $line
	done
}

[[ $1 == show_bonding_port || $1 == sbp ]] && {
	show_bonding_port
	exit 
}

function show_vol() {
	docker ps -a --format "{{.Names}}"|sort|while read line
	do
		echo --------------$line
		docker inspect $line|grep -E "Source|Destination"
	done
}

[[ $1 == show_vol || $1 == sv ]] && {
	show_vol
	exit 
}

[[ $1 == net || $1 == show_net || $1 == sn ]] && {
	docker network ls
	[[ ! -z $2 ]] && docker network inspect $2
	exit
}
[[ $1 == create || $1 == c ]] && {
	echo "#######已经存在的容器列表："
	docker ps -a --format "{{.Names}}"
	read -p "容器名称:"  name
	read -p "主机名称:"  host_name
	echo "#######系统中定义的网络："
	#docker network ls

	select net_name in `	
	docker network ls|grep [a-z0-9]|while read line  
	do
	echo $line|awk '{print $2}'
	done|while read line
	do
	docker network inspect $line|grep -E "Name|Subnet"|head -n 2|awk -F ":" '{print $2}'|xargs|sed 's/ //g'|awk -F "," '{print $1"@@"$2}'
	done
	`
	do
	net_name=`echo $net_name|awk -F "@@" '{print $1}'`
	break
	done
	
	
	
	#read -p "桥接网络:" net_name
	#echo "#######容器中使用的ip地址："
	#show_ip
	
	echo =======================网络信息============================
	
	docker network inspect "$net_name"|grep -E "Name|IPv4Address"
	echo ======================================================
	
	read -p "ip地址：" ipaddr
	echo "#######镜像列表："
	#docker images
	select image_name in `docker images|awk '{print $1":"$2}'|grep -v "REPOSITORY:TAG"`
	do
		echo $image_name
		break
	done


	#read -p "镜像名称" image_name
	echo "目前存在的映射关系："
	show_bonding_port
	echo "设定方式 宿主ip(可以省略):宿主port:容器port 空格隔开 下一组配置"
	read -p "端口映射" port_mapping
	port=''
	for i in $port_mapping
	do
		port=$port" -p $i"
	done
	echo "宿主主机和容器的存储映射关系 (宿主:容器 宿主:容器 空格隔开 下一组配置),默认host:/docker_data/all_share --> docker:/mnt"
	vol=''
	read -p "目录映射" vol_mapping
	#默认把宿主的tmp共享给docker的mnt
	vol_mapping=${vol_mapping:-/docker_data/all_share:/mnt}
	for i in $vol_mapping
	do
		vol=$vol" -v $i"
	done
	
	#
	read -p "启动命令(default:/usr/sbin/init) " runcmd
	runcmd=${runcmd:/usr/sbin/init}
	

	read -p "是否启动sshd (Y|n)" sshd_service
	sshd_service=${sshd_service:-y}
	read -p "容器是否随docker服务启动(y|N)" auto_start
	auto_start=${auto_start:-n}

	ping -c 4 -i 0.01 -w 1 $ipaddr > /dev/null && exit_msg "ip是通的，可能被占用"
	
	[[ $auto_start == y || $auto_start == Y ]] && {
		auto_start_str="--restart=always"
	}

	str="docker create -it --name $name $auto_start_str --hostname $host_name $vol --net $net_name --ip $ipaddr $port $image_name /usr/sbin/init"
	echo $str|tee -a /tmp/admin_dr.log
	eval $str
	str="docker start $name;docker exec $name '/usr/sbin/sshd';docker ps"
	[[ $sshd_service == y || $sshd_service == Y ]] && {
		echo $str|tee -a /tmp/admin_dr.log
		eval $str
	}

	exit
}

[[ $1 == create_net || $1 == cn ]] && {
	echo =====================================================
	docker network ls|grep [a-z0-9]|while read line  
	do
	echo $line|awk '{print $2}'
	done|while read line
	do
	docker network inspect $line|grep -E "Name|Subnet"|head -n 2|awk -F ":" '{print $2}'|xargs|sed 's/ //g'|awk -F "," '{print $1"@@"$2}'
	done
	echo =====================================================
	read -p "网段/掩码:" netinfo
	read -p "名称:" netname
	docker network create --subnet $netinfo $netname
	exit
}


[[ $1 == info ]] && {
	docker inspect $2
	exit
}


[[ $1 == export ]] && {
	[[ -z $2 ]] && exit_msg "请输入容器名称"
	[[ -z $3 ]] && exit_msg "请输入导出文件名称"
	docker export $2 > $3.export
	exit
}


[[ $1 == import ]] && {
	[[ -z $2 ]] && exit_msg "请输入文件名称"
	[[ ! -f $2 ]] && exit_msg "$2 这个文件不存在"
	[[ -z $3 ]] && exit_msg "完全的docker镜像名称"
	cat $2 | docker import - $3
	exit
}

[[ $1 == save ]] && {
	[[ -z $2 ]] && exit_msg "请输入导出的文件名称"
	[[ -z $3 ]] && exit_msg "请输入完整镜像名称"
	docker save -o $2.save $3
	exit	
}

[[ $1 == load ]] && {
	[[ -z $2 ]] && exit_msg "请输入导出的文件名称"
	docker load --input $2
	exit
}

[[ $1 == always_restart ]] && {
	[[ -z $2 ]] && exit_msg "第二个参数是容器名字"
       docker container update --restart=always $2
	exit
}

[[ $1 == bash ]] && {
	[[ -z $2 ]] && exit_msg "第二个参数是容器名字"
	docker exec -it $2 /bin/bash
	exit
}

[[ $1 == loopdo ]] && {

	[[ $2 == '' ]] && {
		[[ -f container_list.txt ]] || {
			echo "#es@@@es01 es02" >> container_list.txt
			echo container_list.txt 文件不存在已经创建
		}
		cat container_list.txt|grep -v ^#
		exit
	}
	[[ -f container_list.txt ]] && {
		alias_name=$2
		shift 2
		for i in `awk -F "@@@" '$1 == "'$alias_name'" {print $2}' container_list.txt`
		do
			echo container name : $i
			docker exec $i $@
		done
		exit
	} || {
		echo "#es@@@es01 es02" >> container_list.txt
		echo "列表文件不存在,已经创建"
	}
}

[[ $1 == loopcp ]] && {

	[[ $2 == '' ]] && {
		[[ -f container_list.txt ]] || {
			echo "#es@@@es01 es02" >> container_list.txt
			echo container_list.txt 文件不存在已经创建
		}
		cat container_list.txt|grep -v ^#
		exit
	}
	[[ -f container_list.txt ]] && {
		alias_name=$2
		for i in `awk -F "@@@" '$1 == "'$alias_name'" {print $2}' container_list.txt`
		do
			echo container name : $i
			docker cp $3 $i:$4
		done
		exit
	} || {
		echo "#es@@@es01 es02" >> container_list.txt
		echo "列表文件不存在,已经创建"
	}
}
########################################################




##########接管其他命令
str="docker $*"
echo `date +%F-%T`" "$str|tee -a /tmp/admin_dr.log
eval "docker $*"
