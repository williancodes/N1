#!/bin/bash
# =========================================================
# Description: N1-LEDE DIY Script
# =========================================================

# 1. 物理删除不需要的默认组件 (Passwall, SSR-Plus 等)
# 在拉取完 feeds 后执行物理删除，防止被 make defconfig 自动勾选依赖
echo ">> Removing unwanted packages..."
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/packages/net/passwall
rm -rf feeds/luci/applications/luci-app-ssr-plus
rm -rf feeds/luci/applications/luci-app-vssr
rm -rf feeds/luci/applications/luci-app-bypass
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-argon-config

# 2. 修改默认 IP 为 10.0.0.2 (防御性编程：确保基础环境也被修改)
echo ">> Setting default IP to 10.0.0.2..."
sed -i 's/192.168.1.1/10.0.0.2/g' package/base-files/files/bin/config_generate

# 3. 安装指定版本的 OpenClash (修复目录结构识别错误)
echo ">> Installing OpenClash (v0.46.011-beta)..."
rm -rf package/luci-app-openclash
# 克隆到临时目录
git clone --depth=1 --branch v0.46.011-beta https://github.com/vernesong/OpenClash.git /tmp/OpenClash
# 仅将需要的 luci-app-openclash 文件夹移动到 package 目录
cp -rf /tmp/OpenClash/luci-app-openclash package/luci-app-openclash
rm -rf /tmp/OpenClash

# 4. 安装其他必需包 (主题等)
echo ">> Installing Themes and amlogic..."
git clone -b 18.06 --single-branch --depth 1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone -b 18.06 --single-branch --depth 1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config
git clone --depth=1 https://github.com/ophub/luci-app-amlogic package/amlogic

# 5. 优化默认时间格式
sed -i 's/os.date()/os.date("%Y-%m-%d %H:%M:%S %A")/g' $(find ./package/*/autocore/files/ -type f -name "index.htm" 2>/dev/null)
