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

# 2. 修改默认 IP 为 10.0.0.2 (旁路由网关、DNS 预设已在 files 中搞定，此处打底)
echo ">> Setting default IP to 10.0.0.2..."
sed -i 's/192.168.1.1/10.0.0.2/g' package/base-files/files/bin/config_generate

# 3. 安装指定版本的 OpenClash (v0.46.011-beta)
echo ">> Installing OpenClash v0.46.011-beta..."
rm -rf package/luci-app-openclash
git clone --depth=1 --branch v0.46.011-beta https://github.com/vernesong/OpenClash.git /tmp/OpenClash
cp -rf /tmp/OpenClash/luci-app-openclash package/luci-app-openclash
rm -rf /tmp/OpenClash

# =========================================================
# 4. 重点：预置 OpenClash ARM64 Meta & Dev 内核 (核心护城河)
# =========================================================
echo ">> Downloading and pre-installing OpenClash Cores..."
CORE_DIR="package/base-files/files/etc/openclash/core"
mkdir -p $CORE_DIR

# 下载 Meta 内核 (N1 为 aarch64 / arm64 架构)
curl -sL https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz | tar xz -C /tmp/
mv /tmp/clash $CORE_DIR/clash_meta
# 下载 Dev 内核备用
curl -sL https://raw.githubusercontent.com/vernesong/OpenClash/core/master/dev/clash-linux-arm64.tar.gz | tar xz -C /tmp/
mv /tmp/clash $CORE_DIR/clash

# 赋予内核可执行权限 (非常重要，否则开机无法启动)
chmod +x $CORE_DIR/clash_meta
chmod +x $CORE_DIR/clash
echo ">> OpenClash Cores installed successfully!"

# 5. 安装必需的主题与 Amlogic 插件
echo ">> Installing Themes and amlogic..."
git clone -b 18.06 --single-branch --depth 1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone -b 18.06 --single-branch --depth 1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config
git clone --depth=1 https://github.com/ophub/luci-app-amlogic package/amlogic

# 6. 修复旧版 Argon 主题时间的默认格式显示问题
sed -i 's/os.date()/os.date("%Y-%m-%d %H:%M:%S %A")/g' $(find ./package/*/autocore/files/ -type f -name "index.htm" 2>/dev/null)
