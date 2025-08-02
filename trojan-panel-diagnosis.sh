#!/bin/bash

# Trojan Panel Docker 诊断脚本
# 用于收集Docker容器运行时的详细诊断信息

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志文件
LOG_FILE="/tmp/trojan-panel-diagnosis-$(date +%Y%m%d_%H%M%S).log"

# 日志函数
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}$msg${NC}" | tee -a "$LOG_FILE"
}

warn() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1"
    echo -e "${YELLOW}$msg${NC}" | tee -a "$LOG_FILE"
}

error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1"
    echo -e "${RED}$msg${NC}" | tee -a "$LOG_FILE"
}

info() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1"
    echo -e "${BLUE}$msg${NC}" | tee -a "$LOG_FILE"
}

# 执行命令并输出到日志
run_cmd() {
    local cmd="$1"
    local desc="$2"
    
    info "$desc"
    echo "==========================================" >> "$LOG_FILE"
    echo "诊断项: $desc" >> "$LOG_FILE"
    echo "命令: $cmd" >> "$LOG_FILE"
    echo "时间: $(date)" >> "$LOG_FILE"
    echo "------------------------------------------" >> "$LOG_FILE"
    
    # 执行命令并捕获输出
    local output
    local exit_code
    
    output=$(eval "$cmd" 2>&1)
    exit_code=$?
    
    # 输出结果到日志
    echo "$output" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # 输出结果到控制台
    if [ $exit_code -eq 0 ]; then
        echo "✅ 成功" | tee -a "$LOG_FILE"
    else
        echo "❌ 失败 (退出码: $exit_code)" | tee -a "$LOG_FILE"
        # 如果命令失败，在日志中标记错误
        echo "[错误] 命令执行失败，退出码: $exit_code" >> "$LOG_FILE"
    fi
    
    echo "==========================================" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    return $exit_code
}

# 开始诊断
log "开始 Trojan Panel Docker 诊断"
log "诊断日志文件: $LOG_FILE"

# 1. 系统基本信息
log "=== 1. 系统基本信息 ==="
run_cmd "uname -a" "内核信息"
run_cmd "cat /etc/os-release" "操作系统版本"
run_cmd "docker --version" "Docker版本"
run_cmd "docker-compose --version" "Docker Compose版本" || warn "Docker Compose 未安装"
run_cmd "free -h" "内存信息"
run_cmd "df -h" "磁盘空间"
run_cmd "lscpu" "CPU信息"
run_cmd "date" "系统时间"

# 2. Docker状态检查
log "=== 2. Docker状态检查 ==="
run_cmd "docker ps -a" "所有容器状态"
run_cmd "docker images" "Docker镜像列表"
run_cmd "docker info" "Docker系统信息"
run_cmd "docker stats --no-stream" "Docker资源使用"

# 3. 网络配置检查
log "=== 3. 网络配置检查 ==="
run_cmd "ip addr show" "网络接口"
run_cmd "netstat -tuln" "监听端口"
run_cmd "docker network ls" "Docker网络"
run_cmd "iptables -L -n" "防火墙规则"
run_cmd "ping -c 3 8.8.8.8" "网络连通性测试"

