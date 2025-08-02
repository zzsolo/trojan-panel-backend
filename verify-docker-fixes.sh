#!/bin/bash

# 验证Docker构建修复的脚本
echo "🔍 验证 Trojan Panel Docker 构建修复..."

# 检查是否有Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装"
    exit 1
fi

# 进入backend目录
cd trojan-panel-backend

# 检查关键文件是否存在
echo "📋 检查关键文件..."
files=("Dockerfile.optimized" "start.sh" "verify-build.sh" ".github/workflows/docker-build-push.yml")
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file 存在"
    else
        echo "❌ $file 不存在"
    fi
done

# 检查环境变量一致性
echo ""
echo "🔧 检查环境变量配置..."
if grep -q "mariadb_ip" Dockerfile.optimized && grep -q "mariadb_ip" start.sh; then
    echo "✅ 环境变量名称一致"
else
    echo "❌ 环境变量名称不一致"
fi

# 检查依赖工具
echo ""
echo "📦 检查Dockerfile中的依赖..."
if grep -q "mysql-client redis wget" Dockerfile.optimized; then
    echo "✅ 依赖工具已添加"
else
    echo "❌ 依赖工具缺失"
fi

# 检查GitHub Actions配置
echo ""
echo "🚀 检查GitHub Actions配置..."
if grep -q "jonssonyan/trojan-panel" .github/workflows/docker-build-push.yml; then
    echo "✅ 镜像名称正确"
else
    echo "❌ 镜像名称错误"
fi

echo ""
echo "🎉 验证完成！"
echo ""
echo "📝 下一步："
echo "1. 提交代码到GitHub仓库"
echo "2. 检查GitHub Actions构建状态"
echo "3. 验证镜像是否成功推送到Docker Hub"
echo "4. 拉取镜像并测试运行"