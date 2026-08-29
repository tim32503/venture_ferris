# Schema 正規化重構方案

> 對象分支：`feat/ui-modernization`（HEAD = `1afb2b4`「摩天輪魔王雙型態與桌機首屏調整」）
>
> ⚠️ 本文件撰寫期間分支收到了 `1afb2b4` 這個 commit，它**推翻了我對候選項 3 的第一版判斷**。
> 修正過程保留在 §2-3，因為那個推翻本身就是這份方案最值得展示的部分。
> 現況入口：`db/schema.rb`（version `2026_08_29_173644`，9 張表）
> 前提：**未上線的作品集專案，DB 內沒有任何 production 資料**。因此本方案允許 breaking migration，
> 不做 zero-downtime 分階段切換；開發機的實際路徑是 `bin/rails db:reset && bin/rails db:seed`。
> 對外行為（HTTP 路由、JSON 欄位名、遊戲規則、計分結果、Demo 流程）維持不變，除 §2-D1 一項明確標示的例外。

## 0. 本次調查取得的關鍵事證

設計決策不從教科書推導，而是先把三個來源對齊：現行程式碼、`docs/REFACTOR_PLAN.md` §1 的當初決策、
以及 2026-08-29 尋回的 2018 年原始 SQL dump（`AP_WHEEL.sql`，Big5 編碼，phpMyAdmin 4.7.7）。
以下四項事證直接推翻了兩個「看起來該改」的候選項：

| # | 事證 | 取得方式 | 影響 |
|---|---|---|---|
| E1 | 舊 DB **沒有 boss 主檔**。`BOSS_LOG` 是純 per-team log，全部 594 筆的 `BOSS_HP` 都是 120（欄位預設值逐列複製）。 | `AP_WHEEL.sql` 的 `CREATE TABLE BOSS_LOG` | Boss 的靜態屬性從來沒有被建模過 —— 但這**不等於** Boss 沒有獨立身分，見 E7 |
| E7 | Q10 與 Q11 是**同一隻「摩天輪魔王」的兩個型態**，不是兩隻怪。`mon10.gif` 從來不存在；現行程式已把 boss #10 對應到 `mon11.gif` 並加上「第一型態」標籤。 | `app/helpers/game/bosses_helper.rb:16-31` 的考證註解、`:32-62` 的實作、`test/helpers/game/bosses_helper_test.rb` 5 個測試 | **Boss 與 Question 不是 1:1，是 1:N（10 隻 Boss 對 11 題）** → 候選項 3 從「不抽表」翻轉為「抽表」 |
| E2 | 2018 實際資料 **573 筆 player、573 個相異 email、356 個相異序號；沒有任何一個 email 出現在兩支隊伍上**，同隊同 email 佔兩個角色的情形也是 0 筆。 | 解析 `WHEEL_PLAYER_USER` 的 INSERT 區塊 | 「跨隊以 email 認人」在真實活動中觸發次數 = 0/573 → 候選項 5、6 改判 |
| E3 | `WHEEL_PLAYER_REWARD.USER_ID` 是 `varchar(50)` 的 email，不是序號 → 現行 `reward_codes.player_email` 確實忠實承襲舊語意，不是重構時的疏漏。 | `CREATE TABLE WHEEL_PLAYER_REWARD` | 候選項 5 的「刻意保留」說法成立 |
| E4 | `QUEST_MAIN` 只有 `QUESTION_HINT1`/`HINT2` 兩欄，NOT NULL，無提示的題目存空字串。 | `CREATE TABLE QUEST_MAIN` | 平鋪提示欄是承襲舊表；但候選項 4 的理由不靠「未來要第三個提示」（見 §2-4） |

另外兩項是讀現行程式碼發現、初步清單未列到的：

- **E5**：`app/controllers/game/jobs_controller.rb:52` 的「同隊職業不可重複」只有 Ruby 層的
  read-then-write 檢查，DB 沒有任何約束 —— 兩個隊友同時送出可以拿到同一個職業。
- **E6**：`db/seeds.rb:113` 的 `hints_enabled: attrs.fetch(:hints_enabled) { attrs[:hint1].present? }`
  ——這個布林欄位在全部 11 題上都恰好等於 `hint1.present?`（第 6 題的顯式 `false` 與導出值一致）。
  它是一個**已經被存起來的導出值**。

---

## 1. 目標 ERD（文字版）

`*` = 本次新增/變更的欄位或表。變更後為 9 張既有表 + `question_hints` + `bosses` = 11 張。

```
teams                                   questions
──────────────────────────              ──────────────────────────────────
 id            PK                        id              PK
 serial_no     UQ  (16 chars)            number          UQ  (1..11)
 test_mode     NOT NULL                  kind            NOT NULL  enum(puzzle/quiz/bear) + CHECK*
 name          NULL (命名前為空)          title           NOT NULL
   │                                     answer_digest   NOT NULL  (SHA256，永不明文)
   │                                     content, level, explanation
   │                                     auto_start      NOT NULL
   │                                     base_score      NOT NULL  CHECK > 0*
   │                                     puzzle_rows/cols NULL      CHECK 與 kind 綁定*
   │                                     boss_hp         NOT NULL  CHECK > 0    ← 每題一戰，刻意留在 questions
   │                                     boss_time_limit NOT NULL  CHECK > 0    ← 同上，見 §5-6
   │                                     boss_id*        FK → bosses  NOT NULL  ← 新增，Q10/Q11 共用同一列
   │                                     boss_phase*     NULL  (1/2；僅摩天輪魔王)
   │                                     ✗ hint1 / hint2 / hints_enabled  ← 刪除，見 §2-4
   │                                       │  1        │ N
   │                                       │           │ 1
   │                                       │        bosses*  (新表，10 列)
   │                                       │        ──────────────────────────
   │                                       │         id      PK
   │                                       │         sprite  NOT NULL (mon01..09, mon11)
   │                                       │         UQ [sprite]
   │  1                                    │  N
   │                                     question_hints*  (新表)
   │                                     ────────────────────────────
   │                                      id          PK
   │                                      question_id FK → questions  NOT NULL
   │                                      position    NOT NULL  (1,2,…)
   │                                      content     NOT NULL
   │                                      UQ [question_id, position]
   │
   ├──── N ─── players
   │            ────────────────────────────────────────
   │             id          PK
   │             team_id     FK → teams  NOT NULL
   │             role        NOT NULL  enum(leader/member) + CHECK*
   │             email       NOT NULL  (person 身分，刻意不外抽，見 §5-5)
   │             job         NULL      enum(uncle/senior/netizen/celebrity) + CHECK*
   │             name, gender, mobile   (聯絡資訊，per-membership，見 §5-5)
   │             UQ [team_id, role, email]                      ← 現況
   │             UQ [team_id, email]                    *（D1，需裁決）
   │             UQ [team_id] WHERE role = leader        *  ← MAX_LEADERS=1 落到 DB
   │             UQ [team_id, job] WHERE job IS NOT NULL *  ← 修 E5
   │               │ 1
   │               │ N
   │             boss_readies
   │             ──────────────────────────
   │              boss_battle_id FK NOT NULL
   │              player_id      FK NOT NULL
   │              UQ [boss_battle_id, player_id]
   │               │ N
   │               │ 1
   ├──── N ─── boss_battles
   │            ──────────────────────────────────────────────
   │             id             PK
   │             team_id        FK → teams      NOT NULL
   │             question_id*   FK → questions  NOT NULL   ← 取代 boss_no
   │             ✗ boss_no                                  ← 刪除
   │             started_at / ended_at  NULL = 進行中 / 未勝利
   │             attack_count   NOT NULL  CHECK >= 0*
   │             hp             NOT NULL  CHECK > 0*   ← 開戰時自 questions.boss_hp 快照，見 §5-2
   │             last_critical_at  NULL
   │             UQ [team_id, question_id]*
   │
   ├──── N ─── question_attempts
   │            ──────────────────────────────────────
   │             team_id      FK → teams      NOT NULL
   │             question_id  FK → questions  NOT NULL
   │             started_at / ended_at  NULL = 進行中
   │             hint_count   NOT NULL  CHECK >= 0*
   │             UQ [team_id, question_id]
   │
   └──── N ─── score_entries
                ──────────────────────────────────────────────
                 team_id       FK → teams      NOT NULL
                 question_id*  FK → questions  NOT NULL   ← 取代 question_number
                 ✗ question_number                         ← 刪除
                 question_score / time_score / hint_score
                 boss_score / job_score / total_score   NOT NULL  CHECK total >= 0*
                 UQ [team_id, question_id]*

reward_codes                            admins
──────────────────────────────           ──────────────────────
 id           PK                          id              PK
 code         UQ NOT NULL                 email           UQ NOT NULL
 test_mode    NOT NULL                    password_digest NOT NULL
 player_email NULL  ← 刻意的字串 key，非 FK，見 §5-1
 claimed_at   NULL
 CHECK (player_email IS NULL) = (claimed_at IS NULL)*
 index [player_email]
```

