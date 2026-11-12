# FlClash Windows 简洁界面源码

基于 FlClash v0.9.2，参考 ClashMi 的简洁信息层级调整 Windows 界面。
应用名称使用 FlClash。程序使用原项目的 Mihomo 内核。

## 修改内容

- Windows 首页改为单列紧凑布局，显示运行状态、连接开关和当前配置。
- 首页集中提供分流模式、系统代理、TUN、订阅管理和节点选择入口。
- Windows 主导航收拢为仪表盘、代理、配置、设置，连接记录等入口放在设置页。
- 使用现有的蓝色主题、灰色背景及卡片样式，移除 Windows 首页的多列监控布局。
- 新增 Windows 界面测试和可手动运行的 GitHub Actions 构建流程。

这是源码包。当前尚未生成或实机验证 Windows 安装包。

## 架构和系统

x64 构建面向常见 Intel、AMD 64 位 Windows 10/11 电脑。
ARM64 构建面向 Windows ARM 电脑，两种架构分别输出安装包。
本改版沿用上游系统要求，尚未进行 Windows 7 或 32 位系统适配。

## 本机编译

在目标架构的 Windows 电脑上准备 Flutter 3.47.6、Go 1.27.1、Rust MSVC、Git、
Visual Studio 的“使用 C++ 的桌面开发”工作负载以及 Inno Setup 6。

将源码解压到普通可写目录，打开 PowerShell，进入该目录并执行下面的命令。

```powershell
.\build-windows.ps1
```

脚本先解析依赖、运行静态分析和 Windows 界面测试，成功后生成 EXE 安装包和 ZIP 便携包。
输出位于 `dist/`。架构按 Windows 构建主机确定。

## GitHub Actions 编译

`.github/workflows/windows-custom.yml` 可以在自己的 GitHub 仓库中手动运行。
流程分别使用 x64 和 ARM64 Windows 构建主机。它只上传构建产物，不创建公开 Release。
完成后在该次运行的 Artifacts 中下载对应架构的安装包和便携包。
该流程尚未实际执行验证。

源码包已包含固定版本的 `core/Clash.Meta` 源码和原始许可证。
如果从保留 Git 子模块的仓库编译，脚本会通过 HTTPS 获取对应子模块。

## 本次验证状态

已进行 Dart 离线格式和语法解析、Git 差异空白检查，以及项目的两项 Git 钩子脚本测试。
新增的界面测试覆盖空配置、连接与停止委托、连接失败后恢复、窗口滚动和主导航入口。
这些 Flutter 测试尚未执行。

Flutter 初始化尝试访问运行环境的云元数据地址，被自动审批拦截。
因此 Flutter 依赖解析、完整静态分析、界面渲染和 Windows 编译仍待在合适的环境中完成。
当前交付物不代表上述检查已通过。

## 上游与许可证

上游版本为 v0.9.2，提交为 `7fd417f`。
Mihomo 子模块固定在 `c5062921054902b25215a6a933e72ccd714c9bfa`。
保留上游 LICENSE 以及各组件原有的许可证和版权说明。
