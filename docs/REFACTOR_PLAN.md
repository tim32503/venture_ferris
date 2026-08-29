# venture_ferris 重構計畫 v2（Taipeicooc2018 → Rails 7.2）

> 依據：`docs/legacy/ANALYSIS.md`（盤點報告，含勘誤見 §8）＋ opus 反方審查結論（2026-08-19）。
> 目標：把 2018 年 CodeIgniter 團隊實境解謎遊戲重構成可公開上架的 Rails 7.2 作品集專案。
> 原則：**UX 流程對齊舊站；架構全面 Rails 化；舊站的已知 bug 依 §1.4/§8 修正，不對齊壞行為**。

## 0. 已知限制與對策

| 限制 | 對策 |
|---|---|
| 無 SQL dump，題目內容已遺失 | seeds 用示範內容重建 11 題＋Boss＋獎品序號池，標明 sample data |
| 舊後台無伺服器端驗證、CSRF 關閉 | 後台 `has_secure_password` + session；全站開 CSRF（Rails 預設） |
| **舊站答案比對在前端**（`wheel_question.php:241` 把答案印進 HTML） | 新增 `POST /game/questions/:number/answer` 伺服器端比對；`questions#show` 不得 render 答案。**README 主打賣點** |
| 舊站輪詢是伺服器端 long-poll（`Wheel_model.php:219-239` 等，`while(true)+usleep`） | 改 client 端固定間隔輪詢（300-500ms 對齊舊站前端），endpoint 必須無阻塞 `render json:` |
| 明文 DB 帳密、Firebase 金鑰、個人 Gmail/網域硬編碼 | 不帶入；設定走 credentials/ENV。驗收 grep 關鍵字：`firebase`、`gstatic.com/firebasejs`、`taipeicooc2018`、`curihaosity.xyz`、`escapeholics.com`、`tim32503`、`AP_WHEEL` |
| Google Image Charts QR API 已棄用 | `rqrcode` gem 本地產生 |
| `site.css` 是 **Big5** 編碼（非 UTF-8）；`boss.css` 是 UTF-8+CRLF | `iconv -f BIG5 -t UTF-8` **先轉再放**進 stylesheets/；放完跑 `assets:precompile` 驗證 |
| 現有 repo baseline 是紅的：views 已引用未搬的 assets（root 頁 500）、layout 缺 `javascript_importmap_tags`/`csrf_meta_tags`、殘留 5 個 Firebase CDN 標籤、`window.history.forward(1)` 與 Turbo 衝突 | **P0 前置修復批次**（見 §5） |
| 素材為 2018 活動委製（怪物/立繪/地圖），footer 掛主辦單位名 | ⚠️ 授權待使用者確認；先照搬並在 README 註明「原案素材版權屬原主辦單位，本專案為技術重構展示」 |

## 1. 資料模型

### 1.1 Models（8 張舊表 → 8+1 個 model）

