#!/bin/bash

BASE_URL="https://github.com/wozulong/Palaude/releases/download/v0.0.1"
ARCH=$(uname -m)
ZIP_FILE=""
EXTRACT_DIR="/opt/palaude_workdir"
PASSWORD="linux.do"
SERVICE_NAME="palaude"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

# 根据架构选择下载文件
case $ARCH in
    x86_64)
        ZIP_FILE="palaude-linux-amd64-0b8a771.zip"
        ;;
    i386)
        ZIP_FILE="palaude-linux-386-0b8a771.zip"
        ;;
    armv7l)
        ZIP_FILE="palaude-linux-arm-0b8a771.zip"
        ;;
    aarch64)
        ZIP_FILE="palaude-linux-arm64-0b8a771.zip"
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
    echo "4. Uninstall Palaude"
    echo "5. Exit"
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

    # 重命名解压后的目录
    mv $EXTRACT_DIR/palaude-linux-*/* $EXTRACT_DIR/
    rm $EXTRACT_DIR/palaude-linux-*/

    # 设置可执行权限
    chmod +x $EXTRACT_DIR/palaude/palaude

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
ExecStart=$EXTRACT_DIR/palaude
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
            uninstall_palaude
            ;;
        5)
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
done
