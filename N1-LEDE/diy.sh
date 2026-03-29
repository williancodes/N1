#!/bin/bash
# =========================================================
# Description: N1-LEDE DIY Script (Targeting Lean Tag 20230609)
# =========================================================

# 1. 物理删除不需要的默认组件 (保持旁路由极致精简)
echo ">> Removing unwanted packages..."
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/packages/net/passwall
rm -rf feeds/luci/applications/luci-app-ssr-plus
rm -rf feeds/luci/applications/luci-app-vssr
rm -rf feeds/luci/applications/luci-app-bypass
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-argon-config

# 2. 修复 Lean 20230609 版本中 baresip 的递归依赖报错 (致命错误)
# N1 旁路由无需 VoIP(网络电话) 功能，直接物理断根，防止 make defconfig 死循环
echo ">> Fixing recursive dependency for baresip..."
find feeds/ -name "baresip" -type d -exec rm -rf {} +

# 3. 修改默认 IP 为 10.0.0.2
echo ">> Setting default IP to 10.0.0.2..."
sed -i 's/192.168.1.1/10.0.0.2/g' package/base-files/files/bin/config_generate

# 4. 安装指定版本的 OpenClash (v0.46.011-beta)
echo ">> Installing OpenClash v0.46.011-beta..."
rm -rf package/luci-app-openclash
git clone --depth=1 --branch v0.46.011-beta https://github.com/vernesong/OpenClash.git /tmp/OpenClash
cp -rf /tmp/OpenClash/luci-app-openclash package/luci-app-openclash
rm -rf /tmp/OpenClash

# =========================================================
# 5. 企业级防断网下载：预置 OpenClash ARM64 Meta & Dev 内核
# =========================================================
echo ">> Downloading and pre-installing OpenClash Cores..."
CORE_DIR="package/base-files/files/etc/openclash/core"
mkdir -p $CORE_DIR

# 封装健壮的下载函数：包含镜像加速、格式校验和失败回退机制
download_core() {
    local url=$1
    local dest=$2
    
    echo "Downloading core from ghproxy mirror..."
    # 尝试使用 ghproxy 镜像加速下载 (加上重试和超时限制)
    curl -sL --retry 3 --connect-timeout 10 "https://mirror.ghproxy.com/$url" -o /tmp/clash.tar.gz
    
    # 防御性编程：验证文件是否存在、大小是否大于0，以及是否为合法压缩包
    if [ ! -s /tmp/clash.tar.gz ] || ! tar -tzf /tmp/clash.tar.gz >/dev/null 2>&1; then
        echo "Mirror failed or file corrupted, falling back to original GitHub URL..."
        curl -sL --retry 3 --connect-timeout 10 "$url" -o /tmp/clash.tar.gz
    fi
    
    # 确保成功后才执行解压，避免报错
    if tar -tzf /tmp/clash.tar.gz >/dev/null 2>&1; then
        tar -xzf /tmp/clash.tar.gz -C /tmp/
        mv /tmp/clash $dest
        rm -f /tmp/clash.tar.gz
        echo "Core installed: $dest"
    else
        echo "ERROR: Failed to download valid core archive!"
    fi
}

# 依次下载 Meta 与 Dev 内核
download_core "https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz" "$CORE_DIR/clash_meta"
download_core "https://raw.githubusercontent.com/vernesong/OpenClash/core/master/dev/clash-linux-arm64.tar.gz" "$CORE_DIR/clash"

# 赋予内核可执行权限 (非常重要，否则开机无法启动)
chmod +x $CORE_DIR/clash_meta
chmod +x $CORE_DIR/clash
echo ">> OpenClash Cores processing finished!"

# 6. 安装必需的主题与 Amlogic 插件
echo ">> Installing Themes and amlogic..."
git clone -b 18.06 --single-branch --depth 1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone -b 18.06 --single-branch --depth 1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config
git clone --depth=1 https://github.com/ophub/luci-app-amlogic package/amlogic

# 7. 修复旧版 Argon 主题时间的默认格式显示问题
sed -i 's/os.date()/os.date("%Y-%m-%d %H:%M:%S %A")/g' $(find ./package/*/autocore/files/ -type f -name "index.htm" 2>/dev/null)
