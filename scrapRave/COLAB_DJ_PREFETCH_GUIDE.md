# Colab DJ 多源抓取与本地导出指南

脚本文件：`/Users/blackie/Projects/raver/scrapRave/colab_dj_source_prefetch.py`

可直接上传运行的 Colab 模板：
- [`colab_dj_source_prefetch.ipynb`](/Users/blackie/Projects/raver/scrapRave/colab_dj_source_prefetch.ipynb)

## 0) 不上传 brands 的本地导出方案（推荐）

如果你不想把整个 `brands/` 上传到 Colab，先在本地导出“未匹配 DJ 名单”。

本地导出脚本：
- [`export_unmatched_timetable_djs.py`](/Users/blackie/Projects/raver/scrapRave/export_unmatched_timetable_djs.py)

本地执行：

```bash
cd /Users/blackie/Projects/raver/scrapRave
python export_unmatched_timetable_djs.py \
  --brands-root ./brands \
  --output-dir ./tmp_unmatched_export \
  --bff-base http://127.0.0.1:3001
```

导出结果：
- `tmp_unmatched_export/unmatched_dj_names_for_colab.json`
- `tmp_unmatched_export/unmatched_dj_names_for_colab.txt`
- `tmp_unmatched_export/unmatched_dj_names_for_colab.csv`

之后在 Colab 只上传这个名单文件（推荐 json）+ 抓取脚本 + `.env.colab` 即可。

## 1) 在 Google Colab 准备环境

```python
!pip -q install requests
```

上传脚本到 Colab（或从 Git 拉取后进入 `scrapRave` 目录）。

## 2) 配置 Token（推荐两种方式）

### 方式 A：上传 `.env` 文件（最简单）

先复制模板：
- [`colab_dj_source_prefetch.env.example`](/Users/blackie/Projects/raver/scrapRave/colab_dj_source_prefetch.env.example)

改成你自己的 `.env.colab`，填入真实值后上传到 Colab。

脚本执行时加：

```bash
--env-file ./.env.colab
```

### 方式 B：直接在 Colab 设置环境变量

脚本读取以下环境变量：

- `SPOTIFY_CLIENT_ID`
- `SPOTIFY_CLIENT_SECRET`
- `DISCOGS_USER_TOKEN`
- `SOUNDCLOUD_CLIENT_ID`（或 `SoundCloud_CLIENT_ID`）
- `SOUNDCLOUD_CLIENT_SECRET`（或 `SoundCloud_CLIENT_SECRET`）

示例（仅示意）：

```python
import os
os.environ["SPOTIFY_CLIENT_ID"] = "..."
os.environ["SPOTIFY_CLIENT_SECRET"] = "..."
os.environ["DISCOGS_USER_TOKEN"] = "..."
os.environ["SOUNDCLOUD_CLIENT_ID"] = "..."
os.environ["SOUNDCLOUD_CLIENT_SECRET"] = "..."
```

## 3) 仅导出 DJ 名单（从 brands timetable 抽取）

```bash
python colab_dj_source_prefetch.py \
  --brands-root ./brands \
  --output-root ./dj_source_cache_export \
  --export-only-names
```

输出：`dj_source_cache_export/dj_names.json`

## 4) 执行多源抓取（每源 top3，重试1次，DJ间隔5秒）

### 方式 A：使用本地导出的名单文件（不上传 brands）

```bash
python colab_dj_source_prefetch.py \
  --env-file ./.env.colab \
  --names-file ./unmatched_dj_names_for_colab.json \
  --output-root ./dj_source_cache_export \
  --sources spotify,discogs,soundcloud \
  --top-n 3 \
  --retry-times 1 \
  --retry-interval-sec 2 \
  --dj-interval-sec 5 \
  --chunk-size 500 \
  --auto-download
```

### 方式 B：从 brands 直接抽取名单

```bash
python colab_dj_source_prefetch.py \
  --env-file ./.env.colab \
  --brands-root ./brands \
  --output-root ./dj_source_cache_export \
  --sources spotify,discogs,soundcloud \
  --top-n 3 \
  --retry-times 1 \
  --retry-interval-sec 2 \
  --dj-interval-sec 5 \
  --chunk-size 500 \
  --auto-download
```

说明：
- `--chunk-size 500`：每 500 个 DJ 生成一个独立 zip 包
- `--auto-download`：在 Colab 中每个分包完成后自动触发下载

## 5) 结果目录

- `dj_source_cache_export/chunks/chunk_0001_1-500/...`：每个分包结果
- `dj_source_cache_export/chunks/chunk_0001_1-500.zip`：每个分包 zip
- `dj_source_cache_export/summary_global.json`：全局汇总

## 6) 日志内容

每个 DJ 会输出：
- 第几个 DJ / 总数
- DJ 名称
- Spotify/Discogs/SoundCloud 各抓到几条
- 失败源与失败原因

对应 action：`prefetch_dj_result`