### 關聯線總結

- `teams 1─N players / question_attempts / boss_battles / score_entries`
- `questions 1─N question_hints / question_attempts / boss_battles / score_entries`
- `bosses 1─N questions`（10 隻對 11 題；只有摩天輪魔王一隻跨兩題，`boss_phase` 區分型態）
- `boss_battles 1─N boss_readies N─1 players`
- `reward_codes` **刻意游離**，以 `player_email` 字串對應到人，不對應到 `players.id`

---

## 2. 逐項決策表

分類：**[N] = 正規化必要**（現行 schema 有真實的參照完整性或重複儲存缺陷）／
**[I] = 順手改善**（不改也不違反正規化，但便宜且有具體收益）。

| # | 項目 | 判定 | 分類 | 風險 |
|---|---|---|---|---|
| 1 | `boss_battles.boss_no` → `question_id` FK | **改** | N | 中 |
| 2 | `score_entries.question_number` → `question_id` FK | **改** | N | 中 |
| 3 | 抽出 `bosses` 表 | **改**（第一版判斷為「不改」，被 `1afb2b4` 推翻） | N | 中 |
| 4 | `hint1`/`hint2` → `question_hints` 子表（並刪 `hints_enabled`） | **改** | N | 中 |
| 5 | `reward_codes.player_email` → FK | **不改**（保留＋文件化＋加 CHECK） | — | 低 |
| 6 | 抽出 `participants` 拆分 person / membership | **不改** | — | — |
| 7a | enum 欄位加 DB CHECK 約束 | **改** | I | 低 |
| 7b | `[team_id, job]` partial unique index | **改** | N | 中低 |
| 7c | `[team_id] WHERE role = leader` partial unique index | **改** | I | 低 |
| 7d | `players` 唯一鍵 `[team_id, role, email]` → `[team_id, email]` | **待裁決** | I | 中 |
| 7e | `reward_codes` 的 `player_email`/`claimed_at` 同生共死 CHECK | **改** | I | 低 |
| 7f | 數值欄位 CHECK（`total_score >= 0`、`hp > 0`、`attack_count >= 0`、`base_score > 0`、`hint_count >= 0`） | **改** | I | 低 |
| 7g | `puzzle_rows`/`puzzle_cols` 與 `kind = puzzle` 綁定的 CHECK | **改** | I | 低 |
| 7h | counter cache（`players_count`、`boss_readies_count`） | **不加** | — | — |
| 7i | `boss_battles.last_critical_at` 欄位位置 | **不改**（但有一個程式面 bug，見下） | — | — |

---

### 1. `boss_battles.boss_no` → `question_id` FK ── **改** [N] 風險：中

**理由（可以說出口的版本）**：`boss_no` 是一個貨真價實的外鍵，只是沒有宣告成外鍵。
證據不在文件裡，在程式碼裡 —— `app/models/score_entry.rb:30` 做的是一次應用層 join：

```ruby
battle = team.boss_battles.find_by(boss_no: question.number)
```

而 `app/controllers/game/bosses_controller.rb:103-104` 先撈出 `@question`，卻只把 `@question.number`
存進去、再把 `@question.boss_hp` 抄進去 —— 手上已經有 `Question` 物件了，存的卻是它的業務編號。
DB 層沒有任何東西能阻止 `BossBattle.create!(team:, boss_no: 99)`；而
`test/models/boss_battle_test.rb:9,14,19,24,30` **正是這樣做的**（`boss_no: 1` 但資料庫裡沒有第 1 題）——
測試本身就是這個參照漏洞真實存在的證明。

**不改的反方論點與回應**：可以主張「boss 編號是遊戲用語，不是題目 id」。但 `app/models/boss_battle.rb:1-2`
的註解自己就寫著 `boss_no` shares numbering with `Question#number`，而 §0-E1 顯示舊 DB 根本沒有
boss 主檔 —— 這個編號從來就只是題號的別名，沒有獨立語意。

**對外行為**：不變。`app/controllers/game/questions_controller.rb:105` 的 JSON key
`active_boss_number` 保留，取值改為 `active_boss&.question&.number`。

---

### 2. `score_entries.question_number` → `question_id` FK ── **改** [N] 風險：中

**理由**：與 #1 同型，但更嚴重 —— `ScoreEntry` 連 `belongs_to :question` 都沒有
（`app/models/score_entry.rb:6` 只有 `belongs_to :team`）。整張結算表對題目的唯一連結是一個裸整數。
`app/models/score_entry.rb:1-2` 的註解把理由寫成「matching the legacy QUEST_SCORE table」——
對齊舊表結構本身不是保留缺陷的理由，尤其在同一個 schema 裡 `question_attempts` 已經用了正規的
`question_id` FK（`db/schema.rb:65`）。**同一份 schema 對同一個概念用了兩種寫法，這是最該修的不一致。**

**不改的反方論點與回應**：可以主張「結算帳本應該在題目被刪除後仍然存在」。回應有三：
(a) 題目是 11 筆靜態 seed 資料，沒有任何介面能刪除它；
(b) `app/models/question.rb:14` 已經是 `has_many :question_attempts, dependent: :destroy`——
    刪題目本來就會連帶毀掉歷史，帳本的獨立性現在也不成立；
