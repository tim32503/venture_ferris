# UI 現代化評估：現況盤點

> 純盤點文件，不含「該不該換 Tailwind／Bootstrap 5／全面 Stimulus 化」的決策，那是後續討論的事。
> 產出時間：2026-08-29。範圍：`app/views/{layouts,welcome,game,admin}/**`、`app/assets/stylesheets/{site,boss}.scss`、
> `app/javascript/**`、`vendor/javascript/*`。逐項附 `檔案:行號`。

## 總覽

- 22 個 view 檔（含 layout、2 個 partial）共 **1126 行**，全部走 Bootstrap 4.1.3 + 少量 Font Awesome 5，樣式全靠 `site.scss`/`boss.scss` 兩份 2018 轉碼 CSS 疊加，沒有元件化。
- 全站只有 1 個 inline `<script>` 區塊（layout 的打字機 `type()`，用 jQuery），5 個 `<script src>` CDN 標籤（jQuery／jQuery UI／Popper／Bootstrap JS）；view 裡 `$(`/`jQuery` 呼叫只出現在這個打字機函式，但**從未被任何 view 呼叫過**（見下方 jQuery 總表）。
- inline `style=` 只有 7 處，且都是「單一數值」等級（`position: relative`、`max-width`、`min-height`、icon 顏色），沒有大面積 inline style。真正的定位邏輯（Boss 立繪疊圖、地圖熱點）在 SCSS 與 controller 的寫死座標裡，不在 view。
- 唯一「前端仍不可迴避需要 jQuery」的地方是拼圖題的 `jquery.snap-puzzle.min.js`（非 ESM、依賴 jQuery UI draggable + touch-punch），其餘 Bootstrap 4 JS 元件（modal／carousel／dropdown）用量很小、且 Bootstrap 5 起已可脫離 jQuery。
- 地圖頁的 image-map 熱點座標是寫死在 `app/controllers/game/maps_controller.rb` 的絕對像素值，圖片卻用 `img-fluid` 響應式縮放 —— 這是全站唯一「螢幕縮小必壞」的已知結構性風險（`<map>` 的 `coords` 不會跟著 `<img>` 縮放，多數瀏覽器不會自動換算）。
- Boss 戰頁的怪物立繪用 `boss.scss` 裡逐怪物、逐項寫死的 `bottom/left/width` 疊圖到背景草地圖片上，換一張圖或改版型就要重新量測全部 11 組數字。
- 7 個 Stimulus controller 已經覆蓋了全部「輪詢」邏輯（team/job/active-question/boss 四種 poll + 共用 base class）與拼圖初始化／熊照片縮放，這部分**不需要重做**，只有 `jquery.snap-puzzle` 本身還沒有原生替代。
- 2018 遺風主要是：`<br>` 排版（layout 頁尾）、`<map>`/`<area>` image-map（地圖頁）、打字機特效（layout，但目前沒有任何頁面呼叫）、字型走 Google Fonts 舊版 `earlyaccess` CDN、`onclick="window.location.href=...''"` 內嵌事件（地圖頁返回鍵）。

---

## 逐頁清單

