#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
PLAIN='\033[0m'

# 仓库地址
REPO_URL="https://github.com/Li-yi-sen/21-zhuanfavpn"
RAW_URL="https://raw.githubusercontent.com/Li-yi-sen/21-zhuanfavpn/main/3x-ui"

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：请使用root用户运行此脚本${PLAIN}"
        exit 1
    fi
}

# 检查系统类型
check_system() {
    if [[ -f /etc/redhat-release ]]; then
        RELEASE="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        RELEASE="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        RELEASE="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        RELEASE="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        RELEASE="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        RELEASE="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        RELEASE="centos"
    else
        echo -e "${RED}未检测到系统版本，请联系脚本作者！${PLAIN}"
        exit 1
    fi
    
    echo -e "${GREEN}检测到系统类型: ${RELEASE}${PLAIN}"
}

# 安装必要的软件包
install_base() {
    echo -e "${YELLOW}安装必要的软件包...${PLAIN}"
    
    if [[ "${RELEASE}" == "centos" ]]; then
        yum update -y
        yum install -y wget curl tar socat
    else
        apt update -y
        apt install -y wget curl tar socat
    fi
    
    echo -e "${GREEN}基础软件包安装完成${PLAIN}"
}

# 安装Docker
install_docker() {
    echo -e "${YELLOW}检查Docker是否已安装...${PLAIN}"
    
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}Docker已安装，跳过安装步骤${PLAIN}"
    else
        echo -e "${YELLOW}开始安装Docker...${PLAIN}"
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        systemctl start docker
        echo -e "${GREEN}Docker安装完成${PLAIN}"
    fi
    
    # 检查Docker是否正常运行
    if ! docker info &> /dev/null; then
        echo -e "${RED}Docker安装失败或未正常运行，请检查错误信息${PLAIN}"
        exit 1
    fi
}

# 安装Docker Compose
install_docker_compose() {
    echo -e "${YELLOW}检查Docker Compose是否已安装...${PLAIN}"
    
    if command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}Docker Compose已安装，跳过安装步骤${PLAIN}"
    else
        echo -e "${YELLOW}开始安装Docker Compose...${PLAIN}"
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
        curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
        echo -e "${GREEN}Docker Compose安装完成${PLAIN}"
    fi
    
    # 检查Docker Compose是否正常
    if ! docker-compose version &> /dev/null; then
        echo -e "${RED}Docker Compose安装失败，请检查错误信息${PLAIN}"
        exit 1
    fi
}