(c) Rails `add_foreign_key` 預設是 RESTRICT，加了 FK 之後刪題目會**失敗**而不是留下孤兒列 ——
    帳本論點其實是支持加 FK 的。

---

### 3. 抽出 `bosses` 表 ── **改** [N] 風險：中

**這一項我改過答案，過程本身就是理由，所以完整保留。**

**第一版判斷（不抽表）**：`questions.boss_hp`/`boss_time_limit` 對 `questions.id` 完全函數相依，
沒有違反任何正規化形式；每題恰有一隻 Boss，是強制 1:1。§0-E1 又顯示舊系統從來沒有 boss 主檔。
一張 11 列、主鍵與 `questions` 一對一、沒有獨立身分的表，換一次熱路徑 join（Boss 頁 300-500ms 輪詢）
不划算 —— 所以判定不抽，只把藏在 `format()` 裡的素材檔名變成 `questions.boss_sprite` 欄位。

**推翻它的事實（§0-E7）**：撰寫期間分支收到 `1afb2b4`。該 commit 的考證註解
（`app/helpers/game/bosses_helper.rb:16-31`）指出 **Q10 與 Q11 是同一隻「摩天輪魔王」的兩個型態** ——
Q10 的題目文字是「前往魔王佔據的摩天輪」，Q11 是 `auto_start`（沒有獨立的 ready lobby），
而 `mon10.gif` 從來就不存在。程式已據此讓 boss #10 借用 `mon11.gif` 並加上「第一型態」標籤。

**這推翻了第一版判斷的前提**：Boss 與 Question **不是 1:1，是 1:N**（10 隻 Boss 對 11 題）。
一個橫跨兩題的實體，定義上就有獨立於任何單一題目的身分。「沒有獨立身分所以不值得抽表」的論證失效。

**現況的代價**：這個 1:N 關係目前用三個 helper method 加兩個魔術常數表達
（`app/helpers/game/bosses_helper.rb:32-62`）：

```ruby
WHEEL_BOSS_FIRST_PHASE_NUMBER = 10
WHEEL_BOSS_FINAL_PHASE_NUMBER = 11

def boss_sprite_source_number(number)
  number == WHEEL_BOSS_FIRST_PHASE_NUMBER ? WHEEL_BOSS_FINAL_PHASE_NUMBER : number
end
```

`boss_sprite_source_number`、`boss_sprite_css_classes`、`boss_phase_label` 三個 method
各自重述一次「10 其實是 11」，外加 `test/helpers/game/bosses_helper_test.rb` 5 個測試
把這個對應釘死。**一個關於資料的事實，被寫成了三段程式邏輯。**

**決策**：抽出 `bosses(id, sprite UQ)`（10 列），`questions.boss_id` FK NOT NULL，
`questions.boss_phase`（integer, NULL；僅摩天輪魔王的兩題填 1/2）。
Q10 與 Q11 指向同一個 `boss_id`，「共用同一隻怪」從三段 Ruby 判斷變成一個外鍵值。

**刻意不放進 `bosses` 的東西**：
- `boss_hp`/`boss_time_limit` **留在 `questions`** —— 它們是「這一戰」的參數而非「這隻怪」的屬性，
  Q10 與 Q11 的難度本來就可以不同（`base_score` 已經是 1000 vs 3000）。放進 `bosses` 會強迫兩題同難度，
  那是行為變更。
- `name` **不加** —— §0-E1 確認舊 dump 沒有 boss 名稱，加了就是憑空發明；而且 view 現在顯示的是
  `魔王戰：<%= @question.title %>`（`app/views/game/bosses/show.html.erb:1,14`），
  加一個 `name` 欄位只會誘發不必要的行為變更。列為未來選項。

**收益**：`boss_image_filename`/`boss_sprite_source_number` 消失（改讀 `question.boss.sprite`）；
`boss_asset_available?`（`app/helpers/game/bosses_helper.rb:64-72`，翻 Sprockets manifest
再 `rescue StandardError` 吞例外）連同 `app/views/game/bosses/show.html.erb:51-55` 的 fallback 分支
可以簡化為「`sprite` 是 NOT NULL，所以一定有值」——素材缺口在 seeds 階段就會炸，不會拖到執行期。
`boss_phase_label` 改由 `boss_phase` 驅動。

**可以說出口的一句話**：「我原本判斷不該抽 —— 一個 1:1、沒有獨立身分的表不值得換一次 join。
後來發現 Q10 和 Q11 打的是同一隻怪，1:1 的前提根本不成立，所以我改了答案。」

**風險提醒**：`test/helpers/game/bosses_helper_test.rb` 的 5 個測試是針對 helper 純函數寫的，
抽表後這些邏輯移到 model/關聯，測試需改寫為 model 測試。**斷言的期望值不變**
（boss 10 仍解析到 mon11、仍是「第一型態」），只是取得方式從呼叫 helper 變成讀關聯。

---

### 4. `hint1`/`hint2` → `question_hints` 子表，並刪除 `hints_enabled` ── **改** [N] 風險：中

**理由一（重複群組）**：`hint1`/`hint2` 是典型的 repeating group。可見的代價是
`app/views/game/questions/_hint_panel.html.erb:10-15` 那段手動展開的階梯：

```erb
<% if attempt.hint_count >= 1 %><p>(1) <%= question.hint1 %></p><% end %>
<% if attempt.hint_count >= 2 %><p>(2) <%= question.hint2 %></p><% end %>
```

以及 `app/controllers/game/questions_controller.rb:16` 的 `HINT_LIMIT = 2` —— 一個被硬編碼成
「等於欄位數量」的常數，而且它還被 view 反向引用（`_hint_panel.html.erb:8,17`）。

**理由二（存起來的導出值，這才是決定性的）**：見 §0-E6。`hints_enabled` 在全部 11 題上都恰好等於
`hint1.present?`，`db/seeds.rb:113` 本身就是這樣算出來的。這是 3NF 意義下的冗餘 —— 一個非鍵欄位
完全由另一個非鍵欄位決定。移到子表後它直接變成 `question.hints.any?`。

**理由三（順帶修掉一個舊站 bug 的殘影）**：`db/seeds.rb:109-112` 的註解記載，舊站對 1/2/8/9 題
「提示是空字串但按鈕仍可按、還會扣分」。現行 schema 靠 seeds 的導出邏輯繞過，子表化之後
「沒有提示列 = 不可能按提示」變成結構上就不可能，不再依賴 seeds 算對。

**注意（行為保存的關鍵細節）**：`app/controllers/game/questions_controller.rb:70-81` 的兩個分支順序不能動。
改寫後必須是：

```ruby
return head :forbidden if @question.hints.none?          # 原 hints_enabled? 分支，回 403
...
if attempt.hint_count >= @question.hints.size            # 原 HINT_LIMIT 分支，回 redirect + alert
```