| View | 用途 | Bootstrap 元件 | jQuery 依賴點 | Inline style／寫死定位 | 2018 遺風 | RWD 現況 |
|---|---|---|---|---|---|---|
| `app/views/layouts/application.html.erb` (66行) | 全站 layout | `container-fluid`（footer） | 打字機 `type()` 函式用 `$('#'+field)`（17-48行，實際上目前**沒有任何 view 呼叫 `type()`**，是死碼） | 無 | `<br>` 排版頁尾（61行）；`type()` 打字機效果整段是孤兒程式碼 | viewport meta 有設，footer 純文字，OK |
| `app/views/welcome/index.html.erb` (125行) | 首頁／活動資訊／Demo 入口 | `table`（5 個資訊表格）、`btn btn-lg` | 無 | `content_for :head` 內嵌 `<style>`（3-33行）用固定 `margin: 5rem`/`3rem`，小螢幕會被過度擠壓 | 全站背景圖 `background-attachment: fixed`（2018 手機相容性差的常見寫法）；資訊用多個獨立 `<table>` 而非語意化清單 | 中：`header{margin:5rem}`/`main{margin:3rem}` 無響應式斷點，手機上留白比例過大 |
| `app/views/welcome/error.html.erb` (16行) | 錯誤頁 | 無明顯 Bootstrap 元件（僅 `container`） | 無 | 無 | 無 | 良好，內容極簡 |
| `app/views/welcome/privacy.html.erb` (82行) | 隱私權政策 | 純文字排版 | 無 | 同 index 的固定 margin `<style>` block（1-33行） | 無特別遺風，純法遵文字 | 同 index，長文在窄螢幕上因 `main{margin:3rem;padding:2rem}` 版心會偏窄 |
| `app/views/game/home/show.html.erb` (67行) | 遊戲主選單 | `modal`（玩法說明，50-65行，用 `data-toggle="modal"`）、`btn-group-vertical`、`badge` | Bootstrap modal 的 `data-toggle`/`data-dismiss` 屬性依賴 Bootstrap 4 JS（間接依賴 jQuery，因為 BS4 modal 內部用 jQuery 插件機制） | 無 | 無 | 良好：`btn-group-vertical`＋`container-fluid` 自然堆疊 |
| `app/views/game/sessions/new.html.erb` (38行) | 登入頁 | `form-group`、`btn-block` | 無 | 無 | 無 | 良好 |
| `app/views/game/teams/show.html.erb` (85行) | 冒險隊伍（隊名／隊員列表） | `table`、`input-group` | 無（`team-poll` 是 Stimulus，非 jQuery） | 無 | 隊員資訊用 `<table>` 呈現，非卡片式 | 表格在窄螢幕會橫向擠壓（3 欄：類型/職業/帳號），無 `table-responsive` wrapper |
| `app/views/game/jobs/show.html.erb` (53行) | 選擇職業 | **`carousel`（Bootstrap 4 Carousel，21-44行，`data-ride="carousel"`）** | Carousel 依賴 Bootstrap 4 JS（jQuery 插件） | 無 | 無 | 中：carousel 圖片 `d-block w-100`，觸控滑動需靠 BS4 內建 swipe（非原生） |
| `app/views/game/maps/show.html.erb` (39行) | 遊戲地圖（**image-map 熱點**） | 無（純 `<map>`/`<area>`） | 無 JS 依賴，但 `onclick="window.location.href='<%= back_path %>'"` 是 inline 事件（33行） | `id="m..."` 的 `style="position: relative;"`（10行）；返回鍵 icon 的顏色 inline style（35-36行） | **`<map name>`/`<area shape/coords>` image-map**，座標寫死在 `app/controllers/game/maps_controller.rb:13-33`（絕對像素，rect/poly/circle 混用），圖片走 `img-fluid` 響應式但座標不隨之縮放 | **差：已知風險點**。手機上圖片縮小後熱點位置會偏移，是全站唯一結構性 RWD 問題 |
| `app/views/game/bosses/show.html.erb` (74行) | 魔王戰（**絕對定位素材疊圖**） | `progress`／`progress-bar`（HP 條，47-50行） | 無 view 內 jQuery，但頁面靠 `boss.scss` 的逐怪物絕對定位 class | `style="position: relative;"`（37行）、HP bar 動態 `width: <%= @battle.hp_percent %>%;`（inline，48行） | 怪物立繪疊圖用 `boss.scss` 逐編號 `.mon01`~`.mon11` 寫死 `bottom/left/width`（見 CSS 現況） | 中：疊圖用 `%`/`rem` 混合，小螢幕下比例會跑掉但不算「壞版面」等級 |
| `app/views/game/records/show.html.erb` (39行) | 解謎紀錄 | `table` | 無 | 無 | 純表格呈現歷史紀錄 | 4 欄表格，窄螢幕會擠，無 `table-responsive` |
| `app/views/game/rewards/show.html.erb` (61行) | 任務獎勵／兌獎 QR | `form-group`、`row`/`col-6` | 無 | 無 | 無 | 良好，QR code 用 SVG helper 產出 |
| `app/views/game/scores/show.html.erb` (55行) | 積分結算 | `table`（7 欄）、`tfoot` | 無 | 無 | 無 | 差：7 欄分數表在手機上必定橫向擠壓，無 `table-responsive` |
| `app/views/game/questions/bear.html.erb` (53行) | 熊讚找碴題 | 無特別元件 | 無（`bear` controller 是 Stimulus，純 CSS `transform: scale` 縮放） | 無 | page-scoped `<style>` inline（3-9行）定義 `.bear-zoomed` | 良好 |
| `app/views/game/questions/puzzle.html.erb` (69行) | 拼圖題（**jQuery 拼圖插件**） | `col-md-6`／`input-group` | **`jquery.snap-puzzle.min.js` + jQuery UI draggable + touch-punch**（透過 `puzzle_controller.js` 呼叫，見下方總表） | `style="min-height: 200px;"`（45行，拼圖堆放區佔位） | page-scoped `<style>`（3-14行）定義 `.snappuzzle-*` class | 中：拼圖堆放區用固定 `min-height`，手機小螢幕下拼圖區塊可能被壓縮 |
| `app/views/game/questions/quiz.html.erb` (41行) | 問答題 | 無特別元件 | 無 | 無 | 無 | 良好 |
| `app/views/game/questions/solved.html.erb` (18行) | 題目已完成提示 | 無 | 無 | 無 | 無 | 良好 |
| `app/views/game/questions/_hint_panel.html.erb` (24行, partial) | 提示面板 | `dialog`（自訂 class，非 BS） | 無 | 無 | 無 | 良好 |
| `app/views/game/questions/_start_dialog.html.erb` (22行, partial) | 開始計時確認 | 無 | 無 | 無 | 無 | 良好 |
| `app/views/admin/sessions/new.html.erb` (25行) | 後台登入 | `form-group`、`btn-block` | 無 | `style="max-width: 420px;"`（1行，容器寬度限制） | 無 | 良好 |
| `app/views/admin/dashboard/show.html.erb` (40行) | 後台總覽 | `card`、`row`/`col-md-4`、`display-4` | 無 | 無 | 無 | 良好，是全站唯一用 Bootstrap `card` 元件的頁面 |
| `app/views/admin/serial_codes/index.html.erb` (52行) | 序號產生器 | `form-inline`、`form-check`、`table-striped` | 無 | `style="width: 8rem;"` 不在上面 grep 命中清單中——**註：實際上這個 style 在 `f.number_field` 上，grep 未命中因為屬性順序不同，見下方修正** | 無 | 良好 |

