#!/bin/bash
# =========================================================
# Description: N1-LEDE DIY Script (Targeting Lean Tag 20230609)
# =========================================================

# =========================================================
# 0. "时光机"：同步降级所有 Feeds 到 2023年6月9日 (核心护城河)
# =========================================================
echo ">> Synchronizing feeds to match 2023-06-09 base code..."
for feed_dir in feeds/*; do
    if[ -d "$feed_dir/.git" ]; then
        cd "$feed_dir"
        echo "Fetching full history for $feed_dir..."
        git fetch --unshallow 2>/dev/null || git fetch --all
        target_commit=$(git rev-list -n 1 --before="2023-06-10 00:00:00" HEAD)
        
        # ！！！注意：这里已经加上了至关重要的空格 ！！！
        if [ -n "$target_commit" ]; then
            echo "Rewinding $feed_dir to commit $target_commit..."
            git checkout -b stable_2023 "$target_commit"
        fi
        cd ../..
    fi
done

# 重新安装降级后的依赖树 (极其重要)
./scripts/feeds install -a

# =========================================================
# 1. 物理删除不需要的组件与引发警告的历史遗留包
# =========================================================
echo ">> Removing unwanted packages..."
rm -rf feeds/telephony
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/packages/net/passwall
rm -rf feeds/luci/applications/luci-app-ssr-plus
rm -rf feeds/luci/applications/luci-app-vssr
rm -rf feeds/luci/applications/luci-app-bypass
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-argon-config

# =========================================================
# 2. 修改默认 IP 为 10.0.0.2
# =========================================================
echo ">> Setting default IP to 10.0.0.2..."
sed -i 's/192.168.1.1/10.0.0.2/g' package/base-files/files/bin/config_generate

# =========================================================
# 3. 安装指定版本的 OpenClash (v0.46.011-beta)
# =========================================================
echo ">> Installing OpenClash v0.46.011-beta..."
rm -rf package/luci-app-openclash
git clone --depth=1 --branch v0.46.011-beta https://github.com/vernesong/OpenClash.git /tmp/OpenClash
cp -rf /tmp/OpenClash/luci-app-openclash package/luci-app-openclash
rm -rf /tmp/OpenClash

# =========================================================
# 4. 企业级防断网下载：预置 OpenClash ARM64 Meta & Dev 内核
# =========================================================
echo ">> Downloading and pre-installing OpenClash Cores..."
CORE_DIR="package/base-files/files/etc/openclash/core"
mkdir -p "$CORE_DIR"

download_core() {
    local url=$1
    local dest=$2
    echo "Downloading core from ghproxy mirror..."
    curl -sL --retry 3 --connect-timeout 10 "https://mirror.ghproxy.com/$url" -o /tmp/clash.tar.gz
    
    # ！！！注意：这里同样确保了有空格 ！！！
    if[ ! -s /tmp/clash.tar.gz ] || ! tar -tzf /tmp/clash.tar.gz >/dev/null 2>&1; then
        echo "Mirror failed or file corrupted, falling back to original GitHub URL..."
        curl -sL --retry 3 --connect-timeout 10 "$url" -o /tmp/clash.tar.gz
    fi
    
    # 再次安全校验并解压
    if tar -tzf /tmp/clash.tar.gz >/dev/null 2>&1; then
        tar -xzf /tmp/clash.tar.gz -C /tmp/
        mv /tmp/clash "$dest"
        rm -f /tmp/clash.tar.gz
        echo "Core installed: $dest"
    else
        echo "ERROR: Failed to download valid core archive!"
    fi
}

# N1 为 ARM64 架构，拉取专属核心
download_core "https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz" "$CORE_DIR/clash_meta"
download_core "https://raw.githubusercontent.com/vernesong/OpenClash/core/master/dev/clash-linux-arm64.tar.gz" "$CORE_DIR/clash"

# 赋予内核可执行权限 (非常重要，否则开机无法启动)
chmod +x "$CORE_DIR/clash_meta"
chmod +x "$CORE_DIR/clash"
echo ">> OpenClash Cores processing finished!"

# =========================================================
# 5. 安装必需的主题与 Amlogic 插件
# =========================================================
echo ">> Installing Themes and amlogic..."
git clone -b 18.06 --single-branch --depth 1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone -b 18.06 --single-branch --depth 1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config
git clone --depth=1 https://github.com/ophub/luci-app-amlogic package/amlogic

# =========================================================
# 6. 修复旧版 Argon 主题时间的默认格式显示问题
# =========================================================
sed -i 's/os.date()/os.date("%Y-%m-%d %H:%M:%S %A")/g' $(find ./package/*/autocore/files/ -type f -name "index.htm" 2>/dev/null)