若直接把 `HINT_LIMIT` 換成 `hints.size` 而拿掉前一個 guard，第 6 題會從 **403** 變成
**302 + 「已達提示使用上限」** —— 這是一個會被 integration 測試抓到的對外行為變更。

**放棄的表達力（誠實揭露）**：改完之後，「有提示文字但關閉提示」這個狀態不再可表達。
`db/seeds.rb` 的 11 題沒有用到這個組合（見 §0-E6），但**測試用到了**：
`test/integration/game/question_flow_test.rb:170` 的 `seed_question(6, hints_enabled: false)`
搭配同檔第 26-27 行 helper 塞入的非空 `hint1`/`hint2`，正是「有提示文字但關閉」的組合 ——
它把 `hints_enabled` 當成建構測試情境的捷徑在用。

改寫方式：該處改為建立一個**沒有 hint 子列**的第 6 題，第 174 行（按鈕不出現）與
第 177 行（`assert_response :forbidden`）的斷言值都不需要動 —— 新的 `hints.none?` guard
會走到同一個 403。**這是「設定方式改變、期望值不變」的典型案例，也是這個判定安全的證據。**

若 reviewer 認為未來確實需要營運層面的 override，則保留 `hints_enabled` 欄位，
但要接受它是一個導出值的顯式覆寫 —— 那時它的預設值應改為 `NULL`（= 跟隨導出值），
而不是現在的 `NOT NULL DEFAULT true`。

---

### 5. `reward_codes.player_email` → `player_id` FK ── **不改**，保留＋文件化＋加 CHECK 風險：低

**判定理由（用資料而不是用直覺）**：

先確認語意確實是活的。序號重入隊有兩條路徑，只有一條會製造新的 `Player` 列：

- `app/controllers/game/sessions_controller.rb:91-92`（`updateSNo` / PATCH）：同一個 `Player`
  列被改綁到新 team，`player_id` **不變** —— 這條路徑用 `player_id` FK 也不會壞。
- `app/controllers/game/sessions_controller.rb:57`（POST 重新登入）：
  `team.players.find_by(role:, email:)` 在新隊上找不到 → **建立一列新的 `Player`**，
  `player_id` 改變 —— 這條路徑改成 `player_id` FK 就會讓同一個人再抽走一組序號。

所以 email key 在程式碼層面確實是 load-bearing，**選項二（改 FK＋放棄跨隊語意）應否決**。

再看選項三（引入 `participants` 以 email 為自然鍵，兩者兼得）。這在紙上是最漂亮的答案，
但 §0-E2 的資料把它否決了：**2018 年真實活動 573 筆玩家、573 個相異 email、356 支隊伍，
沒有任何一個 email 出現在兩支隊伍上。** 這個「跨隊認人」語意在唯一存在過的真實資料集裡
觸發次數是 0/573。為一個觀測頻率為零的情境新增一張表、改動 `players` 的主要識別方式、
並牽動 login/reward/job/admin 四條流程，這正是使用者要避免的過度工程。

**選項一（保留＋文件化）勝出。** 這也是唯一能寫進 README 當賣點的版本：
「我查了原始 dump，確認這個非正規設計承襲自 `WHEEL_PLAYER_REWARD.USER_ID`（§0-E3），
並確認它保護的情境在真實資料裡從未發生 —— 所以我保留語意、寫下理由，而不是為它蓋一張表。」

**唯一要補的整合性缺口**：`player_email` 與 `claimed_at` 在
`app/models/reward_code.rb:37` 是一起寫入的，但 DB 允許只設其一。補一條 CHECK 讓兩者同生共死
（見 §2-7e），這不改變任何語意。

---

### 6. 拆分 person / membership（`participants` 表） ── **不改** 風險：—

**理由**：與 #5 同一份證據，而且是同一個改動 —— 這兩個候選項其實是一個問題。

我原本準備的支持論點是：`players` 同時存 person 屬性（`email`）與 membership 屬性
（`team_id`/`role`/`job`）與聯絡資訊（`name`/`mobile`/`gender`），所以同一個人在兩支隊伍上
會有兩份聯絡資訊，而 `app/controllers/game/rewards_controller.rb:19` 只更新當前那一列 ——
獎品寄給「人」，但地址電話存在「隊籍」上，這是典型的更新異常。

**但這個異常在真實資料裡不存在**（§0-E2：0 個 email 跨隊）。而且 §0 顯示這個結構是從
`WHEEL_PLAYER_USER`（`SERIAL_NO` + `CHAR_TYPE` + `USER_ID` 複合鍵，name/gender/mobile 掛在同一列）
一比一承襲的。這是一個活動小遊戲，`players` 表的生命週期就是一場活動；把 person 抽出來
是 CRM 的建模，不是這個領域的建模。

**保留但要文件化**：`players.name`/`mobile`/`gender` 是 per-membership 而非 per-person，
這一點必須寫進 schema 註解，否則下一個讀者會以為是疏漏。

**唯一從這裡撿到的真缺陷**見 §2-7d：現行唯一鍵 `[team_id, role, email]`
（`db/schema.rb:59`）允許同一個 email 在同一隊裡同時當隊長和隊員。
`test/models/player_test.rb:59-65` 甚至把這個索引寫成了測試，等於把缺陷文件化成了規格。

---

### 7a. enum 欄位加 DB CHECK 約束 ── **改** [I] 風險：低

`players.role`/`job`/`gender`、`questions.kind` 都是整數 enum，Rails 端有 `validate: true`
（`app/models/player.rb:10-13`、`app/models/question.rb:16`），DB 端完全沒有約束 ——
一次 `update_all` 或 `insert_all` 就能寫進 `role = 7`。
`app/controllers/admin/serial_codes_controller.rb:46` 已經在用 `insert_all!`，
這條路徑繞過所有 model 驗證，所以這不是純理論風險。

### 7b. `[team_id, job] WHERE job IS NOT NULL` partial unique index ── **改** [N] 風險：中低

§0-E5：`app/controllers/game/jobs_controller.rb:52` 是 read-then-write：

```ruby
current_team.players.where(job: job).where.not(id: current_player.id).exists?
```

兩個隊友同時送出可以拿到同一個職業，而職業直接影響計分
（`app/models/score_calculator.rb:75,79` 用 `team.players.senior.any?` / `celebrity.any?`）
與 Boss 時限（`app/helpers/game/bosses_helper.rb:13`）。這是一個會影響遊戲結果的競態。
Partial unique index 是唯一能真正關掉它的方法。

**實作注意**：加上索引後 `app/controllers/game/jobs_controller.rb:29` 的 `update` 必須
`rescue ActiveRecord::RecordNotUnique`，導向與現行 race-loser 相同的
「這個職業已經被隊友選走了」alert（第 26 行），對外行為才不變。

### 7c. `[team_id] WHERE role = leader` partial unique index ── **改** [I] 風險：低

`Player::MAX_LEADERS = 1`（`app/models/player.rb:4`）目前只在
`app/models/player.rb:21-33` 的 `team_capacity` 驗證裡，同樣是 read-then-write。
「每隊恰一位隊長」可以用 partial unique index 完整表達，值得放進 DB。

