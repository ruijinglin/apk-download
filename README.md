# APK 下载中心

纯静态 APK 分发页面，托管在 Gitee Pages 上。别人打开链接就能选择产品、查看版本、扫码或点击下载 APK。

## 工作原理

```
本地执行 upload.sh ──→ APK + packages.json 提交到 Gitee 仓库
                                     │
其他人访问 Gitee Pages 地址 ←─────────┘
  → 看到产品列表 → 选择构建类型 → 扫码/点击下载
```

不需要服务器，完全依赖 Gitee 仓库 + Gitee Pages 静态托管。

## 使用

### 上传 APK

```bash
./upload.sh <apk文件> <产品名> <版本号> <构建类型> [描述]
```

示例：
```bash
./upload.sh app-release.apk MyApp 1.0.0 release "正式发布"
./upload.sh app-debug.apk   MyApp 1.0.0 debug   "调试版含日志"
./upload.sh app.apk         MyApp 2.0.0 staging  "灰度测试"
```

脚本会自动：
1. 将 APK 复制到 `apks/<产品>/<构建类型>/` 目录
2. 更新 `packages.json` 清单
3. `git commit` + `git push` 到 Gitee

### 下载

其他人直接在浏览器打开 Gitee Pages 地址即可。

## 部署 Gitee Pages

1. 将本仓库推送到 Gitee
2. 进入仓库 → 服务 → Gitee Pages
3. 部署分支选 `main`（或 `master`），目录选 `/`
4. 启动，得到访问地址如 `https://yourname.gitee.io/apk-download`

## 项目结构

```
apk-download/
├── index.html        ← 下载页面
├── style.css         ← 样式
├── app.js            ← 前端逻辑
├── qrcode.min.js     ← 二维码生成（纯前端）
├── packages.json     ← 产品/版本清单（upload.sh 自动维护）
├── upload.sh         ← 本地上传脚本
└── apks/             ← APK 文件存储
    ├── MyApp/
    │   ├── release/
    │   │   └── app-release.apk
    │   └── debug/
    │       └── app-debug.apk
    └── OtherApp/
        └── release/
            └── other.apk
```

## 注意事项

- Gitee 单文件大小限制 100MB，单仓库建议不超过 1GB
- 如果 APK 较大或版本较多，定期清理旧版本
- Gitee Pages 更新后可能有几分钟缓存延迟
