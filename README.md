# 勇闖摩天輪（Venture Ferris）

一個把 2018 年台北市商業處「勇闖摩天輪」團隊實境解謎活動網站，從 2018 年老舊
的 CodeIgniter 3 專案重構為 Rails 7.2 的技術作品集專案。

## 專案簡介

原案是 2018 年在台北大直美麗華旁舉辦的線下團隊實境解謎活動：玩家掃描活動序號
登入、組成 1 隊長＋最多 3 隊員的隊伍、選擇「阿北／鄉民／鞋姊／罔美」四種職業
（各有不同的解謎輔助效果），接著在三張地圖上依序破解 11 道謎題（拼圖題／問答
題／密碼題），每破解一題就會觸發一場「打王」——對該題專屬的怪物即時累計攻擊
次數直到擊敗為止，全部關卡結束後依時間、提示使用次數、職業加成計算總分，最後
用分數兌換獎品序號。

這個 repo 是該遊戲玩法邏輯的完整重寫，用來展示如何把一個「前端幾乎沒有任何
伺服器端把關」的 10 年前 PHP 專案，改寫成一個資料驗證、權限控管都在伺服器端
完成的現代 Rails 應用。

> 原案的活動素材、美術與品牌名稱版權屬原主辦單位所有，本專案僅作**技術重構
> 展示**用途，不用於任何商業或活動用途。詳見〈素材授權註記〉。

## 重構亮點

這份重構的重點不是「把 PHP 翻譯成 Ruby」，而是把幾個舊站架構上有明確安全或
維護性問題的地方，改成 Rails 慣用且正確的做法：

- **答案驗證從前端搬到伺服器端。** 舊站 `wheel_question.php:241` 會把題目的
  正確答案直接印在頁面的 HTML／JS 裡，玩家打開瀏覽器開發工具就能看到答案。新
  版新增了 `POST /game/questions/:number/answer`（`Game::QuestionsController`）
  做伺服器端比對，`questions#show` 的 render 內容完全不含 `answer_digest`
  （見 `app/models/question.rb` 的 `Question.digest_for`／`#answer?`）。
- **後台驗證從前端遮罩改為伺服器端驗證。** 舊站 admin 後台原本只用一個
  第三方前端驗證 SDK 擋畫面，沒有任何伺服器端檢查，任何人直接打 API 或修改
  JS 都能繞過；新版 `Admin`（`app/models/admin.rb`）用 `has_secure_password`
  + session，`Admin::BaseController#require_admin` 在每個 action 前檔。
- **CSRF 保護啟用。** 舊站整站關閉 CSRF；新版沿用 Rails 預設全站開啟
  （`app/views/layouts/application.html.erb` 的 `csrf_meta_tags`，前端
  fetch 一律透過 `app/javascript/lib/api.js` 帶 `X-CSRF-Token`）。
- **輪詢機制從伺服器端 long-poll 改成 client 端定時輪詢。** 舊站
  `Wheel_model.php` 用 `while(true) + usleep()` 在單個 request 裡阻塞等待
  狀態變化；新版改用 Stimulus controller（`active_question_poll_controller.js`
  等）每 500ms 固定間隔打一次 `status.json`，endpoint 本身永遠立即
  `render json:` 回應，不佔用 worker。
- **Boss 挑戰 ready 狀態冪等化。** 舊站的 `BOSS_LOG.READY_COUNT` 是一個計數
  欄位，玩家重新整理頁面就會被重複計數，灌爆人數；新版改成 `BossReady`
  join table（`team_id/boss_battle_id + player_id` 唯一索引），ready 人數
  由 `COUNT` 出來，同一個玩家按幾次都只算一次。
- **棄用的 Google Image Charts 改用 `rqrcode`。** 舊站後台序號產生器用
  Google 已下架的 Image Charts API 產生 QR code；新版改用 `rqrcode` gem
  在本機產生（`Admin::SerialCodesController`）。
- **前端零 jQuery、零 CSS 框架 CDN。** 舊站整套 jQuery／jQuery UI／
  Bootstrap 4／Font Awesome CDN 已全數移除；拼圖拖拉是自寫的原生
  Pointer Events 引擎，視覺層是 Tailwind CSS v4，細節見下方
  〈前端：全 Hotwire／Tailwind，零 jQuery、零 CSS 框架 CDN〉。

## 架構總覽

### Models

| Model | 對應舊表 | 說明 |
|---|---|---|
| `Team` | WHEEL_PLAYER_MAIN | 隊伍，16 碼序號登入；`test_mode` 標記示範/彩排隊伍 |
| `Player` | WHEEL_PLAYER_USER | 隊伍成員；1 隊長＋最多 3 隊員；`job` 可為 null（未選職業） |
| `Question` | QUEST_MAIN | 11 道謎題；答案只存 SHA-256 digest，不存明文 |
| `QuestionAttempt` | QUEST_LOG | 某隊某題的計時/提示紀錄；`ended_at` 為 null 代表進行中 |
| `BossBattle` | BOSS_LOG | 每題一隻王（`boss_no` 與題號共用編號） |
| `BossReady` | （舊 READY_COUNT 欄位） | 玩家對某場王戰的「準備」標記，join table 保證冪等 |
| `ScoreEntry` | QUEST_SCORE | 每隊每題最終分數，伺服器端算好後寫入 |
| `RewardCode` | WHEEL_PLAYER_REWARD | 兌獎序號池；以 email 為 key，一人固定配發 2 組 |
| `Admin` | （新增，取代舊站前端驗證機制） | 後台帳號，`has_secure_password` |