**必須誠實標註的不對稱**：`MAX_MEMBERS = 3` **無法**用索引表達（那是計數上限，不是唯一性），
只能留在應用層或改用 trigger。本方案不引入 trigger —— 為了對稱而加 trigger 是為形式犧牲可維護性。
這個不對稱要寫進 schema 註解。

### 7d. `players` 唯一鍵 `[team_id, role, email]` → `[team_id, email]` ── **待裁決** [I] 風險：中

現行索引允許 `a@b.com` 在同一隊裡同時是 leader 和 member，佔掉兩個名額。
真實資料 0 筆（§0-E2），legacy 也是 0 筆，明顯不是有意設計。

**但這是本方案唯一會改變對外行為的項目**，所以標為待裁決：收緊之後，
「用已註冊為隊長的 email 再以隊員身分登入」會從「成功建立第二列」變成失敗。
`app/controllers/game/sessions_controller.rb:68-76` 的 `save` 失敗分支目前一律回
`capacity_error_for(role)`（01004/01005），語意上是錯的 —— 那不是名額滿，是身分重複。

三個選項：
1. 收緊索引，失敗導向既有的 `ERROR_INVALID_SERIAL`（01002「序號/角色不合法」）—— 不新增對外錯誤碼。
2. 收緊索引，新增錯誤碼 01006 —— 語意最清楚，但擴充了對外介面。
3. 不動，在 schema 註解寫明這是已知且刻意容忍的鬆散約束。

我的建議是 **選項 1**，並同時修正 `test/models/player_test.rb:59-65`（該測試目前把缺陷寫成了規格）。
但因為它動到對外行為，交由使用者/reviewer 拍板。

### 7e / 7f / 7g. 其餘 CHECK 約束 ── **改** [I] 風險：低

- `reward_codes`：`CHECK ((player_email IS NULL) = (claimed_at IS NULL))`
  —— 兩者在 `app/models/reward_code.rb:37` 一起寫入，DB 應該表達這件事。
- 數值下界：`score_entries.total_score >= 0`（現僅 `app/models/score_entry.rb:9`）、
  `boss_battles.hp > 0` 與 `attack_count >= 0`（現僅 `app/models/boss_battle.rb:20-21`）、
  `questions.base_score > 0` / `boss_hp > 0` / `boss_time_limit > 0`（現僅 `app/models/question.rb:23-25`）、
  `question_attempts.hint_count >= 0`（現僅 `app/models/question_attempt.rb:9`）。
  這些不變量目前全部只活在 Ruby 裡。
- `questions`：`CHECK ((kind = 0) = (puzzle_rows IS NOT NULL AND puzzle_cols IS NOT NULL))`
  —— `puzzle_rows`/`puzzle_cols` 只對 `kind = puzzle` 有意義（11 題中的 2 題）。
  **不為此抽子型別表**：兩個可空整數換一張表加一次 join 不划算，一條 CHECK 拿到九成的完整性。

### 7h. counter cache ── **不加** 風險：—

候選點：`app/models/boss_battle.rb:38` 的 `boss_readies.count`、
`app/controllers/game/bosses_controller.rb:90,124` 與 `app/controllers/game/teams_controller.rb:45`
的 `current_team.players.count`。這些確實跑在 300-500ms 的輪詢路徑上。

**仍然不加**，理由：每隊最多 4 人、每場戰鬥最多 4 筆 ready，兩個 count 都走既有索引
（`index_boss_readies_on_boss_battle_id`、`index_players_on_team_id`），是索引上的極小範圍掃描。
counter cache 換來的效能是量不出來的，卻引入一個 desync 面向——而且恰好落在最不能出錯的地方：
`app/controllers/game/bosses_controller.rb:117` 的逾時重置會 `boss_readies.destroy_all`，
一旦未來有人為了效能把它換成 `delete_all`，快取數字就永久錯位，而錯位的後果是
`start_if_all_ready!`（第 121-128 行）判斷失準 —— 隊伍卡在 lobby 進不去。
**用一個量不出來的收益換一個會卡死流程的失效模式，不划算。**

### 7i. `boss_battles.last_critical_at` ── schema 不改，但發現一個程式面 bug 風險：—

欄位位置正確（爆擊節流是 per-battle 狀態，nullable = 從未爆擊過），不需搬移。

**但**：`app/controllers/game/bosses_controller.rb:116` 的逾時重置
`@battle.update!(started_at: nil, attack_count: 0)` **沒有清掉 `last_critical_at`**。
逾時重戰後，若玩家在 `CRITICAL_THROTTLE_SECONDS`（2 秒，`app/models/boss_battle.rb:17`）
內打出第一次爆擊，會被上一場戰鬥的殘留時戳吞掉。
這是程式 bug 不是 schema 問題，順手在同一個 PR 修掉即可（`last_critical_at: nil`）。

---

## 3. Migration 執行順序

五個新 migration，**不修改既有的 `20260819*` migration** —— 保留第一版設計的痕跡，
讓 `db/migrate/` 本身成為「我做了一次刻意的第二輪設計」的證據，這對作品集是加分而非噪音。

由於沒有 production 資料，backfill 段落只服務開發機；實務路徑仍是 `db:reset && db:seed`。
backfill 一律用 raw SQL，不引用 model class（避免未來 model 改名讓舊 migration 失效）。

| 順序 | Migration | 內容 | 依賴 |
|---|---|---|---|
| M1 | `CreateQuestionHints` | 建 `question_hints(question_id FK NOT NULL, position NOT NULL, content NOT NULL)`；unique index `[question_id, position]`；backfill 自 `questions.hint1`/`hint2`（跳過 NULL/空字串）；`remove_column :questions, :hint1, :hint2, :hints_enabled` | 無 |
| M2 | `CreateBosses` | 建 `bosses(sprite NOT NULL, UQ [sprite])`；插入 10 列（`mon01..mon09`, `mon11`）；`add_reference :questions, :boss, foreign_key: true`（先 nullable）＋ `add_column :questions, :boss_phase, :integer`；backfill：第 N 題（N≤9）→ `mon0N`，**第 10、11 題同指 `mon11` 那一列**，`boss_phase` 分別填 1、2；`change_column_null :questions, :boss_id, false` | 無 |
| M3 | `AddQuestionRefToBossBattles` | `add_reference :boss_battles, :question, foreign_key: true`（先 nullable）；backfill `UPDATE boss_battles SET question_id = (SELECT id FROM questions WHERE questions.number = boss_battles.boss_no)`；`change_column_null` → NOT NULL；`remove_index [team_id, boss_no]`；`add_index [team_id, question_id] unique`；`remove_column :boss_no` | 無 |
| M4 | `AddQuestionRefToScoreEntries` | 同 M3 的形狀，對 `score_entries.question_number` | 無 |
| M5 | `AddSchemaConstraints` | 7a/7b/7c/7e/7f/7g 的全部 CHECK 與 partial unique index（若 7d 獲准，一併在此收緊 `players` 唯一鍵） | M1-M4（`questions` 欄位已定案） |

