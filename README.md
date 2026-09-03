# 勇闖摩天輪（Venture Ferris）

[▶ Live Demo](https://venture-ferris.curihaosity.xyz)

一個把 2018 年台北市商業處「勇闖摩天輪」團隊實境解謎活動網站，從 2018 年老舊的 CodeIgniter 3 專案重構為 Rails 8.1 的技術作品集專案。

![遊戲流程展示](docs/images/demo.gif)

點首頁「▶ 直接體驗（Demo）」即可單人跑完取隊名、選職業、地圖解謎到 Boss 戰的完整流程，不需要湊滿 4 人；Demo 模式下 Boss 血量與時限都已調降，方便一個人在幾分鐘內體驗到結算畫面（正式站部署在東京、有 auto-suspend，第一次打開可能要等一兩秒喚醒機器）。

## 專案簡介

原案是 2018 年在台北大直美麗華旁舉辦的線下團隊實境解謎活動：玩家掃序號登入、組隊、選職業，依序破解 11 道謎題並「打王」，最後依時間、提示使用次數、職業加成計算總分，兌換獎品序號。

這個 repo 是該遊戲玩法邏輯的完整重寫，用來展示如何把一個「前端幾乎沒有任何伺服器端把關」的 10 年前 PHP 專案，改寫成一個資料驗證、權限控管都在伺服器端完成的現代 Rails 應用。

> 原案的活動素材、美術與品牌名稱版權屬原主辦單位所有，本專案僅作**技術重構展示**用途，不用於任何商業或活動用途。詳見下方〈素材授權註記〉。

## 重構亮點

- **答案驗證伺服器端化。** 舊站把正確答案直接印在頁面 HTML／JS 裡，開發者工具就能看到；新版比對全在 `POST /game/questions/:number/answer` 完成，頁面 render 內容不含 digest。細節見 [ARCHITECTURE.md「重構亮點」](docs/ARCHITECTURE.md#refactor-highlights)。
- **後台伺服器端驗證＋唯讀展示角色。** 舊站後台只用前端 SDK 擋畫面、可直接繞過；新版 `has_secure_password` + session 逐 action 檔在伺服器端，另有 `viewer` 唯讀角色供訪客瀏覽而不能寫入。細節同上。
- **Boss 戰爆擊伺服器端節流。** 前端只「宣告」爆擊，實際傷害與 2 秒節流窗全在伺服器端判定，竄改 client 連發爆擊無效。細節同上。
- **前端零 jQuery、零 CSS 框架 CDN。** 舊站整套 jQuery／jQuery UI／Bootstrap 4／Font Awesome 已移除，拼圖拖拉改寫為原生 Pointer Events 引擎，視覺層改用 Tailwind CSS v4。細節見 [ARCHITECTURE.md「前端」](docs/ARCHITECTURE.md#frontend)。
- **正規化 schema，計分邏輯有黃金值測試護欄。** 9 張表的正規化決策（含 8 條刻意保留的非正規設計）逐一論證於 `docs/SCHEMA_REDESIGN.md`；重構前後計分測試斷言值逐位元不變。細節見 [ARCHITECTURE.md「刻意保留的非正規設計」](docs/ARCHITECTURE.md#non-normalized-design)。

完整論述、架構總覽（Models／ERD／路由）、相較原作的新增功能全文，見[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)。

**技術棧**：Rails 8.1／PostgreSQL／Hotwire（Turbo + Stimulus）／Tailwind CSS v4／Dart Sass／部署 Fly.io（東京）+ Cloudflare。

## 本機啟動

```bash
bundle install                 # 1. 安裝 gems（Ruby 版本見 .ruby-version）
bin/rails db:prepare            # 2. 建立資料庫（本機 PostgreSQL socket，免帳密）
bin/rails db:seed               # 3. 灌入 11 題／demo 隊伍／序號池／後台帳號
bin/rails server                # 4. 啟動伺服器 → http://localhost:3000
```

首頁「▶ 直接體驗（Demo）」按鈕會當場建立一支全新單人示範隊伍並直接登入，不需湊滿 4 人即可跑完全部關卡＋Boss 戰＋結算＋兌獎。

後台入口 `/admin/login`：

- **operator**（一般帳號）：`admin@venture-ferris.example`，密碼由 `ADMIN_PASSWORD` 環境變數指定（`ADMIN_PASSWORD=xxx bin/rails db:seed`；未設定時預設 `changeme`，僅供本機示範）。
- **viewer**（唯讀展示帳號，帳密刻意公開）：`demo-admin@venture-ferris.example` / `walkthrough2026`，可瀏覽後台所有頁面，但任何寫入操作都會被伺服器端 `Admin::BaseController#block_viewer_writes` 擋下。

> ⚠️ 正式環境的後台密碼＝部署時設定的 `ADMIN_PASSWORD` secret，不是預設值 `changeme`；帳號建立後才改 secret 不會自動更新既有密碼，需另外更新資料庫中的 `Admin` 記錄。

### 測試

```bash
bin/rails test          # Model + integration tests
bin/rails test:system   # System tests（需要本機 Chrome）
bin/rubocop              # Lint
bin/brakeman             # 安全性靜態掃描
```

CI（`.github/workflows/ci.yml`）在每個 PR 上會跑上述四項，外加 `bin/importmap audit`。

## 文件導覽

| 文件 | 內容 |
|---|---|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | 架構總覽、重構亮點完整版、新增功能全文、已知限制全文——本文件的深度版 |
| [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) | Fly.io 從零到上線的完整操作序列 |
| [`docs/DEPLOYMENT_RESEARCH.md`](docs/DEPLOYMENT_RESEARCH.md) | 部署主機定價與規格查證（Fly.io/Vultr/Linode/DO/Render 比較） |
| [`docs/REFACTOR_PLAN.md`](docs/REFACTOR_PLAN.md) | 重構計畫 v2：舊站行為對照表與已知 bug 修正原則 |
| [`docs/SCHEMA_REDESIGN.md`](docs/SCHEMA_REDESIGN.md) | Schema 正規化方案：逐項決策表與 M0 計分黃金值測試附錄 |
| [`docs/UI_MODERNIZATION_PLAN.md`](docs/UI_MODERNIZATION_PLAN.md) | UI 現代化方案：Tailwind 改版分批計畫 |
| [`docs/UI_AUDIT.md`](docs/UI_AUDIT.md) | UI 現代化前的現況逐頁盤點 |
| [`docs/UI_STYLE_GUIDE.md`](docs/UI_STYLE_GUIDE.md) | Tailwind tokens 與元件配方 |
| [`docs/JOB_SKILLS_DESIGN.md`](docs/JOB_SKILLS_DESIGN.md) | Boss 戰四職業主動技設計 |
| [`docs/ADMIN_CONSOLE_PLAN.md`](docs/ADMIN_CONSOLE_PLAN.md) | 後台功能補全計畫（A1-A5） |
| [`docs/legacy/ANALYSIS.md`](docs/legacy/ANALYSIS.md) | 2018 原始 CodeIgniter 專案盤點報告 |

## 素材授權註記

本專案沿用的怪物立繪、地圖、Boss 場景等美術素材（`app/assets/images/*`）與活動品牌名稱（頁尾「Escapeholics密室逃脫」等），版權屬 2018 年原活動主辦單位（臺北市商業處、臺北市商圈產業聯合會）與原委製廠商所有。本專案僅作為**Rails 重構技術展示**，不含任何商業用途，亦不含原站的真實使用者資料、金鑰或帳密。

## 已知限制

- 題目原文（含第 1、2、9 題的拼圖／熊讚互動題）已於 2026-08-29 依尋回的原始 SQL dump 還原本貌。
- `mon10.gif` 從未存在——第 10/11 題考證後確認是同一隻「摩天輪魔王」的雙型態連戰，非素材遺失。

完整考證過程見 [ARCHITECTURE.md「已知限制（完整版）」](docs/ARCHITECTURE.md#known-limitations)。

已部署 Fly.io（東京，auto-suspend）＋ rack-attack 節流與每日 demo 資料清理排程，完整流程見 `docs/DEPLOYMENT.md`，維運細節見[ARCHITECTURE.md「部署與維運細節」](docs/ARCHITECTURE.md#deployment-details)。