文字版 ERD（`1—N` 表示一對多）：

```
Team 1─N Player
Team 1─N QuestionAttempt N─1 Question
Team 1─N BossBattle 1─N BossReady N─1 Player
Team 1─N ScoreEntry
RewardCode （獨立，以 player_email 字串關聯，不用外鍵——沿用舊站以 email
             為配發 key 的語意，允許玩家換序號重新登入仍拿回同一組獎品）
```

`ScoreCalculator`（`app/models/score_calculator.rb`）是一個 PORO，不對應
資料表，只負責把「該題分數／時間分數／提示扣分／王戰加分／職業加分」組成一筆
`ScoreEntry`。

### 路由設計

- 玩家端集中在 `namespace :game`（`Game::BaseController` 統一檔
  `require_player_session`），對照舊站 38 個 `Wheel` controller action，一一
  對應成 RESTful 路由（詳見 `docs/REFACTOR_PLAN.md` §2 的完整對照表）。
- 後台集中在 `namespace :admin`（`Admin::BaseController` 統一檔
  `require_admin`）。
- 公開頁（首頁、隱私權、錯誤頁）留在頂層，不進 namespace。

### 前端：全 Hotwire／Tailwind，零 jQuery、零 CSS 框架 CDN

這個專案的前端經歷過一次完整的現代化（`docs/UI_MODERNIZATION_PLAN.md` U0～
U3），起點是 2018 年原站直接沿用的 jQuery 3.3.1／jQuery UI 1.12.1／
Bootstrap 4.1.3（含 Font Awesome）全套 CDN，終點是：

- **拼圖拖拉是原生 Pointer Events 引擎，不是套件。** 舊站的
  `jquery.snap-puzzle.min.js`（第三方 minified jQuery plugin，含 jQuery UI
  draggable + touch-punch 模擬觸控）已整個移除，改由
  `app/javascript/controllers/puzzle_controller.js` 用瀏覽器原生
  Pointer Events（`pointerdown`/`pointermove`/`pointerup` + `setPointerCapture`）
  重寫拖拉與吸附判定，滑鼠與觸控天生統一，不需要任何相容層。
- **Bootstrap 4 的 Modal／Carousel 也都退場了**：首頁「玩法說明」彈窗改用
  瀏覽器原生 `<dialog>` 元素（`dialog_controller.js`），選職業的輪播改用 CSS
  `scroll-snap`（`carousel_controller.js`），兩者都不再需要 jQuery。
- 現存的每一個 Stimulus controller（`app/javascript/controllers/*`）都是
  原生 DOM API 或 `fetch`，`app/javascript/lib/api.js` 統一處理
  `X-CSRF-Token`。全站前端**沒有任何一行 jQuery**，也沒有任何 Bootstrap／
  Font Awesome 的 `<script>`／`<link>` CDN 標籤。
- 視覺層改用 **Tailwind CSS v4**（`tailwindcss-rails` gem，免 Node、與既有
  sprockets pipeline 共存），全站 22 個 view 依 `docs/UI_STYLE_GUIDE.md` 的
  tokens／元件配方逐頁改版；`app/assets/stylesheets/site.scss` 與
  `boss.scss` 兩份 2018 年手調座標的舊 SCSS 只保留 Tailwind 覆蓋不到的功能性
  樣式（拼圖引擎的幾何定位、Boss 立繪疊圖的相對座標、地圖熱點、`scroll-snap`
  輪播），不再承擔任何頁面的主題視覺。

### CSS 編譯器

`app/assets/tailwind/application.css`（`@import "tailwindcss"`）經
`tailwindcss-rails` 編譯出 `app/assets/builds/tailwind.css`，負責全站絕大部分
樣式。`sassc-rails`（`libsass` 綁定）現在只剩下編譯上一節提到的兩份少量自訂
CSS（`site.scss`／`boss.scss`）——拼圖/Boss 疊圖等 Tailwind utility 表達不了
或不划算表達的功能性定位樣式。`sassc`/`sassc-rails` 上游已宣告 EOL、不再
維護；**未來待辦**：換成 `dartsass-rails`（官方目前建議的替代方案），屆時
只需要把兩個 `.scss` 檔案原樣搬過去、調整 Gemfile，不影響任何其他程式碼。

## 本機啟動

```bash
# 1. 安裝 Ruby gems（Ruby 版本見 .ruby-version，目前 3.3.5）
bundle install

# 2. 準備資料庫（需要本機有 PostgreSQL 在跑；連線設定見 config/database.yml，
#    預設用本機 socket + 目前系統使用者，一般本機開發不用另外設帳密）
bin/rails db:prepare

# 3. 灌入資料（11 題已還原原文的題目、demo 隊伍、20 組正式序號、100 組兌獎序號、
#    後台帳號；見 db/seeds.rb）
bin/rails db:seed

# 4. 啟動伺服器
bin/rails server
```

