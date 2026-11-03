# SubnetDesk Helper · Deploy · Agent

这是由 [Aysar94-prog](https://github.com/Aysar94-prog) 维护的定制源码版本，默认分支为 **master**。

本仓库包含 Helper、Deploy 管理控制台和 Windows Agent，以及本地网络连接、Receiver-only 安装策略、登录重试会话范围保护和 Windows 终端文本输入修复。

| 组件 | 当前源码中的构建设置 |
| --- | --- |
| Helper | 1.4.7 · Build 125 |
| Deploy | 1.10.1 · Build 125 |
| Agent | 1.7.0 |

这些是源码中的构建设置；最新修复需要重新构建安装包。此账号尚未发布安装包，上游发行包不代表这里的定制产品。

## 获取源码

```sh
git clone https://github.com/Aysar94-prog/SubnetDesk.git source
cd source
```

`hbb_common` 已直接包含在 `libs/hbb_common/`，不需要子模块或第二个仓库。仓库仅包含源码、测试和构建脚本；本地工具、缓存、安装包和运行时凭据不上传。

请阅读 [AGENTS.md](AGENTS.md)、[工作目录说明](docs/WORKSPACE_LAYOUT.md) 和 [Deploy/Agent 文档](deployment/README.md)。部分 Windows 构建脚本使用本地工具路径，需要按构建环境配置。

## 项目来源和许可证

此定制版本基于 [上游 SubnetDesk](https://github.com/zibo-chen/SubnetDesk) 和 [RustDesk](https://github.com/rustdesk/rustdesk)。GitHub 的 fork 标记表示项目来源，并不表示本分支仍是上游原版。

保留原始贡献者权利，遵循 [GNU Affero General Public License v3.0](LICENCE)。

[العربية / 项目主页](README.md)