| Rails Model | 舊表 | 欄位（含約束） |
|---|---|---|
| `Team` | WHEEL_PLAYER_MAIN | `serial_no`(string16, unique index, 驗證恰 16 碼), `test_mode`(boolean, default false — 舊 `SERIAL_TYPE` 實為 test_mode 旗標), `name` |
| `Player` | WHEEL_PLAYER_USER | `team_id`, `role`(enum leader/member), `email`(舊 `USER_ID`，必為 email 格式), `job`(enum uncle/senior/netizen/celebrity，可 null=未選), `name`, `gender`(enum male/female/unspecified；unspecified=未填), `mobile`。unique index `[team_id, role, email]`；`validate :team_capacity`：**leader ≤1、member ≤3** |
| `Question` | QUEST_MAIN | `number`(1..11, unique), `kind`(enum puzzle/quiz/bear), `title`, `answer_digest`(舊 PASSWORD，正規化後存，**不明文 render**), `content`, `level`, `hint1`, `hint2`, `explanation`, `hints_enabled`(bool, 第6題 false), `auto_start`(bool, 第11題 true), `base_score`(int, 預設 1000，第11題 3000), `puzzle_rows`/`puzzle_cols`(拼圖題：第1題 4×4、第2題 1×9), `boss_hp`(int, default 120), `boss_time_limit`(int, default 30 秒) |
| `QuestionAttempt` | QUEST_LOG | `team_id`, `question_id`, `started_at`, `ended_at`(**NULL=進行中**，取代舊哨兵值 `9999-12-31`；計分/已解清單只取 `completed` scope), `hint_count`。unique index `[team_id, question_id]` |
| `BossBattle` | BOSS_LOG | `team_id`, `boss_no`(**與 question number 共用編號，每題一隻 Boss**), `started_at`, `ended_at`(NULL=進行中), `attack_count`, `hp`(default 120)。unique index `[team_id, boss_no]`。勝利門檻 `attack_count >= hp`；HP% = `(hp-attack_count)/hp*100` |
| `BossReady` | （舊 READY_COUNT 欄位） | `boss_battle_id`, `player_id`, unique index 兩者 — **取代舊的無 idempotency 計數器**（重整灌爆 bug）；ready_count 由 count 導出 |
| `RewardCode` | WHEEL_PLAYER_REWARD | `code`(unique), `test_mode`(boolean — 舊 `REWARD_TYPE` 實為 test_mode 旗標), `player_email`(nullable=未配發；**以 email 為 key 保留舊語意**：換序號重入隊仍取回同一組), `claimed_at`。配發規則：**每人恰 2 組**，`transaction` + `SELECT ... FOR UPDATE SKIP LOCKED` 原子化 |
| `ScoreEntry` | QUEST_SCORE | `team_id`, `question_number`, `question_score`, `time_score`(**負值**), `hint_score`(**負值**), `boss_score`, `job_score`, `total_score`(**伺服器端計算**，下限 0)。unique index `[team_id, question_number]` |
| `Admin`（新增） | 取代 Firebase | `email`(unique), `password_digest` |

- `CODE_MAIN` 不搬 → i18n（`config/locales/zh-TW.yml`），錯誤碼對映：`01002` 序號/角色不合法、`01003` email 格式錯誤、`01004` 隊長已被註冊（原站文案）、`01005` 隊員名額已滿（重構新增的細分碼——原站兩種情境共用 01004 的隊長文案）。
- 死代碼不搬：`Register_model`（空殼）、`Test` controller、`welcome_message.php`、`Wheel#index`（只 echo）、`Wheel#checkTimerEnd`（debug print_r）、`Wheel#test`（updateSNo 重複別名）。
- 遊戲狀態邏輯放 model/PORO：`Team#solved_count`（只算 completed）、`Team#current_map`（solved ≥9 → map3）、計分計算 `ScoreCalculator`。

### 1.2 職業效果表（採設計意圖；舊站三處實作皆有 bug，不對齊）

| 職業 | enum | 效果 | 舊站狀態 |
|---|---|---|---|
| 阿北 | uncle | Boss 時限 30→40 秒 | 壞（json "false" 為 truthy，永遠 40 秒） |
| 鄉民 | netizen | 每次攻擊 +2 | 壞（未宣告變數，攻擊 AJAX 從未送出） |
| 鞋姊 | senior | 提示不扣分 | 壞（async race，從未生效） |
| 罔美 | celebrity | job_score +100 | 壞（同上） |

seeds 明訂中文顯示名（阿北/鄉民/鞋姊/罔美）↔ enum 對映。

## 2. 路由設計（38 個舊 action 逐一對應，勘誤：非 31 個）

玩家端 `namespace :game`，後台 `namespace :admin`。

