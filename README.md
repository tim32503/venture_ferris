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
- **Boss 戰爆擊只在伺服器端節流窗外採信。** 遊戲化後的弱點爆擊由前端「宣告」
  （`critical` 參數），但傷害計算與 2 秒節流（`boss_battles.last_critical_at`、
  `BossBattle#critical_ready?`）全在伺服器端——竄改 client 連發爆擊，超出節流
  窗的宣告一律按普通攻擊計，延續全案「驗證都在伺服器端」的原則。
- **棄用的 Google Image Charts 改用 `rqrcode`。** 舊站後台序號產生器用
  Google 已下架的 Image Charts API 產生 QR code；新版改用 `rqrcode` gem
  在本機產生（`Admin::SerialCodesController`）。
- **前端零 jQuery、零 CSS 框架 CDN。** 舊站整套 jQuery／jQuery UI／
  Bootstrap 4／Font Awesome CDN 已全數移除；拼圖拖拉是自寫的原生
  Pointer Events 引擎，視覺層是 Tailwind CSS v4，細節見下方
  〈前端：全 Hotwire／Tailwind，零 jQuery、零 CSS 框架 CDN〉。

## 相較原作的新增功能

重構之外，這個版本也加上了原作沒有的玩法與營運能力：

- **Boss 戰遊戲化**：點怪物本體攻擊、受擊震動與傷害數字、連擊計數、HP 條
  三段變色與擊敗演出；隨機浮現的**弱點爆擊**（×2，伺服器端 2 秒節流防刷，
  見重構亮點）。第 10/11 關依原始劇情考證還原為「摩天輪魔王」雙型態連戰。
- **四職業主動技**（每場王戰每人一次，`BossSkillUse` unique index 保證；
  效果與授權全在伺服器端，client 只傳意圖）：

  | 職業 | 被動 | 主動技 |
  |---|---|---|
  | 阿北 | 王戰時限 +10 秒 | 倚老賣老・本場時限再 +10 秒 |
  | 鄉民 | 每次攻擊 +2 | 肉搜公審・立即 5 點傷害 |
  | 鞋姊 | 提示不扣分 | 醍醐灌頂・下一擊必定爆擊 |
  | 罔美 | 結算 +100 分 | 聚光燈・5 秒爆擊窗＋立即弱點 |

- **營運後台**（`/admin`，全區伺服器端驗證）：營運總覽 Dashboard（進度
  分布、進行中戰鬥、兌獎池餘量）、隊伍管理（搜尋/詳情/個資遮罩，刪除僅限
  test_mode 隊伍且 controller 層硬擋）、題目管理（內容/提示子表/Boss 參數/
  **答案重設**——輸入明文伺服器轉 digest、永不回顯）、兌獎序號池管理與
  批次產生、隊伍序號產生器（rqrcode QR）。

## 架構總覽

### Models

| Model | 對應舊表 | 說明 |
|---|---|---|
| `Team` | WHEEL_PLAYER_MAIN | 隊伍，16 碼序號登入；`test_mode` 標記示範/彩排隊伍 |
| `Player` | WHEEL_PLAYER_USER | 隊伍成員；1 隊長＋最多 3 隊員；`job` 可為 null（未選職業） |
| `Question` | QUEST_MAIN | 11 道謎題；答案只存 SHA-256 digest，不存明文 |
| `QuestionHint` | （舊 QUEST_MAIN.QUESTION_HINT1/2 欄位） | 某題的提示，`[question_id, position]` 唯一；「沒有提示列」就是「這題不能用提示」 |
| `Boss` | （舊站無此表） | 怪物主檔，只有 `sprite`；10 隻對 11 題（第 10/11 題共用摩天輪魔王） |
| `QuestionAttempt` | QUEST_LOG | 某隊某題的計時/提示紀錄；`ended_at` 為 null 代表進行中 |
| `BossBattle` | BOSS_LOG | 每題一場王戰，`question_id` 外鍵；`[team_id, question_id]` 唯一 |
| `BossReady` | （舊 READY_COUNT 欄位） | 玩家對某場王戰的「準備」標記，join table 保證冪等 |
| `BossSkillUse` | （新增） | 玩家於某場王戰的主動技使用紀錄，`[boss_battle_id, player_id]` 唯一＝每場每人一次 |
| `ScoreEntry` | QUEST_SCORE | 每隊每題最終分數，`question_id` 外鍵，伺服器端算好後寫入 |
| `RewardCode` | WHEEL_PLAYER_REWARD | 兌獎序號池；以 email 為 key，一人固定配發 2 組 |
| `Admin` | （新增，取代舊站前端驗證機制） | 後台帳號，`has_secure_password` |

文字版 ERD（`1—N` 表示一對多）：

