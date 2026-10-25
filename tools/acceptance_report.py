#!/usr/bin/env python3
"""Publish actual Linux desktop evidence while keeping Windows status explicit."""
from pathlib import Path
import argparse
import json
import os


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('desktop', type=Path)
    parser.add_argument('cold_exit', type=Path)
    parser.add_argument('windows_package', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    desktop = json.loads((args.desktop / 'acceptance-result.json').read_text())
    cold = json.loads((args.cold_exit / 'cold-exit-result.json').read_text())
    windows = json.loads(args.windows_package.read_text())
    assert desktop['platform'] == 'Linux' and desktop['native_close_and_restart'] == 'passed'
    assert desktop['continuous_30_minutes_complete'] and desktop['elapsed_seconds'] >= 1800
    assert len(cold['rounds']) == 3 and all(item['close_and_restart'] == 'passed' for item in cold['rounds'])
    raw = args.output / 'acceptance-data'
    raw.mkdir(parents=True, exist_ok=True)
    for name, data in [('linux-desktop', desktop), ('cold-exit', cold), ('windows-package', windows)]:
        (raw / (name + '.json')).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    memory = desktop['process_memory_samples']
    start_rss, end_rss = memory[0]['resident_bytes'], memory[-1]['resident_bytes']
    peak_rss = max(item['resident_bytes'] for item in memory)
    warm = [item for item in memory if item['monotonic_seconds'] - memory[0]['monotonic_seconds'] >= 120]
    warm_start = warm[0]['resident_bytes']
    warm_min = min(item['resident_bytes'] for item in warm)
    warm_max = max(item['resident_bytes'] for item in warm)
    lines = ['# v0.8 · 桌面与连续运行验收', '',
             '普通运行程序与独立验收程序都由Godot4.6.3匹配官方模板导出；各自内嵌数据，普通游戏不包含自动验收控制。以下Linux结果来自实际导出的程序和实际经过时间。Windows尚待用户设备执行，不能用Linux通过代替。', '',
             '| 检查 | Linux结果 | Windows状态 |', '| --- | --- | --- |']
    for item in desktop['resolutions']:
        label = '%d×%d' % tuple(item['requested'])
        lines.append(f'| 窗口{label} | {"实际尺寸与完整逻辑画面通过" if item["status"] == "checked" else "跳过：" + item["reason"]} | 待真机 |')
    lines += ['| 全屏进入／返回窗口 | 实际切换通过 | 待真机 |',
              '| 正常关窗／原程序重启 | 系统消息、退出码与存档核对通过 | 待真机 |',
              '| 冷虚拟显示首次启动退出 | 三个新Xorg会话分别通过 | 不适用；使用原生WM_CLOSE |',
              f'| 持续实际运行 | {desktop["elapsed_seconds"] / 60:.2f}分钟、{desktop["frames"]}帧 | 需运行一键脚本 |', '',
              '## 连续运行内容与资源记录', '',
              '验收按真实帧推进同一游戏代码，使用正常派工、饮水、行走、攀爬、搜索、攻击、用药和返程，不注入库存、生命、位置或经验，不让暂停画面代替持续游玩。独立槽位与偏好目录隔离正常玩家存档。', '',
              f'完成{sum(bool(check["passed"]) for check in desktop["checks"])}项桌面检查；三位初始成员仍存活。最近一次样本记录{desktop["samples"][-1]["trips"]}次真实返程，模拟时间{desktop["samples"][-1]["simulation_seconds"]:.1f}秒。', '',
              f'外部进程常驻内存：预热120秒后首样{warm_start / 1048576:.1f} MiB，末次{end_rss / 1048576:.1f} MiB，预热后范围{warm_min / 1048576:.1f}—{warm_max / 1048576:.1f} MiB。全程峰值{peak_rss / 1048576:.1f} MiB。原始首样{start_rss / 1048576:.1f} MiB采于进程刚启动，尚未完成字体／渲染初始化，不能用它与末次差值直接判定泄漏。原始采样与包含启动阶段的曲线一并提供。', '',
              f'连续阶段最慢单帧{desktop["worst_frame_seconds"]:.3f}秒；Xorg dummy／Mesa llvmpipe为软件渲染，这里的帧率不代表Windows硬件表现。', '',
              '## 退出异常的修正', '',
              '旧探针在全新虚拟显示上没有先注册关窗协议，而Godot只查询已有原子，导致首次关闭消息未被识别。现在启动前正确初始化；窗口树搜索还按进程匹配并避免临时窗口销毁竞争。三轮验证均先确认原子不存在，再进行正常系统输入、搜刮、返程、关窗和重启，期限保持15秒。详见[定位证据](EXIT_DIAGNOSIS.md)。', '',
              '## Windows怎么提供证据', '',
              '下载单独的Windows验收包，解压后双击windows_acceptance.cmd。脚本默认跑30分钟，再通过原生关窗消息与实际F6键检查恢复。结果在AcceptanceResults目录；另按[人工检查单](WINDOWS_ACCEPTANCE.md)核对声音、可读性、按键与Alt+Tab。无需提供远程桌面或账号密码。', '',
              'PowerShell脚本已做结构语法检查；尚未实际在Windows执行。只有收到对应设备的实际结果，才能把Windows启动、音频、全屏、分辨率和连续运行标为验收通过。', '',
              '## 原始结果', '',
              '[Linux桌面数据](acceptance-data/linux-desktop.json) · [三轮冷启动](acceptance-data/cold-exit.json) · [Windows包校验值／待验状态](acceptance-data/windows-package.json)', '',
              '```sh', 'python tools/desktop_acceptance.py builds/linux/LiveForever.x86_64 builds/acceptance-linux/LiveForeverAcceptance.x86_64 --minutes 30 --display :98 --artifacts /tmp/live_forever_desktop',
              'python tools/cold_exit_check.py builds/linux/LiveForever.x86_64 --display :99 --artifacts /tmp/live_forever_cold_exit', '```']
    try:
        os.environ.setdefault('MPLCONFIGDIR', str(args.output / '.plot-cache'))
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
        fig, axes = plt.subplots(2, 1, figsize=(10, 6), dpi=180, layout='constrained')
        samples = desktop['samples']
        axes[0].plot([item['wall_seconds'] / 60 for item in samples], [item['fps'] for item in samples], color='#527d69')
        axes[0].set_ylabel('Reported FPS (software GL)')
        origin = memory[0]['monotonic_seconds']
        axes[1].plot([(item['monotonic_seconds'] - origin) / 60 for item in memory], [item['resident_bytes'] / 1048576 for item in memory], color='#b77e37')
        axes[1].set_ylabel('Resident memory (MiB)')
        for axis in axes:
            axis.set_xlabel('Actual elapsed minutes')
            axis.grid(alpha=.2)
            axis.spines[['top', 'right']].set_visible(False)
        fig.suptitle('Live Forever v0.8 — actual continuous desktop runtime')
        fig.savefig(args.output / 'desktop-runtime-preview.png')
        plt.close(fig)
        lines += ['', '![实际帧率与内存采样](desktop-runtime-preview.png)']
    except ImportError:
        print('Matplotlib unavailable; raw data and Markdown still generated.')
    (args.output / 'DESKTOP_ACCEPTANCE.md').write_text('\n'.join(lines) + '\n')
    print('Published actual desktop evidence; Windows remains explicitly pending real-device execution.')


if __name__ == '__main__':
    main()