# 创建项目目录和配置文件
create_project_files() {
    echo -e "${YELLOW}创建项目目录和配置文件...${PLAIN}"
    
    mkdir -p 3x-ui
    cd 3x-ui
    
    # 创建目录结构
    mkdir -p db cert wwwroot wwwroot/static
    
    # 下载docker-compose.yml
    echo -e "${YELLOW}下载docker-compose.yml...${PLAIN}"
    curl -O ${RAW_URL}/docker-compose.yml
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载docker-compose.yml失败，尝试使用备用方式...${PLAIN}"
        cat > docker-compose.yml << 'EOF'
services:
  3xui:
    image: ghcr.io/xeefei/3x-ui:latest
    container_name: 3xui_app
    volumes:
      - $PWD/db/:/etc/x-ui/
      - $PWD/cert/:/root/cert/
      - $PWD/wwwroot:/app/wwwroot
    environment:
      XRAY_VMESS_AEAD_FORCED: "false"
      XUI_ENABLE_FAIL2BAN: "true"
    tty: true
    privileged: true
    cap_add:
      - NET_ADMIN
      - NET_BIND_SERVICE
    ports:
      - "2053:2053"
    restart: unless-stopped
  
  nginx:
    image: nginx:alpine
    container_name: 3xui_nginx
    volumes:
      - $PWD/wwwroot:/usr/share/nginx/html
      - $PWD/nginx.conf:/etc/nginx/conf.d/default.conf
    ports:
      - "80:80"
    restart: unless-stopped
EOF
    fi

    # 下载nginx.conf
    echo -e "${YELLOW}创建nginx.conf...${PLAIN}"
    curl -O ${RAW_URL}/nginx.conf
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载nginx.conf失败，尝试使用备用方式...${PLAIN}"
        cat > nginx.conf << 'EOF'
server {
    listen 80;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
EOF
    fi

    # 创建默认首页
    echo -e "${YELLOW}创建默认首页...${PLAIN}"
    curl -o wwwroot/index.html ${RAW_URL}/wwwroot/index.html
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载index.html失败，尝试使用备用方式...${PLAIN}"
        cat > wwwroot/index.html << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>云服务器管理中心</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: 'Microsoft YaHei', sans-serif;
        }
        body {
            background-color: #f5f5f5;
            color: #333;
            line-height: 1.6;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        header {
            background: linear-gradient(135deg, #1a237e 0%, #283593 100%);
            color: white;
            padding: 60px 20px;
            text-align: center;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        h1 {
            font-size: 2.5rem;
            margin-bottom: 20px;
        }
        .subtitle {
            font-size: 1.2rem;
            margin-bottom: 30px;
            opacity: 0.9;
        }
        .btn {
            display: inline-block;
            background-color: #fff;
            color: #1a237e;
            padding: 12px 30px;
            border-radius: 30px;
            text-decoration: none;
            font-weight: bold;
            transition: all 0.3s ease;
            margin: 10px;
        }
        .btn:hover {
            background-color: #f0f0f0;
            transform: translateY(-3px);
            box-shadow: 0 10px 20px rgba(0,0,0,0.1);
        }
        .features {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 30px;
            margin-top: 50px;
        }
        .feature-card {
            background-color: white;
            border-radius: 8px;
            padding: 30px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.05);
            transition: transform 0.3s ease;
        }
        .feature-card:hover {
            transform: translateY(-5px);
        }
        .feature-title {
            font-size: 1.4rem;
            margin-bottom: 15px;
            color: #1a237e;
        }
        footer {
            margin-top: 80px;
            text-align: center;
            padding: 30px;
            background-color: #1a237e;
            color: white;
        }
        .login-section {
            text-align: center;
            margin: 60px 0;
            padding: 40px;
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.05);
        }
        .login-section h2 {
            margin-bottom: 20px;
            color: #1a237e;
        }
        .services {
            margin-top: 50px;
        }
        .services h2 {
            text-align: center;
            margin-bottom: 30px;
            color: #1a237e;
        }
        .service-list {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
        }
        .service-item {
            background-color: white;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            box-shadow: 0 4px 6px rgba(0,0,0,0.05);
        }
        .service-item h3 {
            color: #1a237e;
            margin-bottom: 10px;
        }
    </style>
</head>
<body>
    <header>
        <div class="container">
            <h1>云服务器管理中心</h1>
            <p class="subtitle">高性能、安全稳定的云服务解决方案</p>
            <a href="#services" class="btn">了解服务</a>
        </div>
    </header>

    <div class="container">
        <div class="features">
            <div class="feature-card">
                <h3 class="feature-title">高性能服务器</h3>
                <p>采用最新硬件配置，提供卓越的计算性能和稳定的网络连接，满足各类业务需求。</p>
            </div>
            <div class="feature-card">
                <h3 class="feature-title">全球加速网络</h3>
                <p>多节点分布式部署，智能路由技术，为您的应用提供全球范围内的快速访问体验。</p>
            </div>
            <div class="feature-card">
                <h3 class="feature-title">安全防护系统</h3>
                <p>多层次安全架构，防DDoS攻击，数据加密传输，保障您的业务安全稳定运行。</p>
            </div>
        </div>

        <div class="services" id="services">
            <h2>我们的服务</h2>
            <div class="service-list">
                <div class="service-item">
                    <h3>云服务器</h3>
                    <p>高性能、可扩展的云计算资源，满足各类应用场景需求。</p>
                </div>
                <div class="service-item">
                    <h3>数据存储</h3>
                    <p>安全可靠的数据存储解决方案，支持多种备份和恢复策略。</p>
                </div>
                <div class="service-item">
                    <h3>网络加速</h3>
                    <p>全球分布式网络节点，提供稳定快速的网络访问体验。</p>
                </div>
                <div class="service-item">
                    <h3>安全防护</h3>
                    <p>全方位安全防护服务，保障您的业务安全稳定运行。</p>
                </div>
            </div>
        </div>

        <div class="login-section">
            <h2>服务器状态</h2>
            <p>当前服务器运行正常，系统负载稳定</p>
            <a href="#contact" class="btn">联系我们</a>
        </div>
    </div>

    <footer id="contact">
        <div class="container">
            <p>Copyright © 2023-2024 云服务器管理中心 | 技术支持与定制开发</p>
        </div>
    </footer>
</body>
</html>
EOF
    fi

    echo -e "${GREEN}项目文件创建完成${PLAIN}"
}

# 启动服务
start_service() {
    echo -e "${YELLOW}启动3X-UI服务...${PLAIN}"
    
    docker-compose up -d
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}服务启动失败，请检查错误信息${PLAIN}"
        exit 1
    fi
    
    echo -e "${GREEN}3X-UI服务启动成功${PLAIN}"
}

