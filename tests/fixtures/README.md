# 真实旧版存档样本

`v1_working.json` 来自上一轮归档的 `live_forever_shelter_m03.zip`：将原源码解压到独立目录，用 Godot 4.6.3 首次导入，然后运行该版本原有的 `tests/persistence_process.gd -- write <fixture-path>`，经正常关窗处理函数生成。

内容为 schema 1：林舟已在灶台工作约2秒，生食 / 水 / 燃料各扣1，产出尚未发生；没有外出、药品、伤势 / 感染等新版字段。数据只有虚构角色和游戏状态，没有真实用户资料或凭据。

新版测试读取 / 复制此文件，不改样本原文。通过它验证迁移保留已扣料、工作进度、库存、人物和设施登记，新药品字段初始化为0，之后完成做饭不再扣第二次原料。首次升级保存还必须保留原 schema-1 字节为备份。


`v2_expedition.json` 使用归档的 `live_forever_shelter_m04.zip`、独立目录和独立用户配置运行原版 `persistence_expedition_process.gd -- write` 生成：人物携药，走到街口箱子、搜索一半，正常关窗处理保存。

`v2_repair.json` 在同一归档原版场景中，将林舟放到工作台交互点，调用原版派工与真实模拟2秒后写盘：schema 2 的免费修整已经开工，已扣材料为空。生成助手仅放在临时旧版副本，不改归档或样本。新版用它核对迁移后完成 / 取消不新增资源，不获得新版付费维修收益。


`v3_factory.json` 使用归档 `live_forever_shelter_m05.zip` 的原程序，在隔离目录 / 用户配置中导入，然后运行原 `persistence_long_term_process.gd -- write` 生成。人物携带真实搜获的材料3、燃料1及原药品，正在机修厂梯子中途；schema3没有人物成长、照料或稳身字段。新版验证其状态、用料和原始升级备份，不改样本。

- v4_people.json：来自归档v0.6原程序，运行persistence_people_process.gd的write阶段。实际生存3天、付费招募沈禾，并保存第四位成员外出中的世界；schema4文件未经手工改写。生成日志保存为构建产物m07-legacy-fixture.log。

- v5_story.json：来自归档v0.7原程序persistence_story_process.gd的write阶段。实际生存两天，保存待处理的林舟故事、原有引导、真实库存与工作；schema5文件未经手工改写。生成日志为构建产物m08-legacy-fixture.log。
