!/bin/bash

IP_LIST=$(awk '/^192\./ {print $1}' /etc/hosts)
TARGET_IPS=("192.168.10.30" "192.168.10.40") # Multi-user.target으로 전환할 IP를 지정
HOST_NAMES=$(awk '/^192\./ {print $NF}' /etc/hosts)

# 1. Ping 테스트
for ip in $IP_LIST
do
ping -c 2 -W 1 $ip > /dev/null 2>&1
[ $? -eq 0 ] && echo "[ OK ] $ip" || "[ FAIL ] $ip"
done

# 2. devops 사용자 생성
for ip in $IP_LIST; do
    sshpass -p "centos" ssh -o StrictHostKeyChecking=no root@$ip "
        id devops &>/dev/null || useradd -G wheel devops
		echo 'devops' | passwd --stdin devops 
    "
done

# 3. SSH 키 배포
sudo yum -y install epel-release sshpass
printf "\n\n\n" | ssh-keygen 
for ip in $IP_LIST
do
sshpass -p devops ssh-copy-id -o StrictHostKeyChecking=no $ip
done

# 4. wheel 그룹에 속한 사용자가 암호 입력 없이 sudo 명령어를 사용할수 있도록 설정하기
for ip in $IP_LIST
do
ssh $ip "sudo sed -i '107s/^/#/;110s/^#//' /etc/sudoers"
done


# 5. 방화벽 활성화
for ip in $IP_LIST
do
ssh $ip "sudo systemctl enable --now firewalld"
done

# 6. Multi-user.target으로 전환
for ip in $TARGET_IPS
do
ssh $ip "sudo systemctl set-default multi-user.target && sudo systemctl isolate multi-user.target"
done

# 7. 바탕화면 아이콘 생성 - 바탕화면에 생성된 아이콘을 확인하고 실행 허용(Allow Launching) 선택(개별적으로 진행)
for ip in $IP_LIST; do
    if [[ ! " ${TARGET_IPS[@]} " =~ " $ip " ]]; then   # GUI 환경 서버만 선택
        ssh "$ip" "bash -s" <<'ENDSSH'
            sudo yum -y install gnome-tweaks

            for i in $(gnome-extensions list); do
                gnome-extensions enable $i
            done

            [ -d ~/바탕화면 ] && cp /usr/share/applications/org.gnome.{Terminal,gedit}.desktop ~/바탕화면
            [ -d ~/Desktop ] && cp /usr/share/applications/org.gnome.{Terminal,gedit}.desktop ~/Desktop
ENDSSH
    fi
done

# 8. 모든 서버에 SSH 접속 한 번씩 시도
for host in $HOST_NAMES
do
    ssh -o StrictHostKeyChecking=no devops@$host "exit"
done