# 创建管理脚本
create_management_script() {
    echo -e "${YELLOW}创建管理脚本...${PLAIN}"
    
    cat > /usr/bin/3x-ui << 'EOF'
#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误：请使用root用户运行此脚本${PLAIN}"
    exit 1
fi

# 检查工作目录
if [ ! -d "/root/3x-ui" ]; then
    echo -e "${RED}错误：未找到3X-UI安装目录，请确认安装是否正确${PLAIN}"
    exit 1
fi

cd /root/3x-ui

case "$1" in
    start)
        echo -e "${GREEN}启动3X-UI服务...${PLAIN}"
        docker-compose up -d
        ;;
    stop)
        echo -e "${YELLOW}停止3X-UI服务...${PLAIN}"
        docker-compose down
        ;;
    restart)
        echo -e "${YELLOW}重启3X-UI服务...${PLAIN}"
        docker-compose restart
        ;;
    status)
        echo -e "${GREEN}3X-UI服务状态:${PLAIN}"
        docker-compose ps
        ;;
    update)
        echo -e "${YELLOW}更新3X-UI服务...${PLAIN}"
        docker-compose pull
        docker-compose up -d
        echo -e "${GREEN}3X-UI已更新至最新版本${PLAIN}"
        ;;
    logs)
        echo -e "${GREEN}查看3X-UI日志:${PLAIN}"
        docker-compose logs -f
        ;;
    backup)
        BACKUP_FILE="3x-ui-backup-$(date +%Y%m%d%H%M%S).tar.gz"
        echo -e "${YELLOW}备份3X-UI数据到 ${BACKUP_FILE}...${PLAIN}"
        tar -czvf ~/${BACKUP_FILE} -C /root/3x-ui db
        echo -e "${GREEN}备份已完成: ~/${BACKUP_FILE}${PLAIN}"
        ;;
    *)
        echo "3X-UI 管理脚本 v5.1"
        echo "用法: 3x-ui [选项]"
        echo ""
        echo "选项:"
        echo "  start    - 启动服务"
        echo "  stop     - 停止服务"
        echo "  restart  - 重启服务"
        echo "  status   - 查看服务状态"
        echo "  update   - 更新到最新版本"
        echo "  logs     - 查看服务日志"
        echo "  backup   - 备份数据库"
        echo ""
        ;;
esac
EOF

    chmod +x /usr/bin/3x-ui
    echo -e "${GREEN}管理脚本创建完成，您可以使用 '3x-ui' 命令管理服务${PLAIN}"
}

# 获取服务器IP
get_server_ip() {
    IP=$(curl -s https://api.ipify.org || curl -s https://api64.ipify.org)
    if [[ -z "${IP}" ]]; then
        IP=$(ip route get 1 | awk '{print $NF;exit}')
        if [[ -z "${IP}" ]]; then
            echo -e "${RED}无法检测到服务器IP地址${PLAIN}"
            IP="您的服务器IP"
        fi
    fi
}

# 显示安装完成信息
show_completion_info() {
    echo -e "${GREEN}=================================================${PLAIN}"
    echo -e "${GREEN}          3X-UI v5.1 安装已完成!                ${PLAIN}"
    echo -e "${GREEN}=================================================${PLAIN}"
    echo -e ""
    echo -e " ${YELLOW}管理面板:${PLAIN}  http://${IP}:2053"
    echo -e " ${YELLOW}用户名:${PLAIN}    admin"
    echo -e " ${YELLOW}密码:${PLAIN}      admin"
    echo -e ""
    echo -e " ${YELLOW}伪装网站:${PLAIN}  http://${IP}"
    echo -e ""
    echo -e " ${YELLOW}管理命令:${PLAIN}  3x-ui              # 显示管理菜单"
    echo -e " ${YELLOW}启动服务:${PLAIN}  3x-ui start"
    echo -e " ${YELLOW}停止服务:${PLAIN}  3x-ui stop"
    echo -e " ${YELLOW}重启服务:${PLAIN}  3x-ui restart"
    echo -e " ${YELLOW}查看状态:${PLAIN}  3x-ui status"
    echo -e " ${YELLOW}查看日志:${PLAIN}  3x-ui logs"
    echo -e " ${YELLOW}更新面板:${PLAIN}  3x-ui update"
    echo -e " ${YELLOW}备份数据:${PLAIN}  3x-ui backup"
    echo -e ""
    echo -e "${RED} 重要提示: 首次登录后请立即修改默认密码!${PLAIN}"
    echo -e "${GREEN}=================================================${PLAIN}"
}

# 主函数
main() {
    clear
    echo -e "${BLUE}=================================================${PLAIN}"
    echo -e "${BLUE}              3X-UI v5.1 安装脚本               ${PLAIN}"
    echo -e "${BLUE}=================================================${PLAIN}"
    echo -e ""
    
    check_root
    check_system
    install_base
    install_docker
    install_docker_compose
    
    # 创建工作目录
    cd /root
    create_project_files
    start_service
    create_management_script
    get_server_ip
    show_completion_info
}

# 执行主函数
main