# 4. 检查Trojan Panel相关容器
log "=== 4. Trojan Panel容器检查 ==="
CONTAINER_ID=$(docker ps -q --filter "name=trojan-panel" --filter "name=jonssonyan/trojan-panel" | head -1)
if [ -n "$CONTAINER_ID" ]; then
    info "找到Trojan Panel容器: $CONTAINER_ID"
    
    # 容器基本信息
    run_cmd "docker inspect $CONTAINER_ID" "容器详细信息"
    
    # 容器日志
    run_cmd "docker logs $CONTAINER_ID" "容器完整日志"
    run_cmd "docker logs $CONTAINER_ID --tail 50" "容器最近50行日志"
    
    # 容器资源使用
    run_cmd "docker stats $CONTAINER_ID --no-stream" "容器资源使用"
    
    # 容器进程
    run_cmd "docker top $CONTAINER_ID" "容器内进程"
    
    # 容器环境变量
    run_cmd "docker exec $CONTAINER_ID env" "容器环境变量"
    
    # 容器内文件系统
    run_cmd "docker exec $CONTAINER_ID ls -la /tpdata/trojan-panel/" "容器内应用目录"
    run_cmd "docker exec $CONTAINER_ID ls -la /tpdata/trojan-panel/logs/" "容器内日志目录"
    run_cmd "docker exec $CONTAINER_ID ls -la /tpdata/trojan-panel/config/" "容器内配置目录"
    
    # 检查二进制文件
    run_cmd "docker exec $CONTAINER_ID file /tpdata/trojan-panel/trojan-panel" "二进制文件信息"
    run_cmd "docker exec $CONTAINER_ID ls -la /tpdata/trojan-panel/trojan-panel" "二进制文件权限"
    
    # 检查启动脚本
    run_cmd "docker exec $CONTAINER_ID cat /tpdata/trojan-panel/start.sh" "启动脚本内容"
    
    # 检查依赖工具
    run_cmd "docker exec $CONTAINER_ID which mysql" "MySQL客户端路径"
    run_cmd "docker exec $CONTAINER_ID which redis-cli" "Redis客户端路径"
    run_cmd "docker exec $CONTAINER_ID which wget" "Wget路径"
    
    # 测试数据库连接
    run_cmd "docker exec $CONTAINER_ID mysql -h\${mariadb_ip} -P\${mariadb_port} -u\${mariadb_user} -p\${mariadb_pas} -e \"SELECT 1;\"" "MySQL连接测试"
    run_cmd "docker exec $CONTAINER_ID redis-cli -h \${redis_host} -p \${redis_port} -a \${redis_pass} ping" "Redis连接测试"
    
    # 检查端口监听
    run_cmd "docker exec $CONTAINER_ID netstat -tuln" "容器内端口监听"
    
    # 检查进程状态
    run_cmd "docker exec $CONTAINER_ID ps aux" "容器内所有进程"
    
    # 健康检查
    run_cmd "docker inspect $CONTAINER_ID --format='{{.State.Health.Status}}'" "容器健康状态"
    
else
    warn "未找到运行中的Trojan Panel容器"
    run_cmd "docker ps -a --filter \"name=trojan-panel\" --filter \"name=jonssonyan/trojan-panel\"" "所有Trojan Panel相关容器"
fi

# 5. 数据库连接测试
log "=== 5. 数据库连接测试 ==="
# 从环境变量或配置中获取数据库连接信息
MYSQL_HOST=${mariadb_ip:-127.0.0.1}
MYSQL_PORT=${mariadb_port:-3306}
MYSQL_USER=${mariadb_user:-root}
MYSQL_PASS=${mariadb_pas:-123456}

REDIS_HOST=${redis_host:-127.0.0.1}
REDIS_PORT=${redis_port:-6379}
REDIS_PASS=${redis_pass:-123456}

run_cmd "mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASS -e \"SELECT 1;\"" "外部MySQL连接测试" || warn "MySQL客户端未安装或连接失败"
run_cmd "redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASS ping" "外部Redis连接测试" || warn "Redis客户端未安装或连接失败"

# 6. 应用服务测试
log "=== 6. 应用服务测试 ==="
SERVER_PORT=${server_port:-8080}
run_cmd "curl -v http://localhost:$SERVER_PORT/api/account/getAccountInfo" "API接口测试" || warn "API接口测试失败"
run_cmd "curl -v http://localhost:$SERVER_PORT/health" "健康检查接口测试" || warn "健康检查测试失败"
run_cmd "curl -v -I http://localhost:$SERVER_PORT" "HTTP头信息测试" || warn "HTTP头信息测试失败"

# 7. 容器内日志文件收集
log "=== 7. 容器内日志文件收集 ==="
if [ -n "$CONTAINER_ID" ]; then
    info "收集容器内日志文件内容..."
    
    # 检查并收集容器内日志文件
    run_cmd "docker exec $CONTAINER_ID find /tpdata/trojan-panel/logs -name '*.log' -exec echo '=== 文件: {} ===' \\; -exec cat {} \\;" "容器内日志文件内容" || warn "无法读取容器内日志文件"
    
    # 检查错误日志
    run_cmd "docker exec $CONTAINER_ID find /tpdata/trojan-panel/logs -name '*.log' -exec grep -l -i error {} \\; 2>/dev/null || echo '未发现错误日志文件'" "错误日志文件列表"
fi

# 8. 系统资源监控
log "=== 8. 系统资源监控 ==="
run_cmd "top -b -n 1 | head -20" "系统进程快照"
run_cmd "iostat" "磁盘I/O统计" || warn "iostat 未安装"
run_cmd "vmstat" "虚拟内存统计"

# 9. Docker守护进程日志
log "=== 9. Docker守护进程日志 ==="
if [ -f "/var/log/docker.log" ]; then
    run_cmd "tail -30 /var/log/docker.log" "Docker守护进程日志"
