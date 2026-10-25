# Live Forever · 留一盏灯 v1.0

单人末日生存游戏。这版重构了日常循环：**白天在避难所直接控制人物生活和建设 → 夜间分配搜刮、守夜与睡眠 → 选择装备出发 → 带着物资走回入口 → 清晨查看一夜结果，再开始新一天。**

人物与房屋仍采用原创几何画面。这次改的是操作和规则，不能据此声称已达到《这是我的战争》的整体成熟度或完整内容规模。

## 下载后直接玩

| 用途 | GitHub直接下载 | 使用方法 |
| --- | --- | --- |
| Windows 64位游戏 | [live_forever_v10_windows_x64.zip](https://github.com/hypetia/live_forever/raw/refs/heads/downloads-v1.0.0/live_forever_v10_windows_x64.zip) | 完整解压，双击 `LiveForever.exe` |
| Linux x86_64游戏 | [live_forever_v10_linux_x64.zip](https://github.com/hypetia/live_forever/raw/refs/heads/downloads-v1.0.0/live_forever_v10_linux_x64.zip) | 完整解压，运行 `LiveForever.x86_64` |
| Windows一键验收工具 | [live_forever_v10_windows_acceptance.zip](https://github.com/hypetia/live_forever/raw/refs/heads/downloads-v1.0.0/live_forever_v10_windows_acceptance.zip) | 主动运行 `windows_acceptance.cmd`，默认约30分钟 |
| v1.0完整源码 | [live_forever_shelter_m10.zip](https://github.com/hypetia/live_forever/raw/refs/heads/downloads-v1.0.0/live_forever_shelter_m10.zip) | Godot **4.6.3标准版**导入 `project.godot`，按F5 |

普通运行包不需要Godot、Python、登录、服务器或持续联网。Windows验收工具与普通游戏分开；正常游戏不会替你自动操作。Windows包已按官方模板导出，**尚未在Windows实际设备完成验收**。

[全部下载文件](https://github.com/hypetia/live_forever/tree/downloads-v1.0.0) · [SHA-256校验文件](https://github.com/hypetia/live_forever/raw/refs/heads/downloads-v1.0.0/v1.0.0-SHA256SUMS.txt) · [最新main源码ZIP](https://github.com/hypetia/live_forever/archive/refs/heads/main.zip)

运行包和版本源码ZIP已上传到独立的`downloads-v1.0.0`分支；`main`保留开发源码。当前环境GitHub Releases接口受限，因此这些文件托管在下载分支，**不是GitHub Release附件**。旧版下载分支保留。

![真实操作：白天生活与场景建设](docs/v10-day.png)

## 从白天开始

1. 点击人物或底部卡片选人。**左键地面走动，双击奔跑，右键取消**；跨楼层沿楼梯走。点击人物头顶的设施图标，可避免点到站在设施旁的人。
2. **床位直接休息，餐桌直接吃饭，水桶会先走过去再饮水。**做饭和制作先点击灶台／工作台，在设施面板选择配方和1–3批，再确认。食物、用料和时间都实际结算。
3. 新命令替换当前任务；按住Shift可追加，最多三项。无法支付或无法到达的新命令保留原行动。手动取消未完成工作退料；睡觉保留已经恢复的疲劳。
4. **B打开建设**，选择简易床、雨水收集器或加固隔断，再点绿色位置。人物走过去施工，完成后才生效；没有一按按钮就免费获得床位或防守加成。
5. 白天20:00自动结束，也可以点击“结束白天”。提前结束会确认；未完成工作／建设取消并退料，跳过的时段只结算需求，不会把生产瞬间做完。首日08:00开局，后续清晨06:00开始。

**R是让选中者自行用药，接受治疗者会写在按钮上。**医护帮助别人请在P页选择医护与同伴，查看“施治者→接受者”。饥饿80以上需要先吃饭，药品仍能处理伤势与感染，但不能代替食物恢复生命。

## 夜晚做什么

为每人选择岗位：每晚最多一人搜刮，其余人可以守夜、床眠或地铺睡眠。床位名额来自实际建成的床。选择地点，再逐份调整随身物资；**出发时才真正从据点扣除**，每位角色有10／12／14格背包。

搜刮者可以点击地面走动、双击奔跑，点击容器会走近搜索。搜索完成后打开“容器／随身背包”，由你拿取或放回物资；**不会自动装满背包**。整理时夜间时间仍然流逝，空格可以明确暂停。F尽量全部拿走，Esc关闭。只有走回最左入口按T，东西才进入据点库存。

点击敌人会靠近并挥击，J也可挥击。红条是生命，金条是警觉；工具命中消耗一件并造成40伤害，徒手只推开、显示0伤害。挥空、被挡、受击和倒地有不同反馈。仍是简化的消耗式工具规则，尚未实现原作那种完整装备／武器体系。

提前归来也结束这一夜，不允许在同一晚反复刷往返。06:00天亮后会关闭整理界面、停止搜刮，沿实际路线撤离；迟归增加疲劳和压力，物资依旧必须到入口才入库。

![真实操作：夜间岗位与装备准备](docs/v10-night-planning.png)

![真实操作：选择拿走与留下的物资](docs/v10-loot.png)

## 清晨的后果

床眠恢复65疲劳，地铺35；守夜增加28，搜刮增加35，途中奔跑等额外消耗另算。第3夜起可能遭袭；守夜者的生命与疲劳、加固隔断共同影响损失。清晨报告会说明收获、休息、防守、丢失的物资与伤势，**读档不会重复结算或重抽袭击结果**。

雨水收集器只在细雨天气的清晨产水2，其他天气不产水。食物保鲜、据点维护、人物情绪／成长、三处搜刮地点、八章同伴故事和三条可选长期目标继续保留；这些系统的费用都来自实际库存。

## 保存、全屏与旧档

- F6保存，F9确认读取；正常关窗先保存。重新启动保持暂停，没有离线消耗。
- F11切换全屏。切到其他应用会暂停并释放持续输入，返回后按空格继续。
- schema7保存昼夜阶段、岗位、携带草案、建设和清晨账目，兼容schema1–6。v0.9旧进度可继续；正在外出的旧档先完成该次外出，再接入新循环。进入夜间分工时，旧的未完成白天任务按取消退料处理。
- 建议把新版解压到新文件夹，不覆盖正在运行的旧程序。存档仍在同一个系统用户目录，首次迁移写入会保留旧原件备份。

## 开发与真实验证范围

默认入口现在是`scenes/campaign.tscn`。`scenes/shelter.tscn`保留为共享底层模拟测试场景；正常运行包进入新昼夜循环。

```sh
git clone --single-branch --branch main https://github.com/hypetia/live_forever.git
python tests/run_checks.py --graphics --artifacts /tmp/live-forever-checks
python tools/build_desktop.py --acceptance --output builds --logs builds/logs
```

Godot4.6.3和Python3；图形检查需要显示环境，普通玩家不用安装这些开发工具。重建字体的可选工具需要fontTools，正常测试与运行不依赖它。

[本轮机制与验证记录](docs/CAMPAIGN_V1.md) · [正常游玩说明](docs/PLAYING.md) · [Windows实机检查](docs/WINDOWS_ACCEPTANCE.md) · [源码／运行包下载索引](downloads/README.md) · [许可](licenses/README.md)

对照原作的操作说明和实机资料在当前环境被网络代理403阻止，未运行原作；本轮不能描述为经过原作实机逐项对照。已实现的昼夜结构与交互会单独验证，武器深度、地图／事件数量、完整战役、温度与疾病系统等仍未达到原作规模。
