#!/usr/bin/sh
######！！！注意！！！######
#此脚本的泛用性很弱，只对ipv6且为apache2有效，当然通过修改相关表达式和文件位置也可以适配ipv4和其他服务软件
######！！！注意！！！######

######流程######
#读取access.log日志文件
#逐行提取ipv6地址
#判断地址是否重复
#   否，判断ip所在国家是否为国内
#   |   否，进行字符串相关操作后写入apache2配置文件封锁的IP池
#   |   是，不做封锁操作
#   是，查询下一行
#重启服务
######流程######



#######初始化全局变量start######
denyIP=""  #需加入apache2配置文件中封锁的IP池
ConfigFileLine=""  #apache2配置文件中需增加封锁IP池的标记行
ContrastIP="0000:0000:0000:0000:0000:0000:0000:0000" #初始化需要判断IP是否重复的变量
#######初始化全局变量end######

######读取日志文件循环start######
cat /var/log/apache2/access.log|while read line #读取日志文件access.log并将字符串值赋给变量line
do
    InquireIP=$(echo $line| grep -oE '(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))') #提取ipv6地址
    if [ $ContrastIP != $InquireIP ];then #地址重复判断
        echo $(echo "[";date "+%Y-%m-%d %H:%M:%S";echo "] ""$InquireIP")>>/home/nmsl/DenyIP.log
        echo $(echo "[";date "+%Y-%m-%d %H:%M:%S";echo "] ""正在判断...")>>/home/nmsl/DenyIP.log
        IP_country=$(echo $(curl "https://ip.zxinc.org/api.php?type=json&ip=$InquireIP")| sed 's/,/\n/g' | grep "country" | sed 's/:/\n/g' | sed '1d' | sed 's/\t//g'|awk '{print substr($1,2,6)}') #将InquireIP变量值给地址归属地查询api网站https://ip.zxinc.org/api.php?type=json&ip=$InquireIP进行地址归属地查询，并对得到的返回值（json）进行处理，只显示两个汉字字符（不是中国的一律封禁）
        echo $(echo "[";date "+%Y-%m-%d %H:%M:%S";echo "] ""$IP_country")>>/home/nmsl/DenyIP.log
        sleep 2s #请求api延时2s
        if [ $IP_country != "中国" ];then #判断ip归属地是否为中国
            denyIP=$(echo $InquireIP|awk 'BEGIN{FS=OFS=":"}NF=2'|sed 's/^/Deny From / '|sed 's/$/::\/32/') #对日志中得到的ipv6地址进行字符处理，得到形如“Deny From xxxx:xxxx::/32”的字符串
            ConfigFileLine=$(sed -n  '/#denyIP标记行/=' /etc/apache2/apache2.conf) #找到apache2配置文件中需添加的标记行（标记行需要手动添加到apache2配置文件，以方便脚本找到添加封禁ip的所需位置，比如我在apache2配置文件的合适位置中加入“#denyIP标记行”，标记字符前必须加“#”以注释）
            sed -i ''"$ConfigFileLine"' i \\t'"$denyIP"'' /etc/apache2/apache2.conf #找到标记行并在标记行处加入封禁ip，且标记行下移一行
            echo $(echo "[";date "+%Y-%m-%d %H:%M:%S";echo "] ""IP:[$InquireIP]""已加入黑名单")>>/home/nmsl/DenyIP.log
        #else
            #echo $(echo "[";date "+%Y-%m-%d %H:%M:%S";echo "] ""国内IP")
        fi
    #else
        #echo $(echo "[";date "+%Y-%m-%d %H:%M:%S";echo "] ""ip重复，跳过")
    fi
    ContrastIP=$InquireIP #将本次处理的ip地址赋值给ContrastIP以便下次做地址重复判断
done
######读取日志文件循环end######

######重启服务start######
echo $(echo "[";date "+%Y-%m-%d %H:%M:%S";echo "] ";echo "重启apache2服务...";service apache2 restart;)>>/home/nmsl/DenyIP.log
echo $(echo "[";date "+%Y-%m-%d %H:%M:%S";echo "] ";echo "apache2服务状态:";service apache2 status)>>/home/nmsl/DenyIP.log
######重启服务end######