> 註：`admin/serial_codes/index.html.erb` 的 `number_field` 有 `style: "width: 8rem;"`（第 19 行的 helper 參數，非原始 HTML `style="..."` 字串），grep 的 raw-HTML 比對抓不到 Rails helper 產生前的參數形式，因此未列入前面「inline style 共 7 處」的計數；量化章節已註明此為 grep 方法論限制。

---

## jQuery 依賴總表

逐一列出全專案「實際會在瀏覽器執行到」的 jQuery 相關依賴（不含註解中提及但未執行的文字）：

| # | 依賴點 | 位置 | 說明 | 改寫難度 | 風險 |
|---|---|---|---|---|---|
| 1 | `jquery.snap-puzzle.min.js` 拼圖拖拉插件 | 載入：`app/views/layouts/application.html.erb:19`；呼叫：`app/javascript/controllers/puzzle_controller.js:57`（`window.jQuery(this.imageTarget).snapPuzzle({...})`） | 第三方 minified、非 ESM，用於 `game/questions/puzzle.html.erb`（題號 1、2）。內部用 jQuery UI draggable 做碎片拖曳、碰撞偵測 | **大** | 拖拉手感、觸控相容性、碎片吸附邏輯要重寫一整套演算法；沒有原始碼可讀（已 minify），只能黑箱重寫，回歸測試成本高 |
| 2 | jQuery UI `draggable`（snapPuzzle 內部依賴） | `vendor/javascript/jquery.snap-puzzle.min.js`（整個檔案，3 行 minified，無法逐行定位） | snapPuzzle 插件本身建立在 jQuery UI draggable 之上 | **大**（與 #1 是同一顆風險，拆不開） | 同上 |
| 3 | jQuery UI touch-punch shim | `vendor/javascript/jquery.ui.touch-punch.js`（全檔 9 行）；載入順序見 `app/views/layouts/application.html.erb:19` | 把 jQuery UI 的 mouse event 轉譯成 touch event，讓 draggable 在手機上可用。本身是舊站 `wheel_puzzle.php:166` 抽出來的 inline shim | **小**（若 #1/#2 換成原生方案，這個 shim 直接整個刪除，不用改寫） | 低，純粹是 #1 的附屬品，非獨立風險點 |
| 4 | Bootstrap 4 Modal（`$().modal()` 系列，內部呼叫） | `app/views/game/home/show.html.erb:39,50-65`（`data-toggle="modal"` / `data-target="#descModal"` / `data-dismiss="modal"`） | 「玩法說明」彈窗，純顯示圖片，無資料互動 | **小**：Bootstrap 5 拿掉 jQuery 依賴後這段可原封不動（HTML data attribute 不變）；若改 Stimulus，用一個 20 行內的 controller 就能取代 | 低，功能單純（開/關 modal，無表單、無焦點陷阱以外的邏輯） |
| 5 | Bootstrap 4 Carousel（`$().carousel()` 系列，內部呼叫） | `app/views/game/jobs/show.html.erb:21-44`（`data-ride="carousel"` / `data-slide="prev/next"`） | 選職業的圖片輪播，含左右箭頭切換 | **中**：輪播的滑動手感、鍵盤／觸控支援要重做；Bootstrap 5 的 carousel 已不依賴 jQuery，若目標是「去 jQuery 但留 Bootstrap」則這項零成本 | 低-中，功能有互動（點擊切換、可能的觸控滑動），若自寫 Stimulus 版本要覆蓋觸控滑動才不會體驗倒退 |
| 6 | Layout 打字機效果 `type()` | `app/views/layouts/application.html.erb:26-48`（定義），**未在任何 view 中被呼叫**（repo 內 `grep -rn "type("` 沒有找到 view 端呼叫點） | 2018 舊站遺留的逐字顯示特效函式，目前是死碼 | **小**（建議直接刪除，而非「改寫成 Stimulus」——沒有呼叫方就沒有改寫的必要） | 低，但屬於「該不該保留」的判斷，已在總覽提及、留給後續決策 |
| 7 | `window.jQuery` 全域物件依賴（判斷插件就緒） | `app/javascript/controllers/puzzle_controller.js:43`（`isReady()` 檢查 `window.jQuery && window.jQuery.fn.snapPuzzle`） | Stimulus controller 主動探測 jQuery 是否載入完成，屬於 #1 拼圖方案的一部分，非獨立依賴 | 隨 #1 一併處理 | 低，是防禦性寫法，不是額外風險 |