**M3/M4 的 backfill 前置檢查**：若開發機既有資料含孤兒列（`boss_no` 或 `question_number`
對不到任何 `questions.number`），`change_column_null` 會失敗。migration 應先
`DELETE FROM boss_battles WHERE question_id IS NULL`（開發資料可棄）或直接 `db:reset`。

**替代方案（若使用者偏好乾淨的 `schema.rb` 歷史）**：把 M1-M5 的結果直接壓回
`20260819*` 那批 migration，然後 `db:drop db:setup`。代價是失去上述的設計痕跡。
本方案**不建議**，但保留為選項。

### seeds 連動（`db/seeds.rb`）

- `db/seeds.rb:36-37,43-44,49-50,61-62,78-79,84-85`：`hint1:`/`hint2:` 改為 `hints: [...]` 陣列。
- `db/seeds.rb:106-107,113`：移除 `hint1:`/`hint2:`/`hints_enabled:` 賦值；改為建立 `question_hints` 子列。
  `hints_enabled` 的導出邏輯（第 113 行）整段刪除 —— 它的職責已由「有沒有 hint 列」承擔。
- 新增 `boss:`／`boss_phase:` 賦值：第 1-9 題各自對應 `mon0N` 的 boss 列；
  **第 10、11 題指向同一個 `mon11` boss 列**，`boss_phase` 各為 1、2。
  `bosses` 的 10 列本身也在 seeds 建立（`find_or_create_by!(sprite:)`）。
- `db/seeds.rb:5-13` 的檔頭註解需補上：第 6 題原本的顯式 `hints_enabled: false` 為何可以拿掉
  （因為它本來就沒有提示文字，導出值一致）。

---

## 4. 受影響程式碼盤點

行號以 HEAD `1afb2b4` 為準（已逐一核對）。

### 項目 1（`boss_no` → `question_id`）

| 檔案:行號 | 需要的改動 |
|---|---|
| `app/models/boss_battle.rb:1-3` | 註解：`boss_no` shares numbering → 改述為 `belongs_to :question` |
| `app/models/boss_battle.rb:19` | `validates :boss_no, ...` → `belongs_to :question` + `validates :question_id, uniqueness: { scope: :team_id }` |
| `app/models/score_entry.rb:30` | `find_by(boss_no: question.number)` → `find_by(question: question)` |
| `app/models/team.rb:51-53` | `active_boss_battle` 加 `.includes(:question)`（供 questions#status 取 number） |
| `app/models/question.rb` | 新增 `has_many :boss_battles` |
| `app/controllers/game/bosses_controller.rb:103` | `find_or_create_by!(boss_no: @question.number)` → `find_or_create_by!(question: @question)` |
| `app/controllers/game/questions_controller.rb:105` | `active_boss&.boss_no` → `active_boss&.question&.number`（**JSON key 不變**） |
| `test/models/boss_battle_test.rb:9,14,19,24,28-35,37,42,47,53` | 9 個測試全部需先建立 `Question` 再建 battle |
| `test/models/boss_ready_test.rb:10,22-23` | 同上 |
| `test/integration/game/boss_flow_test.rb:84,107,123,140,167,179,189` | `find_by!(boss_no: N)` → `find_by!(question: question)` |
| `test/integration/game/settlement_flow_test.rb:58` | 同上 |
| `test/integration/game/demo_flow_test.rb:86` | 同上 |

### 項目 2（`question_number` → `question_id`）

| 檔案:行號 | 需要的改動 |
|---|---|
| `app/models/score_entry.rb:1-2` | 註解：移除「matching the legacy QUEST_SCORE table」的理由 |
| `app/models/score_entry.rb:6` | 新增 `belongs_to :question` |
| `app/models/score_entry.rb:8` | `validates :question_number` → `validates :question_id, uniqueness: { scope: :team_id }` |
| `app/models/score_entry.rb:24` | `pluck(:question_number)` → `pluck(:question_id)`；第 28 行比對隨之改 |
| `app/models/score_entry.rb:34` | `create!(question_number: question.number, ...)` → `create!(question: question, ...)` |
| `app/controllers/game/scores_controller.rb:12` | `order(:question_number)` → `joins(:question).order("questions.number")` |
| `app/views/game/scores/show.html.erb:36` | `entry.question_number` → `entry.question.number`（**顯示值不變**；controller 需 `includes(:question)`） |
| `test/models/score_entry_test.rb:9,14,21,23` | 3 個測試需先建立 `Question` |
| `test/integration/game/settlement_flow_test.rb:62,115` | `find_by!(question_number: N)` → `find_by!(question: question)` |

### 項目 3（`bosses` 表）

| 檔案:行號 | 需要的改動 |
|---|---|
| `app/models/question.rb` | 新增 `belongs_to :boss`；`boss_phase` 相關的 `first_phase?`/`final_phase?` 述詞 |
| `app/models/boss.rb` | **新檔**：`has_many :questions`，`validates :sprite, presence: true, uniqueness: true` |
| `app/helpers/game/bosses_helper.rb:32-37` | `WHEEL_BOSS_*` 兩個常數與 `boss_sprite_source_number` 刪除 |
| `app/helpers/game/bosses_helper.rb:39-41` | `boss_image_filename` 刪除（改讀 `question.boss.sprite`） |
| `app/helpers/game/bosses_helper.rb:43-52` | `boss_sprite_css_classes` 改由 `question.boss.sprite` + `boss_phase` 推導，不再吃 `number` |
| `app/helpers/game/bosses_helper.rb:54-62` | `boss_phase_label` 改由 `question.boss_phase` 驅動（case 1/2），不再比對題號 |
| `app/helpers/game/bosses_helper.rb:64-72` | `boss_asset_available?` 可刪除（`sprite` NOT NULL，缺素材在 seeds 就會炸）；若要保留防禦則改吃 `sprite` |
| `app/views/game/bosses/show.html.erb:15` | `boss_phase_label(@question.number)` → `boss_phase_label(@question)` |
| `app/views/game/bosses/show.html.erb:45,47` | `boss_image_filename`/`boss_sprite_css_classes` 的引數由 number 改為 question |
| `app/views/game/bosses/show.html.erb:51-55` | fallback 分支簡化或移除 |
| `db/seeds.rb`（第 96-122 區塊） | 見 §3 seeds 連動 |
| `test/helpers/game/bosses_helper_test.rb:13-40` | 5 個測試改寫為 model/關聯測試（**期望值不變**：boss 10 → mon11、「第一型態」） |
| `test/system/game_boss_page_test.rb:14,42,78` | 三處 `Question.create!` 需補 `boss:` 關聯 |

### 項目 4（`question_hints`）

