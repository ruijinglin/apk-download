#!/bin/bash
#
# APK 管理脚本
# 用于修改产品名、修改备注、标记线上版、删除版本等操作
#
# 用法:
#   ./manage.sh rename-product <旧名> <新名>
#   ./manage.sh set-description <产品名> <描述>
#   ./manage.sh mark-online <产品名> <构建类型> <版本号>
#   ./manage.sh edit-version <产品名> <构建类型> <版本号> <新描述>
#   ./manage.sh delete-version <产品名> <构建类型> <版本号>
#   ./manage.sh list
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
META="${REPO_DIR}/packages.json"

if [ $# -lt 1 ]; then
  echo -e "${CYAN}APK 管理工具${NC}"
  echo ""
  echo "用法:"
  echo "  $0 list                                          查看所有产品和版本"
  echo "  $0 rename-product <旧名> <新名>                  重命名产品"
  echo "  $0 set-description <产品名> <描述>               修改产品描述"
  echo "  $0 mark-online <产品名> <构建类型> <版本号>       标记为线上版本"
  echo "  $0 edit-version <产品名> <构建类型> <版本号> <描述> 修改版本备注"
  echo "  $0 delete-version <产品名> <构建类型> <版本号>    删除某个版本"
  echo "  $0 push                                          提交并推送变更"
  exit 1
fi

ACTION="$1"
shift

case "$ACTION" in

  list)
    python3 << 'EOF'
import json

with open("packages.json", 'r') as f:
    data = json.load(f)

products = data.get('products', {})
if not products:
    print("  暂无产品")
else:
    for name, p in products.items():
        desc = p.get('description', '')
        print(f"\n  📦 {name}" + (f" - {desc}" if desc else ""))
        for bt, versions in p.get('builds', {}).items():
            print(f"    [{bt}]")
            for v in versions:
                online = " ⭐线上" if v.get('isOnline') else ""
                print(f"      v{v['version']} - {v['filename']} ({v.get('description', '')}){online}")
EOF
    ;;

  rename-product)
    OLD_NAME="$1"
    NEW_NAME="$2"
    if [ -z "$OLD_NAME" ] || [ -z "$NEW_NAME" ]; then
      echo -e "${RED}用法: $0 rename-product <旧名> <新名>${NC}"
      exit 1
    fi

    python3 << EOF
import json, sys

with open("packages.json", 'r') as f:
    data = json.load(f)

products = data.get('products', {})
if '${OLD_NAME}' not in products:
    print(f"  错误: 产品 '${OLD_NAME}' 不存在")
    sys.exit(1)
if '${NEW_NAME}' in products:
    print(f"  错误: 产品 '${NEW_NAME}' 已存在")
    sys.exit(1)

# 重命名产品
p = products.pop('${OLD_NAME}')
p['name'] = '${NEW_NAME}'

# 更新所有 downloadUrl
for bt, versions in p.get('builds', {}).items():
    for v in versions:
        v['downloadUrl'] = v['downloadUrl'].replace('apks/${OLD_NAME}/', 'apks/${NEW_NAME}/')

products['${NEW_NAME}'] = p

with open("packages.json", 'w') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("  ✓ 已重命名: ${OLD_NAME} → ${NEW_NAME}")
EOF

    # 重命名文件夹
    if [ -d "${REPO_DIR}/apks/${OLD_NAME}" ]; then
      mv "${REPO_DIR}/apks/${OLD_NAME}" "${REPO_DIR}/apks/${NEW_NAME}"
      echo -e "${GREEN}  ✓ 文件夹已重命名${NC}"
    fi
    ;;

  set-description)
    PRODUCT="$1"
    DESC="$2"
    if [ -z "$PRODUCT" ] || [ -z "$DESC" ]; then
      echo -e "${RED}用法: $0 set-description <产品名> <描述>${NC}"
      exit 1
    fi

    python3 << EOF
import json, sys

with open("packages.json", 'r') as f:
    data = json.load(f)

products = data.get('products', {})
if '${PRODUCT}' not in products:
    print(f"  错误: 产品 '${PRODUCT}' 不存在")
    sys.exit(1)

products['${PRODUCT}']['description'] = '${DESC}'

with open("packages.json", 'w') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("  ✓ 已更新 ${PRODUCT} 的描述")
EOF
    ;;

  mark-online)
    PRODUCT="$1"
    BUILD_TYPE="$2"
    VERSION="$3"
    if [ -z "$PRODUCT" ] || [ -z "$BUILD_TYPE" ] || [ -z "$VERSION" ]; then
      echo -e "${RED}用法: $0 mark-online <产品名> <构建类型> <版本号>${NC}"
      exit 1
    fi

    python3 << EOF
