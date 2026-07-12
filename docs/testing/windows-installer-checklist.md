# Windows 安装版验证清单

验证日期：2026-07-13（Asia/Shanghai）

## 自动化验证

- [x] Rust 单元测试：8 项通过
- [x] 安装规则静态测试：9 项通过
- [x] Windows 原生 release 构建成功
- [x] Inno Setup 成功生成 `Setup.exe`
- [x] 安装到 `C:\Program Files\Screen Time Manager`
- [x] `ScreenTimeManagerService` 状态为 Running
- [x] 服务启动类型为 Automatic
- [x] 服务账户为 LocalSystem
- [x] 服务命令行包含 `--service`
- [x] 强制结束界面进程后，服务重新启动新的界面进程
- [x] 静默卸载后，服务和安装目录均已删除

GitHub Actions 证据：Windows Installer CI 运行 `29214173067`，结论为 success。

## 安全边界

此方案避免依赖“启动应用”列表，并能恢复被普通任务管理器操作结束的界面进程。拥有管理员权限的用户仍然可以停止或删除 Windows 服务、卸载程序或修改系统权限；应用不能对本机管理员形成绝对防护。
