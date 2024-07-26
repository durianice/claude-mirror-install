#!/bin/bash

# 检查并安装 jq
if ! command -v jq &> /dev/null
then
    echo "jq 未安装. 正在安装 jq..."
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update && sudo apt-get install -y jq
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y jq
    elif [ -x "$(command -v brew)" ]; then
        brew install jq
    else
        echo "不支持的包管理器. 请手动安装 jq."
        exit 1
    fi
fi

# 检查并安装 unzip
if ! command -v unzip &> /dev/null
then
    echo "unzip 未安装. 正在安装 unzip..."
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update && sudo apt-get install -y unzip
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y unzip
    elif [ -x "$(command -v brew)" ]; then
        brew install unzip
    else
        echo "不支持的包管理器. 请手动安装 unzip."
        exit 1
    fi
fi

# 获取最新的release信息
REPO="wozulong/fuclaude"
API_URL="https://api.github.com/repos/$REPO/releases/latest"
RELEASE_DATA=$(curl -s $API_URL)

# 提取最新release的tag_name
LATEST_TAG=$(echo $RELEASE_DATA | jq -r .tag_name)

# 基本URL
BASE_URL="https://github.com/$REPO/releases/download/$LATEST_TAG"
ARCH=$(uname -m)
ZIP_FILE=""
EXTRACT_DIR="/opt/claude_mirror_workdir"
PASSWORD="linux.do"
SERVICE_NAME="claude_mirror"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
CRON_JOB="0 4 * * * /bin/bash $EXTRACT_DIR/update_claude_mirror.sh > /dev/null 2>&1"

# 根据架构选择下载文件
case $ARCH in
    x86_64)
        ZIP_FILE=$(echo $RELEASE_DATA | jq -r '.assets[] | select(.name | contains("linux-amd64")) | .name')
        ;;
    i386)
        ZIP_FILE=$(echo $RELEASE_DATA | jq -r '.assets[] | select(.name | contains("linux-386")) | .name')
        ;;
    armv7l)
        ZIP_FILE=$(echo $RELEASE_DATA | jq -r '.assets[] | select(.name | contains("linux-arm")) | .name')
        ;;
    aarch64)
        ZIP_FILE=$(echo $RELEASE_DATA | jq -r '.assets[] | select(.name | contains("linux-arm64")) | .name')
        ;;
    *)
        echo "不支持的架构: $ARCH"
        exit 1
        ;;
esac

# 获取本机IP地址
LOCAL_IP=$(hostname -I | awk '{print $1}')

# 菜单函数
show_menu() {
    echo "1. 安装"
    echo "2. 启动"
    echo "3. 停止"
    echo "4. 重启"
    echo "5. 查看状态"
    echo "6. 卸载"
    echo "7. 更新"
    echo "8. 开启自动更新"
    echo "9. 关闭自动更新"
    echo "10. 退出"
}

# 安装函数
install_claude_mirror() {
    DOWNLOAD_URL="$BASE_URL/$ZIP_FILE"

    # 下载文件
    wget -O $ZIP_FILE $DOWNLOAD_URL

    # 创建解压目录
    mkdir -p $EXTRACT_DIR

    # 解压文件
    unzip -P $PASSWORD $ZIP_FILE -d $EXTRACT_DIR

    # 找到解压后的目录名称
    EXTRACTED_DIR=$(find $EXTRACT_DIR -mindepth 1 -maxdepth 1 -type d)

    # 将解压后的文件移动到目标目录
    mv $EXTRACTED_DIR/* $EXTRACT_DIR/
    rmdir $EXTRACTED_DIR

    # 查找可执行文件并设置可执行权限
    EXECUTABLE=$(find $EXTRACT_DIR -type f -executable -print -quit)
    if [ -z "$EXECUTABLE" ]; then
        echo "在解压目录中未找到可执行文件."
        exit 1
    fi
    chmod +x $EXECUTABLE

    # 更新config.json中的bind地址
    CONFIG_FILE="$EXTRACT_DIR/config.json"
    if [ -f "$CONFIG_FILE" ]; then
        sed -i "s/127.0.0.1/$LOCAL_IP/" $CONFIG_FILE
    fi

    # 创建systemd服务文件
    echo "[Unit]
Description=claude_mirror Service
After=network.target

[Service]
ExecStart=$EXECUTABLE
Restart=always
User=root
WorkingDirectory=$EXTRACT_DIR/
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target" > $SERVICE_FILE

    # 重新加载systemd守护进程
    systemctl daemon-reload

    # 启动并启用服务
    systemctl start $SERVICE_NAME
    systemctl enable $SERVICE_NAME

    echo "服务 $SERVICE_NAME 已安装并启动."

    # 创建更新脚本
    echo "#!/bin/bash
$EXTRACT_DIR/$(basename $0) 7" > $EXTRACT_DIR/update_claude_mirror.sh
    chmod +x $EXTRACT_DIR/update_claude_mirror.sh
}

# 启动服务函数
start_claude_mirror() {
    systemctl start $SERVICE_NAME
    echo "服务 $SERVICE_NAME 已启动."
}

# 停止服务函数
stop_claude_mirror() {
    systemctl stop $SERVICE_NAME
    echo "服务 $SERVICE_NAME 已停止."
}

# 重启服务函数
restart_claude_mirror() {
    systemctl restart $SERVICE_NAME
    echo "服务 $SERVICE_NAME 已重启."
}

# 查看服务状态函数
status_claude_mirror() {
    systemctl status $SERVICE_NAME
}

# 更新函数
update_claude_mirror() {
    # 停止服务
    stop_claude_mirror

    # 下载并安装最新版本
    install_claude_mirror

    # 启动服务
    start_claude_mirror

    echo "服务 $SERVICE_NAME 已更新并重启."
}

# 卸载函数
uninstall_claude_mirror() {
    systemctl stop $SERVICE_NAME
    systemctl disable $SERVICE_NAME
    rm $SERVICE_FILE
    systemctl daemon-reload
    rm -rf $EXTRACT_DIR
    echo "服务 $SERVICE_NAME 已卸载."
}

# 开启自动更新函数
enable_auto_update() {
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "自动更新已开启. claude_mirror 将在每天凌晨4点自动更新."
}

# 关闭自动更新函数
disable_auto_update() {
    crontab -l | grep -v "$CRON_JOB" | crontab -
    echo "自动更新已关闭."
}

# 主程序
while true; do
    show_menu
    read -p "请选择一个选项: " choice
    case $choice in
        1)
            install_claude_mirror
            ;;
        2)
            start_claude_mirror
            ;;
        3)
            stop_claude_mirror
            ;;
        4)
            restart_claude_mirror
            ;;
        5)
            status_claude_mirror
            ;;
        6)
            uninstall_claude_mirror
            ;;
        7)
            update_claude_mirror
            ;;
        8)
            enable_auto_update
            ;;
        9)
            disable_auto_update
            ;;
        10)
            exit 0
            ;;
        *)
            echo "无效选项. 请重试."
            ;;
    esac
done