打開 http://localhost:3000 後，首頁會有一個「▶ 直接體驗（Demo）」按鈕，點下去
會（`POST /game/session` 帶 `demo: "1"`，見
`Game::SessionsController#create_demo!`）當場建立一個全新的單人示範隊伍
（`test_mode: true`、隨機序號、隨機訪客 email）並直接以該隊隊長身分登入，
不需要湊到 4 個人，也不會和其他訪客互相搶名額——每次點擊都是獨立的一支隊，
可以一路把 11 題 + Boss 戰 + 結算 + 兌獎跑完。`db/seeds.rb` 另外保留的固定
序號 `Team::DEMO_SERIAL_NO`（見 `app/models/team.rb`）只是展示資料本身、
**刻意不預塞任何玩家**，不是首頁 Demo 按鈕實際登入的隊伍。示範資料
（`db/seeds.rb`）把所有題目的王戰 HP 設定成 10、基準時限 60 秒（隊上有
「阿北」職業時 +10 秒），方便單人在合理時間內打完全部 Boss；已登入 demo
隊伍的頁面（`/game`）會在主選單標題旁顯示一個「Demo」標籤。

後台入口在 `/admin/login`。帳號由 `db/seeds.rb` 建立，email 固定為
`admin@venture-ferris.example`，密碼可用環境變數指定：

```bash
ADMIN_PASSWORD=your-password bin/rails db:seed
```

若未設定 `ADMIN_PASSWORD`，seeds 會用預設密碼 `changeme`（僅供本機示範，正式
環境請務必自行設定這個環境變數後再跑 seeds）。

## 測試

```bash
# Model + integration tests
bin/rails test

# System tests（需要本機有 Chrome，見 test/application_system_test_case.rb）
bin/rails test:system

# Lint
bin/rubocop

# 安全性靜態掃描
bin/brakeman
```

CI（`.github/workflows/ci.yml`）在每個 PR 上會跑上述四項，外加
`bin/importmap audit`。

## 素材授權註記

本專案沿用的怪物立繪、地圖、Boss 場景等美術素材（`app/assets/images/*`）與
活動品牌名稱（頁尾「Escapeholics密室逃脫」等），版權屬 2018 年原活動主辦
單位（臺北市商業處、臺北市商圈產業聯合會）與原委製廠商所有。本專案僅作為
**Rails 重構技術展示**，不含任何商業用途，亦不含原站的真實使用者資料、金鑰
或帳密。

## 已知限制

- **題目原文已還原。** 原始 SQL dump 已於 2026-08-29 尋回，`db/seeds.rb` 的
  11 題標題／題目敘述／難度／提示／解說已改為 `QUEST_MAIN` 的原文。其中第 1、
  2、9 題（拼圖／熊讚特殊題）在原始資料庫的 `QUESTION_PASSWORD` 欄位本身就是
  空字串，代表當年的正解判斷不是靠這個欄位（推測寫死在已遺失的舊站前端
  程式碼中），因此這三題仍沿用重構時另行編寫的示範答案。答案依既有設計
  仍只存 SHA-256 digest（`Question.digest_for`，見 `app/models/question.rb`），
  不會明文寫回任何檔案。
- **`mon10.gif` 遺失。** 原始素材備份裡怪物圖檔只有 10 個檔案（`mon01~09.gif`
  + `mon11.gif`），第 10 題的怪物圖檔在備份當時就已經不存在，並非本次重構
  遺漏；`app/helpers/game/bosses_helper.rb` 的 `boss_asset_available?` 會偵測
  缺檔並讓 `app/views/game/bosses/show.html.erb` 改顯示文字說明，而不是壞圖。

## 部署待辦

這個專案目前只整備到「本機/一般 Rails 環境可以正常開機」的程度，尚未決定
實際部署平台，所以刻意不生成任何平台專屬設定（例如 Kamal 的
`config/deploy.yml`）。若之後要部署，至少需要：

- 決定部署目標（Render／Fly.io／Kamal + VM／其他）並補上對應設定檔。
- 設定 `RAILS_MASTER_KEY`（或改用其他 credentials 管理方式）。
- 設定 `VENTURE_FERRIS_DATABASE_PASSWORD`（見 `config/database.yml` 的
  production 區塊）。
- 若要啟用 Rails 的 Host header 保護，設定環境變數 `ALLOWED_HOSTS`
  為逗號分隔的允許網域清單（見 `config/environments/production.rb`）；
  不設定則維持 Rails 預設（不限制 Host）。
- 重新產生正式環境用的序號池與兌獎序號池（目前 seeds 裡的都是示範用途）。
- 首頁 Demo 入口（`POST /game/session` 帶 `demo=1`）目前**沒有節流**：任何
  訪客每點一次就建立一組新的 `Team`+`Player` 並在兌獎時消耗 `RewardCode`
  池。公開部署前應加上 rate limit（如 `rack-attack`）與 `test_mode` 隊伍的
  定期清理排程。
