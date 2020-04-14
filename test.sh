#for i `docker ps -a|grep -v NAMES|awk '{print $1}'`
#do
#
#done


image=img/centos75:new

#https://www.cnblogs.com/fuyuteng/p/8847331.html

[[ $1 == del ]] && {
dmidecode |grep 'VMware Virtual Platform' || exit 
cp -f /etc/hosts /tmp/hosts/hosts.`date +%F-%T`
sed -i /new/d /etc/hosts
for line in `docker ps -a --format "{{.Names}}"`
do
        {
                docker stop $line -t 1  && echo "stop $line"
                docker rm $line && echo "rm $line"
        } &
done

wait
exit
}



for i in {1..3}
do
echo ----------------------new.$i----------10.0.1.$i
j=$(($i+2))
docker create -it --name new.$i --hostname new_10_0_1_$i --net mynetwork1 --ip 10.0.1.$i \
-p 192.168.137.$j:80:80 \
-v /data/nginx:/data \
--cpus=2 \
--memory 100m \
--cpuset-cpus 0,1 \
$image /bin/bash
sleep 1
docker start new.$i 
docker exec -d new.$i /usr/sbin/sshd
echo "10.0.1.$i new.$i"	>> /etc/hosts
done

rm -f /root/.ssh/known_hosts
#
# docker启动的时候提示WARNING: IPv4 forwarding is disabled. Networking will not work.
# /etc/sysctl.conf 添加net.ipv4.ip_forward=1 
# sysctl -p
# 重新生成docker


for i in `cat /etc/hosts|grep new|awk '{print $2}'`
do
ssh-copy-id -f $i
done

for i in `cat /etc/hosts|grep new|awk '{print $2}'`
do
echo --------------$i
ssh $i 'date'
done


#yum makecache;yum -y install epel-release;yum -y install nginx;nginx;
exit
for i in {3..5}
do
echo -------------192.168.137.$i
nc -z -w 1 192.168.137.$i 80  && echo ok || echo failed
done

#
#然后由 stress 命令创建四个繁忙的进程消耗 CPU 资源：
#stress -c 4
