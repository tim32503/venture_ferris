# UI 現代化方案

> 依據：`docs/UI_AUDIT.md`（2026-08-29 逐頁盤點）。本文件是「怎麼改、分幾批、先後順序」的方案；現況細節（檔案:行號）請回查 AUDIT。
> 狀態：提案，等使用者裁決三個決策點後才動工。

## 現況一句話

全站 22 個 view 共 1126 行，樣式是 Bootstrap 4.1.3（CDN）＋兩份 2018 手調座標的 SCSS；jQuery 實際依賴只剩「拼圖 plugin（含 jQuery UI）」一顆硬骨頭與 Bootstrap 4 的 modal/carousel 兩個小元件；6/7 個 Stimulus controller 與所有輪詢已是原生 fetch，不需重做。

## 三個決策點與建議

### 決策 1：CSS 框架 → 建議「TailwindCSS 全面改版」

| 選項 | 工作量 | 作品集價值 | 說明 |
|---|---|---|---|
| A. 維持 Bootstrap 4 | 0 | 負分 | BS4 已 EOL（2023），且 modal/carousel 綁死 jQuery |
| B. 升 Bootstrap 5 | 中（class 更名：`data-toggle`→`data-bs-toggle`、`form-group`/`form-inline` 移除、`ml-/mr-`→`ms-/me-` 等，22 個 view 全要過一遍） | 低 | 解掉 jQuery 依賴但視覺不變，屬「維護」不是「展示」 |
| **C. TailwindCSS（建議）** | 大（19 個 page view 逐頁換 class＋視覺重設計；兩份舊 SCSS 重寫） | **高** | `tailwindcss-rails` gem 免 Node、與現有 sprockets 共存；1126 行的量級完全可控。Tailwind 本身無 JS 元件，modal/carousel 反正要改 Stimulus——與決策 2 是同一批工，做一次解兩題 |

選 C 的附帶決定：遊戲美術素材（背景、立繪、地圖）保留原味，改的是版面容器、表格、表單、按鈕、字體階層——「2018 的活動美術＋2026 的介面工程」本身就是作品集敘事。

### 決策 2：jQuery 退場 → 建議「全部退場，拼圖用原生 Pointer Events 重寫」

依 AUDIT 的依賴總表逐項處置：

| 依賴 | 處置 | 難度 |
|---|---|---|
| `jquery.snap-puzzle.min.js`＋jQuery UI draggable＋touch-punch | **用原生 Pointer Events 重寫成 `puzzle_controller.js` 的一部分**（Pointer Events 天生統一滑鼠/觸控，touch-punch 直接消滅；吸附邏輯＝格子中心距離判定，約 150-200 行）。備援方案：importmap pin `interact.js`（ESM 友善）再包 Stimulus | 大（但這是全案最有展示價值的一塊：「把 minified 黑箱 plugin 重寫成 200 行原生引擎」） |
| Bootstrap 4 Modal（首頁玩法說明） | 原生 `<dialog>` 元素＋ ~20 行 Stimulus controller（也可與現有 Turbo confirm 對話框共用樣式） | 小 |
| Bootstrap 4 Carousel（選職業） | CSS `scroll-snap` ＋小 Stimulus controller（左右鍵/指示點），觸控滑動由瀏覽器原生提供、比 BS4 的模擬 swipe 更好 | 中 |
| Layout 打字機 `type()`（死碼）＋`@keyframes blink`＋`.ripple`（孤兒 CSS） | 直接刪除。（選配彩蛋：把 `.rippleEffect` 接到 Boss 戰「攻擊！」按鈕當點擊回饋——它原本可能就是為此設計的） | 小 |
| 完成後 | layout 移除全部 4 個 CDN `<script>`（jQuery/jQuery UI/Popper/Bootstrap JS）與 2 個 vendor 檔 | — |

### 決策 3：Turbo 深化 → 建議「列為選配收尾，不混入本次」

現有 fetch 輪詢（500ms）行為正確、實作乾淨。升級選項是 Turbo 8 的 `broadcasts_refreshes`＋morphing：model 一行宣告、view 一行 `turbo_stream_from`，可讓 4 個 poll controller 幾乎全數退役——展示價值高，但**需要 ActionCable backend**（dev 用 async、production 要 Redis 或 solid_cable），部署目標未定前先不動。列為 U4 選配。

## 與框架無關、無論如何都該修的結構性問題（來自 AUDIT）

1. **地圖 image-map 熱點**（全站唯一必壞的 RWD 洞）：`<map>/<area>` 絕對像素座標不隨 `img-fluid` 縮放。改法：熱點改成以百分比定位的 `<a>` overlay（座標從 controller 的像素值換算成 %，一次換算永久有效），image-map 整組退役。
2. **Boss 疊圖 11 組手調座標**（`boss.scss:37-46`）：改成百分比＋CSS custom properties（`--mon-w/--mon-x/--mon-y`），數值仍是逐怪物的，但單位改相對值後手機比例不再跑掉。
3. **表格 RWD**：積分結算 7 欄表（必擠壓）、隊伍/紀錄表——Tailwind 化時直接改成手機卡片式/桌機表格的 responsive 版型。
4. **首頁/隱私頁固定 margin**（`5rem/3rem` 無斷點）→ 響應式間距。
5. Google Fonts 舊 `earlyaccess` CDN → 現行 API。

## 分批計畫

| 批次 | 內容 | 依賴 | 規模 | 狀態 |
|---|---|---|---|---|
| U0 清理 | 刪打字機死碼/blink/ripple（或接上攻擊按鈕）、Google Fonts 更新 | — | 小 | ✅ 完成 |
| U1 結構修復 | 地圖熱點 % 化、Boss 疊圖相對定位化、表格 responsive、固定 margin 響應式（先在 Bootstrap 下修好，與框架切換解耦） | — | 中 | ✅ 完成 |
| U2 jQuery 退場 | 拼圖原生重寫、modal→`<dialog>`、carousel→scroll-snap、移除 4 個 CDN script + 2 個 vendor 檔 | U0 | 大 | ✅ 完成 |
| U3a／U3b Tailwind 改版（首批＋入場導覽） | 導入 tailwindcss-rails；welcome/admin/game 首頁與地圖等入場導覽五頁換裝 | U1、U2 | 大 | ✅ 完成 |
| U3c Tailwind 改版（收尾） | 剩餘遊戲頁（quiz/puzzle/bear/solved/hint/start_dialog/boss/scores/rewards/records）換裝；`.dialog` 共用 class 退場；移除 Bootstrap CDN CSS + Font Awesome CDN（`fas fa-home`→inline SVG）；README 前端章節同步 | U3a、U3b | 大 | ✅ 完成 |
| U4（選配） | Turbo 8 broadcasts_refreshes 取代輪詢 | 部署目標定案 | 中 | 未排程 |

每批驗收：`bin/rails test`＋`test:system` 全綠不退步；U2 拼圖重寫需新增 system test（拖拉完成觸發解鎖）；U3 每批附改版前後截圖對照。

## 若只想要最小方案（不做 Tailwind）

U0＋U1＋U2＋「Bootstrap 5 升級」＝ jQuery 全退、RWD 修好、框架不再 EOL，視覺大致不變。工作量約為完整方案的一半，作品集加分有限。