| 舊 URL | 新路由 | 備註 |
|---|---|---|
| `/` | `root "welcome#index"` | 沿用；加「▶ Demo 體驗」入口（修復批次定案：POST `demo=1` 每次建立全新單人 test_mode 隊，不帶固定序號） |
| `/welcome/privacy` | `GET /privacy` → `welcome#privacy` | 沿用 |
| `/welcome/error/{code}`、`/wheel/error/{code}` | `GET /error/:code` → `welcome#error` | i18n 訊息 |
| `/wheel/login/{sno}/{type}` | `GET /game/login?sno=&role=` → `game/sessions#new` | |
| `/wheel/register/...` | `POST /game/session` → `game/sessions#create` | 序號驗證＋寫 session |
| `/wheel/updateSNo`（換序號重入隊） | `PATCH /game/session` → `game/sessions#update` | |
| `/wheel/team*`、teamReg/teamNMGet/teamIsReady | `GET/PATCH /game/team`、`GET /game/team/status.json` | status 回 `{name, ready, total}` |
| job 系列（jobSelect/jobCheck/jobIsNull/checkJob） | `GET/PATCH /game/job`、`GET /game/job/status.json` | status 回 `{players:[{email,job}], all_selected}` — 修正舊 jobIsNull 永遠回 0 的 SQL bug |
| `/wheel/home` | `GET /game` → `game/home#show` | |
| `/wheel/map/{no?}` | `GET /game/map`（依進度 redirect 到 1 或 3）＋ `GET /game/maps/:id`(1/2/3) | **map2 是 map1 的空間下鑽（掛第 5,6,7,8,9 題），不是進度階段** |
| `/wheel/question/{qno}` 含 puzzle/bear | `GET /game/questions/:number` | 依 kind render；**不 render 答案** |
| （舊站無：前端比對答案） | **`POST /game/questions/:number/answer`** | 伺服器端比對，正解才寫 `ended_at` |
| timer/setHintCount/getHintCount/getHint/questionIsStart | `POST .../timer`、`POST .../hints`、`GET .../status.json` | |
| `/wheel/boss/{bno}`、attack/getBossHP/ready/bossIsStart | `GET /game/bosses/:number`、`POST .../attacks`、`POST .../ready`、`GET .../status.json` | **每題一隻 Boss**（mon01~11.gif）；status 回 `{hp_percent, attack_count, ready, total, started}` |
| `/wheel/score/{qno?}`、setScore | `GET /game/score`、`POST /game/score` | total 伺服器端算 |
| `/wheel/reward`、setInfo/getInfo/setQRCode/getQRCode | `GET /game/reward`、`PATCH /game/reward/contact`、`POST /game/reward/codes` | |
| `/wheel/record`、getQuestionSolved | `GET /game/record` | |
| `/admin/*` | `namespace :admin`：sessions#new/create/destroy、dashboard#show、serial_codes#index/create | 全部 `before_action :require_admin`；產生量參數化（預設 50）用 `insert_all`；QR 用 rqrcode |

- 玩家端 `Game::BaseController` 統一 `before_action :require_player_session`。
- **JSON 契約**：`app/javascript/lib/api.js` 統一 fetch wrapper —— 帶 `X-CSRF-Token`（讀 csrf meta）、`Accept: application/json`、`credentials: same-origin`；POST 參數放 body 不放 URL。

## 3. 前端與 assets

- **jQuery 全站保留，走 classic script（不走 importmap ESM**，minified plugin 非 ESM 且 Bootstrap 4 modal 硬依賴 jQuery）：jQuery 3.3.1 / jQuery UI 1.12.1 / Bootstrap 4.1.3 **沿用舊站的 CDN `<script>` 標籤**（`_layouts/header.php:11-26` 同款）；本地 vendor 只放兩個檔：`jquery.snap-puzzle.min.js`（從舊專案 contents/ 複製）與 **jQuery UI touch-punch shim**（從舊站 `wheel_puzzle.php:166` 的 inline shim 抽出成獨立檔，手機拖拉必需），用 `javascript_include_tag` 依序載入（jQuery→jQuery UI→touch-punch→snap-puzzle）。
- importmap **只**服務 Turbo/Stimulus 與自寫 controllers；modal 沿用 Bootstrap 4 JS 不用 Stimulus 重寫。
- 45 張圖 → `app/assets/images/`；CSS 轉 UTF-8 後搬入（含 CRLF→LF）；`@import url(//fonts.googleapis.com/...)` 保留 `url()` 形式。
- CSS 編譯器：維持 `sassc-rails`（已 EOL 一事在 README 選型理由中記錄，換裝列為未來項，避免本次 Gemfile 變動）。
- 移除 layout 的 Firebase CDN 標籤與 `window.history.forward(1)`（與 Turbo Drive 衝突；防返回需求以 Turbo 慣例或直接移除）。