elif [ -f "/var/log/upstart/docker.log" ]; then
    run_cmd "tail -30 /var/log/upstart/docker.log" "Docker守护进程日志"
elif journalctl --unit=docker &>/dev/null; then
    run_cmd "journalctl --unit=docker --no-pager -n 30" "Docker守护进程日志"
else
    warn "无法找到Docker守护进程日志"
fi

# 10. 生成诊断摘要
log "=== 10. 诊断摘要 ==="
echo "" >> "$LOG_FILE"
echo "==========================================" >> "$LOG_FILE"
echo "              诊断摘要报告" >> "$LOG_FILE"
echo "==========================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# 提取关键信息
echo "【系统信息】" >> "$LOG_FILE"
echo "- 操作系统: $(uname -s)" >> "$LOG_FILE"
echo "- 内核版本: $(uname -r)" >> "$LOG_FILE"
echo "- Docker版本: $(docker --version 2>/dev/null | head -1)" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

echo "【容器状态】" >> "$LOG_FILE"
if [ -n "$CONTAINER_ID" ]; then
    echo "- 容器ID: $CONTAINER_ID" >> "$LOG_FILE"
    echo "- 健康状态: $(docker inspect $CONTAINER_ID --format='{{.State.Health.Status}}' 2>/dev/null || echo '未知')" >> "$LOG_FILE"
    echo "- 运行状态: $(docker inspect $CONTAINER_ID --format='{{.State.Status}}' 2>/dev/null || echo '未知')" >> "$LOG_FILE"
else
    echo "- 未找到运行中的Trojan Panel容器" >> "$LOG_FILE"
fi
echo "" >> "$LOG_FILE"

echo "【主要问题检查】" >> "$LOG_FILE"
echo "1. 容器是否正常运行: $([ -n "$CONTAINER_ID" ] && echo "是" || echo "否")" >> "$LOG_FILE"
echo "2. 二进制文件是否存在: $([ -n "$CONTAINER_ID" ] && (docker exec $CONTAINER_ID test -f /tpdata/trojan-panel/trojan-panel 2>/dev/null && echo "是" || echo "否") || echo "未知")" >> "$LOG_FILE"
echo "3. MySQL客户端可用: $([ -n "$CONTAINER_ID" ] && (docker exec $CONTAINER_ID which mysql >/dev/null 2>&1 && echo "是" || echo "否") || echo "未知")" >> "$LOG_FILE"
echo "4. Redis客户端可用: $([ -n "$CONTAINER_ID" ] && (docker exec $CONTAINER_ID which redis-cli >/dev/null 2>&1 && echo "是" || echo "否") || echo "未知")" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

echo "【建议检查项目】" >> "$LOG_FILE"
echo "1. 检查容器日志中的错误信息" >> "$LOG_FILE"
echo "2. 验证数据库连接配置" >> "$LOG_FILE"
echo "3. 确认环境变量设置正确" >> "$LOG_FILE"
echo "4. 检查端口映射和网络配置" >> "$LOG_FILE"
echo "5. 验证依赖工具安装情况" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# 诊断完成
log "诊断完成！"
log "诊断日志文件: $LOG_FILE"
log ""
log "请将 $LOG_FILE 文件提供给技术支持人员进行分析"
log ""
log "主要检查项："
log "1. 容器是否正常运行 - 查找 '容器详细信息' 部分"
log "2. 应用启动日志 - 查找 '容器完整日志' 部分"
log "3. 数据库连接测试 - 查找 'MySQL连接测试' 和 'Redis连接测试' 部分"
log "4. API接口测试 - 查找 'API接口测试' 部分"
log "5. 环境变量配置 - 查找 '容器环境变量' 部分"
log "6. 依赖工具可用性 - 查找 'MySQL客户端路径' 等部分"

# 显示关键信息摘要
echo ""
echo "=== 诊断摘要 ==="
echo "📋 日志文件: $LOG_FILE"
echo ""
echo "🔍 快速检查建议："
if [ -n "$CONTAINER_ID" ]; then
    health_status=$(docker inspect $CONTAINER_ID --format='{{.State.Health.Status}}' 2>/dev/null || echo "未知")
    echo "   容器健康状态: $health_status"
    
    if [ "$health_status" = "unhealthy" ]; then
        echo "   ❌ 容器健康状态异常，请检查日志"
    fi
else
    echo "   ❌ 未找到运行中的容器"
fi

echo ""
echo "📂 日志文件位置: $LOG_FILE"
echo "📊 文件大小: $(ls -lh $LOG_FILE | awk '{print $5}')"
echo "⏰ 诊断时间: $(date)"