# ubuntu-env-setup

Ubuntu 22.04 开发环境一键安装脚本。一条命令装好中文支持、浏览器、编辑器、串口调试助手和终端。

## 安装内容

| 组件 | 说明 |
|------|------|
| 中文支持 | 中文字体（Noto CJK / 文泉驿）+ fcitx5 拼音输入法 + `zh_CN.UTF-8` locale |
| Google Chrome | 官网 amd64 `.deb`（仅 x86_64，arm64 自动跳过） |
| Visual Studio Code | 微软官方 apt 源（amd64 / arm64） |
| CuteCom | 串口调试助手（universe 源） |
| Terminator | 多窗口终端 |

## 用法

在目标 Ubuntu 22.04 机器上：

```bash
# 下载/拷贝脚本后执行
sudo bash install.sh

# 或
chmod +x install.sh && sudo ./install.sh
```

- 脚本**可重复执行（幂等）**。
- 需要联网；安装 Chrome 时国内请先开代理：
  ```bash
  export https_proxy=http://127.0.0.1:7897   # 按你的 Clash 端口改
  sudo -E bash install.sh
  ```

## 配置

脚本顶部「配置区」可开关各组件：

```bash
INSTALL_CHINESE=true      # 中文支持
SET_ZH_LOCALE=false       # true=系统界面也切成中文(重启生效)
INSTALL_CHROME=true       # Google Chrome
INSTALL_VSCODE=true       # VS Code
INSTALL_CUTECOM=true      # CuteCom
INSTALL_TERMINATOR=true   # Terminator
```

## 安装后

- **重启或重新登录**，使中文输入法 / 串口权限生效。
- fcitx5 未自启时运行 `fcitx5 -d`，并在「设置 → 键盘/输入法」确认「中文(智能拼音)」已添加。
- 串口访问需要用户在 `dialout` 组（脚本已自动添加，重新登录生效）。
- 串口设备一般为 `/dev/ttyUSB0` 或 `/dev/ttyACM0`。

## 许可证

[MIT](./LICENSE)
