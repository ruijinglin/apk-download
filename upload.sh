#!/bin/bash
#
# APK 上传脚本（Gitee Pages 静态方案）
#
# 工作原理：
#   1. 将 APK 文件复制到本仓库的 apks/<产品>/<构建类型>/ 目录
#   2. 更新 packages.json 清单
#   3. git add + commit + push 到 Gitee
#   4. 别人通过 Gitee Pages 打开页面即可下载
#
# 用法: ./upload.sh <apk文件> <产品名> <版本号> <构建类型> [描述]
#
# 示例:
#   ./upload.sh app-release.apk MyApp 1.0.0 release "正式版"
#   ./upload.sh app-debug.apk MyApp 1.0.0 debug "调试包"
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 本脚本所在目录（即仓库根目录）
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ $# -lt 4 ]; then
  echo -e "${CYAN}╔═══════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║   📦 APK 上传到 Gitee 仓库                ║${NC}"
  echo -e "${CYAN}╚═══════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${YELLOW}用法:${NC} $0 <apk文件> <产品名> <版本号> <构建类型> [描述]"
  echo ""
  echo "  apk文件   - APK 文件路径"
  echo "  产品名    - 产品名称（如 MyApp）"
  echo "  版本号    - 如 1.0.0, 2.1.3-beta"
  echo "  构建类型  - release / debug / staging / beta 等"
  echo "  描述      - 可选，版本描述"
  echo ""
  echo -e "${GREEN}示例:${NC}"
  echo "  $0 ./app/build/outputs/apk/release/app-release.apk MyApp 1.0.0 release \"首次发布\""
  echo "  $0 app-debug.apk MyApp 1.0.0 debug \"含日志调试版\""
  exit 1
fi

APK_FILE="$1"
PRODUCT="$2"
VERSION="$3"
BUILD_TYPE="$4"
DESCRIPTION="${5:-}"

# 检查文件
if [ ! -f "$APK_FILE" ]; then
  echo -e "${RED}✗ 文件不存在:${NC} $APK_FILE"
  exit 1
fi

FILENAME=$(basename "$APK_FILE")
FILE_SIZE=$(stat -f%z "$APK_FILE" 2>/dev/null || stat -c%s "$APK_FILE" 2>/dev/null)
FILE_SIZE_HR=$(ls -lh "$APK_FILE" | awk '{print $5}')

# 目标目录
DEST_DIR="${REPO_DIR}/apks/${PRODUCT}/${BUILD_TYPE}"
mkdir -p "$DEST_DIR"

echo ""
echo -e "${CYAN}┌─────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}  📦 上传 APK 到 Gitee 仓库"
echo -e "${CYAN}├─────────────────────────────────────────────┤${NC}"
echo -e "${CYAN}│${NC}  文件: ${FILENAME} (${FILE_SIZE_HR})"
echo -e "${CYAN}│${NC}  产品: ${PRODUCT}"
echo -e "${CYAN}│${NC}  版本: v${VERSION}"
echo -e "${CYAN}│${NC}  类型: ${BUILD_TYPE}"
echo -e "${CYAN}│${NC}  描述: ${DESCRIPTION:-无}"
echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"
echo ""

# 1. 复制 APK 到仓库
echo -e "${GREEN}[1/4]${NC} 复制 APK 文件..."
cp "$APK_FILE" "$DEST_DIR/$FILENAME"

# 2. 更新 packages.json
echo -e "${GREEN}[2/4]${NC} 更新 packages.json..."
UPLOAD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DOWNLOAD_URL="apks/${PRODUCT}/${BUILD_TYPE}/${FILENAME}"

# 使用 python3 更新 JSON（保证格式正确）
python3 << EOF
import json, os

meta_path = os.path.join("${REPO_DIR}", "packages.json")

with open(meta_path, 'r') as f:
    data = json.load(f)

products = data.setdefault('products', {})
product = products.setdefault('${PRODUCT}', {'name': '${PRODUCT}', 'description': '', 'builds': {}})
builds = product['builds'].setdefault('${BUILD_TYPE}', [])

version_info = {
    'version': '${VERSION}',
    'filename': '${FILENAME}',
    'description': '${DESCRIPTION}',
    'buildType': '${BUILD_TYPE}',
    'size': ${FILE_SIZE},
    'uploadTime': '${UPLOAD_TIME}',
    'downloadUrl': '${DOWNLOAD_URL}'
}

# 检查是否已存在相同版本+文件名，有则覆盖
existing_idx = None
for i, v in enumerate(builds):
    if v['version'] == '${VERSION}' and v['filename'] == '${FILENAME}':
        existing_idx = i
        break

if existing_idx is not None:
    builds[existing_idx] = version_info
else:
    builds.insert(0, version_info)

with open(meta_path, 'w') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("  packages.json 已更新")
EOF

# 3. Git commit
echo -e "${GREEN}[3/4]${NC} Git commit..."
cd "$REPO_DIR"
git add "apks/${PRODUCT}/${BUILD_TYPE}/${FILENAME}" packages.json
git commit -m "📦 ${PRODUCT} v${VERSION} (${BUILD_TYPE}) - ${DESCRIPTION:-更新}"

# 4. Git push
echo -e "${GREEN}[4/4]${NC} Git push..."
git push

echo ""
echo -e "${GREEN}✓ 上传完成！${NC}"
echo ""
echo -e "  APK 已推送到 Gitee 仓库，刷新页面即可看到更新。"
echo ""