| 檔案:行號 | 需要的改動 |
|---|---|
| `app/models/question.rb:14` | 新增 `has_many :question_hints, -> { order(:position) }, dependent: :destroy` |
| `app/controllers/game/questions_controller.rb:14-16` | `HINT_LIMIT` 常數移除；view 的兩處引用改為 `question.hints.size` |
| `app/controllers/game/questions_controller.rb:71` | `unless @question.hints_enabled?` → `if @question.question_hints.none?`（**保持 403 分支在前**，見 §2-4） |
| `app/controllers/game/questions_controller.rb:75` | `>= HINT_LIMIT` → `>= @question.question_hints.size` |
| `app/views/game/questions/_hint_panel.html.erb:6` | `question.hints_enabled?` → `question.question_hints.any?` |
| `app/views/game/questions/_hint_panel.html.erb:8,17` | `Game::QuestionsController::HINT_LIMIT` → `question.question_hints.size` |
| `app/views/game/questions/_hint_panel.html.erb:10-15` | 展開的階梯 → `question.question_hints.first(attempt.hint_count).each` 迴圈 |
| `db/seeds.rb:36-37,43-44,49-50,61-62,78-79,84-85,106-107,113` | 見 §3 seeds 連動 |
| `test/integration/game/question_flow_test.rb:26-27` | `seed_question` helper 的 `hint1:`/`hint2:` → 建立 `question_hints` |
| `test/integration/game/question_flow_test.rb:170` | `seed_question(6, hints_enabled: false)` → 改為建立無 hint 子列的第 6 題。**第 174、177 行的斷言不變**（403 由新的 `hints.none?` guard 提供） |
| `test/integration/game/question_flow_test.rb:183-195` | 「提示到上限後停止」測試：上限來源從 `HINT_LIMIT` 常數變成該題的 hint 列數（helper 給 2 列 → 期望值仍是 2），斷言不變 |

### 項目 7（約束）

| 檔案:行號 | 需要的改動 |
|---|---|
| `app/controllers/game/jobs_controller.rb:29` | `update` 加 `rescue ActiveRecord::RecordNotUnique` → 導向第 26 行相同的 alert（7b） |
| `app/controllers/game/bosses_controller.rb:116` | 順手修 `last_critical_at` 未清除的 bug（7i） |
| `app/controllers/admin/serial_codes_controller.rb:46` | 無需改動，但 `insert_all!` 正是 7a CHECK 要防的路徑 |
| `test/models/player_test.rb:59-65` | 若 7d 獲准，此測試需重寫（目前把缺陷寫成了規格） |

### 測試影響面總計

現況（HEAD `1afb2b4`）：**123 個非 system 測試**（integration 58 + models 53 + controllers 7 +
helpers 5）＋ **9 個 system 測試**。以 `grep -c 'test "'` 逐目錄核對（未實跑，需 DB）。

> 派工單提到的「118 integration」對應的是 `1afb2b4` 之前的狀態（58+53+7）；
> `1afb2b4` 新增了 `test/helpers/game/bosses_helper_test.rb` 的 5 個測試，所以現在是 123。
> `test/mailers`、`test/channels` 皆無實際測試（`channels` 內唯一的 `test "..."` 是被註解掉的）。

| 項目 | 需改寫的測試 | 型態 |
|---|---|---|
| 1 | ~20 處（`boss_battle_test` 9、`boss_ready_test` 2、三個 flow test 約 9） | 建立資料的前置條件變嚴（需先有 Question） |
| 2 | ~5 處 | 同上 |
| 3 | 8 處（`bosses_helper_test` 5 個改寫為 model 測試、system test 的 seed helper 3 處補關聯） | 邏輯換位置，期望值不變 |
| 4 | ~4 處（`question_flow_test` 的 seed helper ＋ 提示相關斷言） | seed helper 結構調整 |
| 7 | 1-2 處（`player_test`，僅在 7d 獲准時） | 語意變更 |

**全部屬於「建立測試資料的方式改變」，沒有任何一項需要變更斷言的期望值** ——
除了 7d（若獲准）會改變一個測試的期望。這正是「對外行為不變」的可驗證形式：
若改完後有斷言值需要調整，就代表某處行為被動到了，應該回頭檢查。

**建議的驗收動作**：`bin/rails test` 全綠 ＋ `bin/rails test:system` 全綠 ＋ `bin/rubocop` ＋
`bin/brakeman` 無新增警告（`.github/workflows/ci.yml` 已在跑這四項）。
另建議在 M5 後手動確認 `db/schema.rb` 的 `create_table` 區塊確實出現 `t.check_constraint`
（Rails 7.2 會 dump 進 schema.rb）。

---

## 5. 刻意保留的非正規清單（必須寫進 schema 註解與 README）

這一節是本方案最重要的展示項。**能說清楚為什麼不改，比硬把所有東西正規化更能展現判斷力。**
以下每一項都建議在 migration 裡用 `comment:` 或在對應 model 的檔頭註解寫明。

| # | 保留的非正規設計 | 位置 | 理由 |
|---|---|---|---|
| 1 | `reward_codes.player_email` 是字串 key 而非 FK | `db/schema.rb:101,106` | 配發以「人」為單位，不以「隊籍」為單位。`sessions#create`（`sessions_controller.rb:57`）在換序號時會建立**新的 Player 列**，改 FK 會讓同一個人重複領獎。承襲 `WHEEL_PLAYER_REWARD.USER_ID`（2018 dump 確認）。已用 CHECK 補上 `claimed_at` 的同生共死約束。 |
| 2 | `boss_battles.hp` 是 `questions.boss_hp` 的複本 | `db/schema.rb:31` | **開戰瞬間的快照**。進行中的戰鬥不應因為題目被調整而改變難度。這是有意的時點凍結，不是重複儲存。 |
| 3 | `boss_time_limit` 不做快照（與第 2 項不對稱） | `bosses_controller.rb:109` | 因為它**本質上是動態的**：`bosses_helper.rb:13` 會依當前隊伍是否有 uncle 加 10 秒，隊員可以在戰鬥前換職業。無法快照，所以每次即時計算。這個不對稱是刻意的，要寫明，否則看起來像疏漏。 |
| 4 | `score_entries` 存 5 個分項＋`total_score`（`total = max(0, Σ分項)`，可導出） | `db/schema.rb:112-117` | **結算帳本**。分項本身取決於結算當下的隊伍職業組成（`score_calculator.rb:75,79`），事後無法重算 —— 玩家改職業或退隊都會讓重算結果不同。整列是一次結算的物化快照。 |
| 5 | `players` 同時承載 person（`email`）與 membership（`team_id`/`role`/`job`）與聯絡資訊（`name`/`mobile`/`gender`） | `db/schema.rb:49-61` | 聯絡資訊是 per-membership 而非 per-person。理論上會有跨隊更新異常，但 2018 真實資料 573 筆玩家中跨隊 email = **0 筆**（§0-E2）。這是一場活動的遊戲，不是 CRM；為零觀測頻率的情境抽 `participants` 表是過度工程。 |
| 6 | `boss_hp`/`boss_time_limit` 留在 `questions` 而非移進新的 `bosses` 表 | `db/schema.rb:91-92` | 它們是「這一戰」的參數而不是「這隻怪」的屬性。Q10 與 Q11 打同一隻怪但難度可以不同（`base_score` 已是 1000 vs 3000）；移進 `bosses` 會強迫兩題同難度 —— 那是行為變更，不是正規化。 |
| 6b | `questions.puzzle_rows`/`puzzle_cols` 稀疏欄位（11 題中只有 2 題有值），而非抽拼圖子型別表 | `db/schema.rb:89-90` | 兩個可空整數換一張表加一次 join 不划算；改用 CHECK 綁定 `kind = puzzle`，拿到九成完整性。 |
| 6c | `bosses` 表不含 `name` | §2-3 | 舊 dump 沒有 boss 名稱（§0-E1），加了就是憑空發明；view 目前顯示 `question.title`，加欄位只會誘發不必要的行為變更。 |
| 7 | `Player::MAX_MEMBERS = 3` 只在應用層，而 `MAX_LEADERS = 1` 落到 DB index | `player.rb:5,21-33` | 唯一性可以用 partial unique index 表達，計數上限不行（需要 trigger）。**不為了對稱而引入 trigger** —— 那是為形式犧牲可維護性。這個不對稱要寫明。 |
| 8 | DB 外鍵一律 RESTRICT，刪除連鎖只在 Rails 的 `dependent: :destroy` | `schema.rb:133-139`、`team.rb:16-19` | RESTRICT 是比 CASCADE 安全的預設：繞過應用層的刪除會**失敗**而不是靜默毀掉歷史。應用層仍提供正常的連鎖刪除路徑。 |

