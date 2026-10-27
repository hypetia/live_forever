# REA研究记录：Windows Steam《这是我的战争》

当前状态：**已阅读并实际运行REA；尚未取得原作文件，没有完成《这是我的战争》的逆向，也没有把猜测写成原作机制。** 用户已确认目标是Windows Steam版，Final Cut与具体构建号尚待文件确认。

## 已完成的工具验证

- 阅读官方[morluto/rea](https://github.com/morluto/rea)、CLI、桌面目录检查、原生二进制分析和安装文档。研究时仓库提交为`79b8219f290ef6304e469d9b8c40dc2af30edba9`，软件包版本6.8.0、MIT许可。
- 从npm官方注册表将REA 6.8.0和兼容的Node 24.22.1装入独立研究目录，没有改动聊天客户端的MCP注册或全局Node。正常游戏不依赖这些分析工具。
- 实际用`inspect-desktop-application`检查本项目v1.6 Windows包：观察到x86-64 PE头和内嵌Godot PCK头，数据包引擎版本4.6.3。此结论仅属于我们的包，不是原作的引擎结论。
- 实际用`inspect-pe-imports`读取同一程序的导入表。默认64 MiB预算小于该程序，已在研究脚本中按所选文件大小显式设置`--max-file-bytes`。
- Ghidra readiness检查返回`missing_analysis_engine`。当前JDK21存在，但Ghidra未安装；获取官方GitHub Release元数据的请求被网络代理以403拒绝。尚未运行Ghidra原生反编译或原作动态观察。

工具验证摘要见[rea-v17-tool-verification.json](rea-v17-tool-verification.json)。原始证据保存在独立研究目录，摘要列出哈希与能力边界。

## 原作文件需要怎样提供

Steam库右键游戏 → 管理 → 浏览本地文件。先提供主程序EXE、同目录的游戏／引擎DLL，和可选的版本说明。安装目录若有多个EXE或较多DLL，先发文件清单，按清单选择真正承载逻辑的模块。数据包与配置表在确定程序引用后再按需提供。无需Steam账号或密码。

如果文件不便上传，也可在持有游戏的Windows电脑安装受REA支持的Node和Ghidra，再运行只读检查，将生成的证据报告发来。目录检查不会运行游戏、解包归档或跟随子目录符号链接。

## 研究入口

仓库提供`tools/rea_research.py`，接收用户指定的安装目录或主程序，结果写入源码仓库外的新目录，避免覆盖既有证据。它记录工具命令、退出码、报告哈希和所选程序的完整文件哈希。Node运行环境需要满足REA要求；目前验证版本为24.22.1。

```bash
python tools/rea_research.py "/path/to/This War of Mine/main.exe" \
  --output /private/research/twom-steam \
  --rea /path/to/rea-agents/scripts/rea.mjs \
  --node /path/to/supported-node
```

也可安装REA CLI后省略`--rea`和`--node`。普通检查执行安装目录识别与所选PE文件的导入表读取，不启动目标游戏。配置`GHIDRA_INSTALL_DIR`与匹配的JDK后，可添加`--native`；脚本先检查provider就绪情况，不就绪时保留诊断并明确退出，不声称反编译成功。

## 拿到文件后的调查顺序

1. 校验具体版本、架构、程序与支持模块的哈希，识别实际引擎和逻辑载体。
2. 查找背包／容器／物品相关字符串、资源引用和数据表，定位堆叠上限、容量计算及转移边界。
3. 分别追踪鼠标交互范围、移动寻路、搜索进度、动作取消和离场确认。
4. 追踪昼夜状态切换、时间推进、守夜与睡眠结算，并检查存档恢复边界。
5. 追踪潜行、声音、警觉、攻击前摇、命中与装备效果；通过实际运行观察交叉核对。
6. 将每条结论标为已观察、代码推导或仍待确认，再把有证据的行为独立实现到本游戏。

REA的反编译与引用结果不是原始完整源码；优化、脚本数据、资源文件和运行条件都可能影响结论。当前背包上限是本游戏独立设计，不以本次工具自检冒充原作研究。
