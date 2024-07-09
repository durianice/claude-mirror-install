#!/bin/bash

# 检查并安装 jq
if ! command -v jq &> /dev/null
then
    echo "jq is not installed. Installing jq..."
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update && sudo apt-get install -y jq
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y jq
    elif [ -x "$(command -v brew)" ]; then
        brew install jq
    else
        echo "Package manager not supported. Please install jq manually."
        exit 1
    fi
fi

# 检查并安装 unzip
if ! command -v unzip &> /dev/null
then
    echo "unzip is not installed. Installing unzip..."
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update && sudo apt-get install -y unzip
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y unzip
    elif [ -x "$(command -v brew)" ]; then
        brew install unzip
    else
        echo "Package manager not supported. Please install unzip manually."
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
EXTRACT_DIR="/opt/palaude_workdir"
PASSWORD="linux.do"
SERVICE_NAME="palaude"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

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
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# 获取本机IP地址
LOCAL_IP=$(hostname -I | awk '{print $1}')

# 菜单函数
show_menu() {
    echo "1. Install Palaude"
    echo "2. Start Palaude"
    echo "3. Stop Palaude"
    echo "4. Restart Palaude"
    echo "5. Status of Palaude"
    echo "6. Uninstall Palaude"
    echo "7. Update Palaude"
    echo "8. Exit"
}

# 安装函数
install_palaude() {
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
        echo "No executable file found in the extracted directory."
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
Description=Palaude Service
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

    echo "Service $SERVICE_NAME has been installed and started."
}

# 启动服务函数
start_palaude() {
    systemctl start $SERVICE_NAME
    echo "Service $SERVICE_NAME started."
}

# 停止服务函数
stop_palaude() {
    systemctl stop $SERVICE_NAME
    echo "Service $SERVICE_NAME stopped."
}

# 重启服务函数
restart_palaude() {
    systemctl restart $SERVICE_NAME
    echo "Service $SERVICE_NAME restarted."
}

# 查看服务状态函数
status_palaude() {
    systemctl status $SERVICE_NAME
}

# 更新函数
update_palaude() {
    # 停止服务
    stop_palaude

    # 下载并安装最新版本
    install_palaude

    # 启动服务
    start_palaude

    echo "Service $SERVICE_NAME has been updated and restarted."
}

# 卸载函数
uninstall_palaude() {
    systemctl stop $SERVICE_NAME
    systemctl disable $SERVICE_NAME
    rm $SERVICE_FILE
    systemctl daemon-reload
    rm -rf $EXTRACT_DIR
    echo "Service $SERVICE_NAME has been uninstalled."
}

# 主程序
while true; do
    show_menu
    read -p "Please select an option: " choice
    case $choice in
        1)
            install_palaude
            ;;
        2)
            start_palaude
            ;;
        3)
            stop_palaude
            ;;
        4)
            restart_palaude
            ;;
        5)
            status_palaude
            ;;
        6)
            uninstall_palaude
            ;;
        7)
            update_palaude
            ;;
        8)
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
done