---

## 6. 未能確定 / 需使用者裁決的點

1. **7d（`players` 唯一鍵收緊）** —— 這是全案唯一會改變對外行為的項目，需要拍板選項 1/2/3（見 §2-7d）。
2. **`bosses` 的 10 列切分是否正確** —— 本方案採信 `1afb2b4` 的考證
   （`app/helpers/game/bosses_helper.rb:16-31`）：Q10/Q11 是同一隻摩天輪魔王的兩個型態，
   `mon10.gif` 從未獨立存在。這個結論是從題目原文與素材命名推論出來的，**不是從 dump 直接證實的**
   （§0-E1 確認舊 DB 根本沒有 boss 主檔，所以無從證實）。若使用者手上有其他佐證推翻它，
   `bosses` 就該是 11 列、`boss_phase` 整欄移除，M2 的 backfill 需相應調整。
3. **`hints_enabled` 的 override 能力** —— §2-4 判定移除。seeds 的 11 題不使用該組合，
   但 `test/integration/game/question_flow_test.rb:170` 把它當測試捷徑在用（需改寫，斷言不變）。
   若使用者預期未來會有「有提示文字但暫時關閉」的營運需求，應保留該欄位並改為 nullable override。
4. **是否壓縮 migration 歷史** —— §3 建議保留 M1-M5 作為設計痕跡，但這是偏好問題，
   壓回原批次也是合理選擇。
5. **`.claude/worktrees/venture-ferris-rails-refactor-ac8f21/`** 內有一份較舊的完整程式碼副本，
   grep 時會產生大量重複命中。本文件的所有行號**均取自 repo 根目錄的工作樹**，
   未採用該 worktree 的任何內容。若該目錄已無用途，建議清理（另見使用者 memory 中記載的
   「RuboCop 隱藏目錄 worktree 誤報」）。

---

## §7 反方審查裁決（2026-08-30，實作前必讀）

經獨立反方審查後的**最終範圍**：**M0＋M1～M4＋7b＋7d**。以下修正與裁決優先於前文任何矛盾之處。

### 本次範圍（敘事：參照完整性＋一個真實競態＋一個刻意行為修正）
- **M0（新增，排最前）**：先寫一個 `travel_to` 凍結時間的全鏈 integration 測試（timer→提示×N→answer→ready→attack 擊敗→score），6 個分項與 total 全部字面量斷言，另含 senior/celebrity 兩變體——重構前先綠，是計分不變式唯一可信驗收。
- M1 `question_hints` 子表、M2 `bosses` 表、M3/M4 兩個 FK 正規化、7b `[team_id, job]` partial unique、7d `[team_id, email]` unique（已裁決的刻意行為修正）。

### 踢出本次（留待後續獨立 PR）
7a／7e／7f／7g（CHECK 批次，唯一舉證不成立且零已知缺陷）、7c（已有應用層防護的 [I] 級）、7i（`last_critical_at` 逾時未清——是**行為修正**，混入會破壞「schema 重構不改行為」敘事）、刪除 `boss_asset_available?`（論證錯誤：NOT NULL 字串與 asset 檔案存在無關，保留防禦、參數改 sprite）、worktree 清理。

### 實作必補（審查抓到的必爆點）
1. `app/models/player.rb:16` 驗證 scope 同步改為 `:team_id`（否則 7d 下 `save` 過 Ruby 驗證、PG 炸 RecordNotUnique → 500）。
2. `sessions#create`（:68-76）與 `sessions#update`（:91-98）都要 `rescue ActiveRecord::RecordNotUnique` 並對映錯誤碼；`#update` 要處理 7b（job 衝突）與 7d（email 衝突）。
3. 7d 分支順序定案：`find_by(role:, email:)` 未命中後、名額檢查**之前**，先查 `team.players.exists?(email:)` → 命中回**新錯誤碼 01006**「此 Email 已在此隊伍以其他身分註冊，請使用帳號轉移」（補 `zh-TW.yml` 鍵；錯誤頁既有的「帳號轉移」按鈕適用此碼）。
4. `test/integration/game/status_json_test.rb:45` 兩名玩家改指定不同 job。
5. `test/integration/game/settlement_flow_test.rb` 的 `seed_question(11)` 需建 2 則 hint 子列以維持 `hint_score < 0` 斷言。
6. 測試盤點實為 **14 處 `Question.create!`／11 檔**；`bosses` 在測試 DB（schema:load）不存在，migration 內 INSERT 靠不住——**bosses 種子資料必須進 `db/seeds.rb`，測試 helper 各自 `Boss.find_or_create_by!(sprite:)`**。
7. M1 用 `remove_columns`（非 remove_column 多欄位誤用）；M1-M4 寫 `def up`/`def down`（down 直接 raise IrreversibleMigration）。
8. M3 孤兒清理先刪 `boss_readies` 再刪 `boss_battles`（FK RESTRICT）。
9. M1 backfill position 用 `row_number()` 稠密編號。
10. **`boss_battles` 唯一鍵維持 `[team_id, question_id]`——戰鬥單位是 question 不是 boss**（Q10/Q11 是兩場戰鬥打同一隻怪）；`bosses.sprite` 存裸值（`mon11`），view 端補 `.gif`。
11. `HINT_LIMIT`→`hints.size` 僅在「每題 0 或 2 則」時與現況等價，seeds 加註記錄此依賴。
12. 文件勘誤：§2-7a 的 `insert_all!` 舉證不成立（teams 無 enum 欄位）；§4「`player_test.rb:59-65` 需重寫」為假陽性（收緊後斷言仍成立）；§2-4/§4 的 `hints` vs `question_hints` 命名統一為 `has_many :hints, class_name: "QuestionHint"`。