**不需要 jQuery 的部分**（避免誤判為依賴）：`team_poll_controller.js`、`job_poll_controller.js`、`active_question_poll_controller.js`、`boss_poll_controller.js`、`bear_controller.js`、`poll_controller.js`、`lib/api.js` 全部是原生 `fetch`/Stimulus，**與 jQuery 完全無關**，這 6 個 controller + 1 個 lib 已經是「現代化完成」的部分（見下節）。

---

## CSS 現況

### `app/assets/stylesheets/site.scss`（97 行）

- 管轄範圍：全站共用（layout footer／`.dialog` 對話框樣式／登入頁／首頁按鈕群組／地圖返回鍵／熊讚頁縮放按鈕定位／魔王頁疊圖與 HP 條）。
- 魔術數字：約 15 處寫死的 `rem`/`px` 定位值，例如 `.login-dialog{ top: 23rem; left:10%; right: 10% }`（39行）、`.home-group{ padding-left: 5rem; padding-right: 5rem; }`（44-45行）、`.map-menu{ top: 1rem; left: 1rem; }`（51-53行）——這些都是「配合某張固定尺寸背景圖手調出來的座標」，換圖或換版型必須重新試錯。
- 與 Bootstrap 耦合：低度耦合，多數 class 是自訂命名（`.dialog`/`.login-*`/`.boss-*`），只有少數地方覆寫 Bootstrap 語意元素（`header`/`footer`/`main` 標籤選擇器，7-22行），不是靠 override `.btn`/`.card` 等 Bootstrap class 本身，所以理論上換 CSS 框架時這份檔案可以整份重寫而不必先拆解 Bootstrap 依賴。
- `!important`：**未發現任何 `!important` 使用**（已用 `grep -n '!important' app/assets/stylesheets/*.scss` 確認，結果為空）。
- 打字機效果的 `@keyframes blink`（31-33行）目前无對應可視化呼叫者（`type()` 是死碼，見上表 #6），這段 CSS 同樣是孤兒。