```
Team 1─N Player          UQ [team_id, email]（一個 email 在一隊只佔一個席位）
                         UQ [team_id, job] WHERE job IS NOT NULL（同隊職業不重複）
Team 1─N QuestionAttempt N─1 Question
Team 1─N BossBattle      N─1 Question      UQ [team_id, question_id]
         BossBattle 1─N BossReady N─1 Player
         BossBattle 1─N BossSkillUse N─1 Player
Team 1─N ScoreEntry      N─1 Question      UQ [team_id, question_id]
Boss 1─N Question （10 隻怪對 11 題；第 10/11 題指向同一列，
                    以 questions.boss_phase = 1/2 區分型態）
Question 1─N QuestionHint                  UQ [question_id, position]
RewardCode （獨立，以 player_email 字串關聯，不用外鍵——沿用舊站以 email
             為配發 key 的語意，允許玩家換序號重新登入仍拿回同一組獎品）
```

`ScoreCalculator`（`app/models/score_calculator.rb`）是一個 PORO，不對應
資料表，只負責把「該題分數／時間分數／提示扣分／王戰加分／職業加分」組成一筆
`ScoreEntry`。

### 刻意保留的非正規設計

正規化這一輪的重點不只是「把該拆的拆掉」，也包括**寫清楚哪些沒拆、為什麼**。
完整論證見 `docs/SCHEMA_REDESIGN.md` §5，摘要：

- **`reward_codes.player_email` 是字串 key 而不是 `player_id` 外鍵。** 兌獎配發
  以「人」為單位而非「隊籍」；`sessions#create` 在玩家換序號時會建立**新的
  `Player` 列**，改成外鍵會讓同一個人重複領獎。這個語意承襲自 2018 dump 的
  `WHEEL_PLAYER_REWARD.USER_ID`（本身就是 email 欄位）。
- **`boss_battles.hp` 是 `questions.boss_hp` 的複本。** 那是**開戰瞬間的快照**：
  進行中的戰鬥不該因為題目被調參而改變難度。
- **`boss_time_limit` 反而不做快照。** 因為它本質是動態的——隊上有「阿北」會
  +10 秒，而隊員可以在開戰前才換職業。這個與上一項的不對稱是刻意的。
- **`score_entries` 存 5 個分項＋可導出的 `total_score`。** 分項取決於結算當下的
  隊伍職業組成，事後無法重算，整列是一次結算的物化快照。
- **`players` 同時承載 person（`email`）與 membership（`team_id`/`role`/`job`）
  與聯絡資訊。** 理論上有跨隊更新異常，但 2018 真實資料 573 名玩家中跨隊 email
  是 **0 筆**；這是一場活動的遊戲，不是 CRM。
- **`boss_hp`/`boss_time_limit` 留在 `questions` 而沒有移進 `bosses`。** 它們是
  「這一戰」的參數而非「這隻怪」的屬性——第 10/11 題打同一隻怪但難度本來就不同
  （`base_score` 是 1000 vs 3000），移過去會強迫兩題同難度，那是行為變更。
  同理 `bosses` 刻意不加 `name`：舊 dump 沒有怪物名稱，加了就是憑空發明。
- **`Player::MAX_MEMBERS = 3` 只在應用層，`MAX_LEADERS = 1` 卻可以落到 DB。**
  唯一性能用 partial unique index 表達，計數上限不行（需要 trigger）；**不為了
  對稱而引入 trigger**。
- **外鍵一律 RESTRICT，刪除連鎖只在 Rails 的 `dependent: :destroy`。** 繞過應用層
  的刪除會失敗而不是靜默毀掉歷史。

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
  sprockets pipeline 共存），全站 view（含後台）依 `docs/UI_STYLE_GUIDE.md` 的
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
- **`mon10.gif` 從未存在，第 10/11 題其實是同一隻「摩天輪魔王」的雙型態連戰。**
  原始素材備份裡怪物圖檔只有 10 個檔案（`mon01~09.gif` + `mon11.gif`），一度
  被當成「第 10 題圖檔遺失」處理。考證還原後的原始劇情文本（`db/seeds.rb`）
  發現：第 10 題標題是「魔王佔據的摩天輪」，第 11 題緊接著是同一場戰鬥的延續
  （`auto_start`，沒有獨立的宣戰大廳），且素材命名習慣以 F1/F2 表示同一隻怪
  的兩個型態——三者合起來指向「第 10/11 題本來就是對同一隻摩天輪魔王的連續
  戰鬥」，`mon10.gif` 推測從未作為獨立素材存在過，不是遺失。本次改以
  `mon11.gif` 還原設計意圖：第 10 題（第一型態）套用濾鏡＋略小尺寸顯示同一張
  立繪，第 11 題（最終型態）維持原色滿版。這個考證結論後來直接變成 schema：
  `bosses` 表的第 10、11 題**指向同一列**，型態由 `questions.boss_phase` 決定，
  取代了原本散在三個 helper method 裡的 `number == 10 ? 11 : number` 判斷
  （見 `docs/SCHEMA_REDESIGN.md` §2-3——這也是「抽 `bosses` 表」這個決策從
  「不抽」翻轉成「抽」的原因：怪物與題目不是 1:1）。視覺樣式見
  `app/assets/stylesheets/boss.scss` 的 `.boss-phase-1`。
  `boss_asset_available?` 的文字說明 fallback 機制仍保留，作為其餘題號未來若
  素材缺失時的防禦——`sprite` 是 NOT NULL 字串，這跟 asset 檔案存不存在是兩件事。

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
