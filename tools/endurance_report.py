#!/usr/bin/env python3
"""Generate the extended survival report from actual engine JSON results."""
from pathlib import Path
import argparse
import csv
import json
import os


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('results', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    raw = args.output / 'endurance-data'
    raw.mkdir(exist_ok=True)
    modes = {'three30': '三人30天', 'five60': '逐步五人60天', 'recovery': '伤亡与低库存恢复'}
    reports = {mode: json.loads((args.results / (mode + '.json')).read_text()) for mode in modes}
    for mode, report in reports.items():
        (raw / (mode + '.json')).write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    fields = ['mode', 'day', 'alive', 'hunger', 'morale', 'integrity',
              'raw_food', 'water', 'fuel', 'meals', 'materials', 'tools', 'medicine']
    with (args.output / 'endurance-daily.csv').open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        for mode, report in reports.items():
            for entry in report['daily']:
                writer.writerow({'mode': mode, **{key: entry[key] for key in fields[1:6]}, **entry['stock']})
    lines = ['# v0.8 · 30／60天与逆境恢复报告', '',
             '前两组从新局初始库存连续模拟，不注入生命、物资、坐标或经验。自动策略使用真实派工、饮水、搜索、步行、攀爬、战斗、撤退、升级和付费招募；有余量时支付人物事件费用、建设项目和参加限次互助，否则保留物资；勘查目标通过正常移动和搜索取得。', '',
             '一天为720秒模拟时间，所有时间推进使用实际游戏相同的1/60秒子步。30天和60天分别从第1天08:00运行到第31天和第61天08:00。存档保留最近30条日记录，测试报告另外收集完整时间线；没有跳日或离线奖励。', '',
             '| 场景 | 经过天数 | 存活 / 历史人数 | 往返次数 | 饮水 | 修缮 | 结构 | 故事数 |',
             '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |']
    for mode, report in reports.items():
        lines.append(f'| {modes[mode]} | {report["days_elapsed"]:.2f} | {report["alive"]} / {len(report["crew"])} | {report["trips"]} | {report["drinks"]} | {report["repairs"]} | {report["integrity"]:.1f}% | {len(report["stories"])} |')
    lines += ['', '## 终点可用库存', '', '| 场景 | 生食 | 水 | 燃料 | 熟食 | 材料 | 工具 | 药品 |',
              '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |']
    for mode, report in reports.items():
        lines.append('| ' + modes[mode] + ' | ' + ' | '.join(str(report['stock'][key]) for key in fields[6:]) + ' |')
    lines += ['', '## 可选目标与互助的实际投入', '',
              '| 场景 | 通讯 / 救护 / 补给线阶段 | 已付材料 | 已付药品 | 药品互助 / 备件互助次数 |',
              '| --- | --- | ---: | ---: | --- |']
    for mode, report in reports.items():
        goal = report['goals']
        lines.append('| ' + modes[mode] + ' | ' + ' / '.join(str(goal['stages'][key]) + '/3' for key in ['radio', 'clinic', 'network']) +
                     f' | {goal["spent"]["materials"]} | {goal["spent"]["medicine"]} | {goal["trades"]["medicine"]} / {goal["trades"]["materials"]} |')
    baseline = args.output / 'baseline-v07' / 'five60.json'
    if baseline.exists():
        old = json.loads(baseline.read_text())
        new = reports['five60']
        lines += ['', '## 与实际v0.7五人60天结果比较', '',
                  '| 版本 | 往返 | 期末材料 | 期末药品 | 期末生食 / 水 / 燃料 |',
                  '| --- | ---: | ---: | ---: | --- |',
                  f'| v0.7 | {old["trips"]} | {old["stock"]["materials"]} | {old["stock"]["medicine"]} | {old["stock"]["raw_food"]} / {old["stock"]["water"]} / {old["stock"]["fuel"]} |',
                  f'| v0.8 | {new["trips"]} | {new["stock"]["materials"]} | {new["stock"]["medicine"]} | {new["stock"]["raw_food"]} / {new["stock"]["water"]} / {new["stock"]["fuel"]} |', '',
                  '旧数据直接来自归档v0.7源码包中的实测JSON，原字节和归档SHA-256保存在baseline-v07。新版策略额外规划项目并使用互助，因此结果体现整套玩法变化，不能单独归因于某一个配方。', '',
                  '[v0.7五人原数据](baseline-v07/five60.json) · [原始归档证明](baseline-v07/provenance.json)']
    lines += ['', '## 独立逆境夹具' , '',
              '第三组先实际生存3天、付费接纳沈禾，再明确设置一份压力测试夹具：许遥永久死亡，陈野生命65／伤势45／感染35，结构18%，生食、水、燃料各仅保留1，药品清空。此处主动施加伤亡、伤势和资源损失，不计作自然游玩的成功案例，也没有添加恢复物资。', '',
              '随后连续推进12个完整模拟日，仅通过正常游戏操作恢复，招募顾苒和唐弥；旧成员的死亡身份保留。该组往返次数从恢复阶段重新计数；日明细包含事故前最近一条日界记录，随后是恢复期间的日界。饮水、修缮、库存、伤亡与故事是世界累计状态。', '',
              '## 结果的解释范围', '',
              '这些用例证明当前存在可持续的熟练操作策略，且指定逆境有恢复路径；不代表所有开局、操作水平、随机遭遇或策略均可救回。仍需玩家持续安排物资、维护和照料。', '',
              '项目建设与共用两日间隔的互助为材料、药品提供了明确用途，所有投入均进入账目。玩家可以保留物资；不参与项目／互助的策略仍可能积累库存。食物受有限保鲜约束，其余库存仍无强制总上限；这些成功案例不等于所有资源、策略和操作水平已经平衡。技能仍每项最多3级、180经验，升级最多3级，敌人生命40、每地点最多5名。', '',
              '## 原始数据与重现', '',
              '[三人30天](endurance-data/three30.json) · [五人60天](endurance-data/five60.json) · [逆境恢复](endurance-data/recovery.json) · [完整每日CSV](endurance-daily.csv)', '',
              '```sh', 'godot --headless --editor --import --quit',
              'godot --headless --path . --script res://tests/test_endurance.gd -- /tmp/live_forever_endurance',
              'python tools/endurance_report.py /tmp/live_forever_endurance --output /tmp/live_forever_endurance_report', '```']
    try:
        os.environ.setdefault('MPLCONFIGDIR', str(args.output / '.plot-cache'))
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
        fig, axes = plt.subplots(2, 2, figsize=(11, 6), dpi=180, layout='constrained')
        for mode, color in [('three30', '#527d69'), ('five60', '#b77e37')]:
            entries = reports[mode]['daily']
            for axis, key, title in [(axes[0, 0], 'water', 'Available water'), (axes[0, 1], 'fuel', 'Available fuel'),
                                     (axes[1, 0], 'morale', 'Mean morale'), (axes[1, 1], 'integrity', 'Shelter structure (%)')]:
                values = [entry['stock'][key] if key in ['water', 'fuel'] else entry[key] for entry in entries]
                axis.plot([entry['day'] for entry in entries], values, color=color, linewidth=1.5, label=mode)
                axis.set_title(title)
                axis.set_xlabel('Calendar day at boundary')
                axis.grid(alpha=.2)
                axis.spines[['top', 'right']].set_visible(False)
        axes[0, 0].legend(frameon=False)
        fig.suptitle('Live Forever v0.8 — continuous 30/60-day survival')
        fig.savefig(args.output / 'endurance-preview.png')
        plt.close(fig)
        lines += ['', '![真实长期资源与状态](endurance-preview.png)']
    except ImportError:
        print('Matplotlib unavailable; CSV and Markdown still generated.')
    (args.output / 'ENDURANCE_REPORT.md').write_text('\n'.join(lines) + '\n')
    print('Generated endurance report, raw JSON and complete daily CSV.')


if __name__ == '__main__':
    main()