## 4. 測試與品質

- Minitest：model 測試（驗證、容量、計分、配發原子性）＋ integration 測試（全流程：登入→組隊→選職→解題→Boss→結算→兌獎；admin 未登入被擋；答案錯誤不放行；show 頁 HTML 不含答案）。
- **System test**（CI 已有 `test:system` job）至少：拼圖頁可載入且 plugin 初始化、Boss 點擊累加、輪詢導頁、答案錯誤不過關。
- 每批驗收：`bin/rails test` 綠 ＋ `bin/rubocop` 綠 ＋ `bin/brakeman` 無新增警告（CI `.github/workflows/ci.yml` 已在跑這三項＋`importmap audit`）。
- P7 收尾 grep（關鍵字見 §0）＋ smoke test 走完全鏈 ＋ `assets:precompile` 後確認 45 張圖與 CSS 都在 manifest。

## 5. 實作分批

| 批次 | 內容 | 依賴 | 驗收重點 |
|---|---|---|---|
| **P0 前置修復** | 搬 45 張圖＋CSS 轉碼搬入＋vendor JS 四件套；layout 補 `javascript_importmap_tags`/`csrf_meta_tags`/`csp_meta_tag`、移除 Firebase 標籤與 `history.forward`；評估 dartsass 換裝；建 `lib/api.js`。**唯一有權改 `app/views/layouts/` 的批次** | — | `curl -f localhost:3000/` 回 200；precompile 過 |
| **P1 資料層** | migrations、9 models、關聯/驗證/scope、seeds（11 題示範＋**demo 序號 `DEMO...` 保留為展示資料但刻意 0 玩家（修復批次定案：首頁 Demo 改為每次 POST 建立全新單人隊，避免共用序號滿額死鎖）＋demo 難度（全部題目 boss_hp 10/時限 60）**＋序號池＋admin 帳號）、model 測試 | —（與 P0 平行，不動 assets/layouts/views） | `db:prepare`+model 測試綠 |
| **P2 入場流程** | game/sessions、teams、jobs ＋ views ＋ Stimulus 輪詢 ＋ integration | P0+P1 | 測試綠；Stimulus 有 connect（system test） |
| **P3 解題主線** | home/maps(:id)/questions/answer/question_attempts；三種題型 views（拼圖 plugin 接線） | P2 | 測試綠；show 不含答案 |
| **P4 Boss 與結算** | bosses(:number)/attacks/ready(join table)/scores/rewards/records＋ScoreCalculator＋職業效果 | P3 | 全流程 integration 綠 |
| **P5 後台** | Admin model、admin sessions、序號產生器（insert_all、參數化）、rqrcode、授權測試 | P1（欄位語意已定案）；可與 P2-P4 平行 | 未登入 302；產生器寫 DB |
| **P6 Demo 體驗** | 首頁 Demo 入口（帶 demo 序號）、Boss demo 難度接線、UI 標示「Demo 模式」 | P4 | 單人可走完全鏈 |
| **P7 收尾** | README（架構、ERD、setup、**「答案驗證移到伺服器端」主打**、素材授權註記、選型理由）、i18n、敏感字 grep、smoke test、`config.hosts`/部署整備（deploy 目標待使用者定） | 全部 | verifier 驗收 |

派工模型：各批 `general-purpose` + `sonnet`（連錯兩次升 opus）；最終 `verifier` 驗收。

## 8. ANALYSIS.md 勘誤（審查發現）

1. Wheel controller 是 **38 個 public action**（不是 31）。
2. 隊伍組成是 **1 隊長 + 最多 3 隊員**（不是「隊長/隊員各一」）。
3. 「打王」是**每題一隻 Boss（boss_no 與題號共用）**，非單一 Boss。
4. `SERIAL_TYPE`/`REWARD_TYPE` 是 test_mode 旗標（0/1），非類別欄位。
5. 附錄 A 的「AJAX 取得」中 teamNMGet/jobCheck/getBossHP 實為伺服器端 long-poll。