### `app/assets/stylesheets/boss.scss`（81 行）

- 管轄範圍：只服務 `game/bosses/show.html.erb` 一頁，透過 `content_for :head` 額外載入（`app/views/game/bosses/show.html.erb:8-10`），刻意不進全站 layout。
- 魔術數字：**11 個怪物 class（`.mon01`~`.mon09`,`.mon11`，37-46行）逐一手動寫死 `width`/`bottom`/`left` 三個數值**，且彼此數值差異看不出規律（例如 `.mon04{ width: 40%; bottom: 5rem; left: 8rem; }` vs `.mon11{ width: 150%; bottom: 13rem; left: -6rem; }`），明顯是針對個別怪物立繪原始圖片比例手調過的結果——這是全站「改一次要重新量測」成本最高的一段 CSS。
- 與 Bootstrap 耦合：低，同樣是自訂 class + 少量標籤選擇器覆寫。
- `!important`：同樣未發現。
- 額外含一組 `.ripple`/`.rippleEffect` 點擊漣漪動畫（63-81行），但目前**没有任何 view 或 controller 用到 `.ripple`/`.rippleEffect` class**（已用 `grep -rn "ripple" app/views app/javascript` 確認無結果）——這也是孤兒 CSS，可能是原本設計要用在「攻擊！」按鈕點擊回饋上但沒接上。

---

## 已經現代化的部分（Stimulus / Turbo，避免重複工）

| Controller | 檔案 | 負責什麼 |
|---|---|---|
| `poll_controller.js` | `app/javascript/controllers/poll_controller.js`（54行） | 共用輪詢基底類別：固定 ≤500ms 間隔打 `fetch`，子類別只需實作 `onData(json)`。取代舊站 server-side blocking `while(true)+usleep` 輪詢。 |
| `team_poll_controller.js` | `app/javascript/controllers/team_poll_controller.js`（28行） | 冒險隊伍頁：即時更新隊名／人數，隊長命名完成後自動導頁到選職業頁。 |
| `job_poll_controller.js` | `app/javascript/controllers/job_poll_controller.js`（30行） | 選職業頁：即時停用已被隊友選走的職業按鈕。 |
| `active_question_poll_controller.js` | `app/javascript/controllers/active_question_poll_controller.js`（42行） | 主選單／地圖頁：偵測隊友已開始的題目或魔王戰，自動導頁跟上。 |
| `boss_poll_controller.js` | `app/javascript/controllers/boss_poll_controller.js`（69行） | 魔王戰頁：即時更新宣戰人數／HP／攻擊次數，倒數計時，擊敗後導向積分頁。 |
| `puzzle_controller.js` | `app/javascript/controllers/puzzle_controller.js`（72行） | 等圖片真正 layout 完成後才初始化 jQuery 拼圖插件（見上方 jQuery 總表 #1），拼圖完成後解鎖答案輸入框。**這個 controller 本身是 Stimulus，但包著一個沒法脫離 jQuery 的插件**，是唯二真正卡住「全面 Stimulus 化」目標的地方之一。 |
| `bear_controller.js` | `app/javascript/controllers/bear_controller.js`（21行） | 熊讚題照片的「點擊放大」互動，純 CSS class toggle，無 jQuery。 |
| `lib/api.js` | `app/javascript/lib/api.js`（60行） | 共用 `fetch` 包裝（自動帶 CSRF token、JSON 序列化），所有 poll controller 共用。 |
| Turbo | `app/javascript/application.js`（29行） | 自訂 `Turbo.config.forms.confirm`，把 `data-turbo-confirm` 從 `window.confirm` 換成頁內自訂 modal（避免內嵌瀏覽器吃掉原生 confirm dialog）；全站 `button_to ... form: { data: { turbo_confirm: ... } }` 都吃這個設定（例：`app/views/game/home/show.html.erb:47`、`app/views/game/questions/_hint_panel.html.erb:20`）。 |