import json, sys

with open("packages.json", 'r') as f:
    data = json.load(f)

products = data.get('products', {})
if '${PRODUCT}' not in products:
    print("  错误: 产品不存在")
    sys.exit(1)

builds = products['${PRODUCT}'].get('builds', {}).get('${BUILD_TYPE}', [])
if not builds:
    print("  错误: 构建类型不存在")
    sys.exit(1)

found = False
for v in builds:
    if v['version'] == '${VERSION}':
        v['isOnline'] = True
        found = True
    else:
        v.pop('isOnline', None)

if not found:
    print("  错误: 版本 ${VERSION} 不存在")
    sys.exit(1)

with open("packages.json", 'w') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("  ✓ 已标记 ${PRODUCT}/${BUILD_TYPE}/v${VERSION} 为线上版本")
EOF
    ;;

  edit-version)
    PRODUCT="$1"
    BUILD_TYPE="$2"
    VERSION="$3"
    NEW_DESC="$4"
    if [ -z "$PRODUCT" ] || [ -z "$BUILD_TYPE" ] || [ -z "$VERSION" ] || [ -z "$NEW_DESC" ]; then
      echo -e "${RED}用法: $0 edit-version <产品名> <构建类型> <版本号> <新描述>${NC}"
      exit 1
    fi

    python3 << EOF
import json, sys

with open("packages.json", 'r') as f:
    data = json.load(f)

builds = data.get('products', {}).get('${PRODUCT}', {}).get('builds', {}).get('${BUILD_TYPE}', [])
found = False
for v in builds:
    if v['version'] == '${VERSION}':
        v['description'] = '${NEW_DESC}'
        found = True
        break

if not found:
    print("  错误: 找不到该版本")
    sys.exit(1)

with open("packages.json", 'w') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("  ✓ 已更新版本描述")
EOF
    ;;

  delete-version)
    PRODUCT="$1"
    BUILD_TYPE="$2"
    VERSION="$3"
    if [ -z "$PRODUCT" ] || [ -z "$BUILD_TYPE" ] || [ -z "$VERSION" ]; then
      echo -e "${RED}用法: $0 delete-version <产品名> <构建类型> <版本号>${NC}"
      exit 1
    fi

    python3 << EOF
import json, sys

with open("packages.json", 'r') as f:
    data = json.load(f)

builds = data.get('products', {}).get('${PRODUCT}', {}).get('builds', {}).get('${BUILD_TYPE}', [])
original_len = len(builds)
new_builds = [v for v in builds if v['version'] != '${VERSION}']

if len(new_builds) == original_len:
    print("  错误: 找不到该版本")
    sys.exit(1)

# 找到被删除的文件名
removed = [v for v in builds if v['version'] == '${VERSION}']
filename = removed[0]['filename'] if removed else None

data['products']['${PRODUCT}']['builds']['${BUILD_TYPE}'] = new_builds

# 清理空构建类型
if not new_builds:
    del data['products']['${PRODUCT}']['builds']['${BUILD_TYPE}']

# 清理空产品
if not data['products']['${PRODUCT}']['builds']:
    del data['products']['${PRODUCT}']

with open("packages.json", 'w') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

if filename:
    print(f"FILENAME:{filename}")
print("  ✓ 已删除版本记录")
EOF

    # 删除 APK 文件
    RESULT=$(python3 -c "
import json
with open('packages.json','r') as f: pass
" 2>&1 || true)
    APK_PATH="${REPO_DIR}/apks/${PRODUCT}/${BUILD_TYPE}"
    # 尝试根据版本找文件并删除
    if [ -d "$APK_PATH" ]; then
      echo -e "  ${YELLOW}提示: 如需删除 APK 文件请手动删除 ${APK_PATH} 下对应文件${NC}"
    fi
    ;;

  push)
    echo -e "${GREEN}提交并推送变更...${NC}"
    cd "$REPO_DIR"
    git add -A
    git commit -m "📝 更新包信息" || echo "无变更需要提交"
    git push
    echo -e "${GREEN}✓ 已推送${NC}"
    ;;

  *)
    echo -e "${RED}未知操作: ${ACTION}${NC}"
    echo "运行 $0 查看帮助"
    exit 1
    ;;
esac