**結論**：7 個 controller 中，6 個已完全脫離 jQuery；唯一卡住的是 `puzzle_controller.js` 包裹的 `jquery.snap-puzzle.min.js`（+ jQuery UI draggable + touch-punch），這是「全面 Stimulus 化」目標唯一剩下的硬骨頭，其餘 Bootstrap 4 JS 元件（modal/carousel）用量很小、且是「換 Bootstrap 5」就能順便解決、不需要另外投入 Stimulus 改寫成本的部分。

---

## 量化數據

| 指標 | 數值 | 取得指令 |
|---|---|---|
| View 檔案數（盤點範圍內） | 22（含 1 個 layout、19 個 page view、2 個 partial） | `find app/views/{layouts,welcome,game,admin} -type f \| wc -l` |
| View 總行數 | 1126 | `wc -l app/views/layouts/application.html.erb app/views/welcome/*.erb app/views/game/**/*.erb app/views/admin/**/*.erb` |
| Inline `<script>`／`<script src>` 標籤數 | 5（1 個 inline 打字機邏輯 + 4 個 CDN `<script src>`，全部集中在 layout） | `grep -rn "<script" app/views \| wc -l` |
| 出現 inline `<script>` 的檔案數 | 1（僅 `application.html.erb`） | `grep -rln "<script" app/views` |
| Inline `style="..."` 屬性數（原始 HTML 字串比對） | 7 | `grep -rn 'style="' app/views \| wc -l`（注意：`admin/serial_codes/index.html.erb` 的 `number_field style: "width: 8rem;"` 是 Rails helper 參數形式，非產出前 HTML 可被此 grep 命中，故此數字略低於實際渲染後的 style 屬性數） |
| 出現 inline style 的檔案數 | 4 | `grep -rln 'style="' app/views` |
| `$(`／`jQuery` 呼叫次數（含註解，不含 vendor） | 12 行命中（其中僅 5 行是**會執行的程式碼**：layout 打字機 4 行 `$(...)` + puzzle_controller.js 的 `window.jQuery`/`window.jQuery.fn` 2 處算 1 行；其餘為註解文字說明） | `grep -rn '\$(' app/views app/javascript; grep -rn 'jQuery' app/views app/javascript` |
| `site.scss` 行數 | 97 | `wc -l app/assets/stylesheets/site.scss` |
| `boss.scss` 行數 | 81 | `wc -l app/assets/stylesheets/boss.scss` |
| `!important` 出現次數 | 0 | `grep -n '!important' app/assets/stylesheets/*.scss` |
| Stimulus controller 數 | 7（不含 `application.js`/`index.js` 兩個框架接線檔） | `find app/javascript/controllers -name '*_controller.js' \| wc -l` |
| Vendor jQuery 相關檔案數 | 2（`jquery.snap-puzzle.min.js` 3 行 minified、`jquery.ui.touch-punch.js` 9 行） | `wc -l vendor/javascript/*.js` |
