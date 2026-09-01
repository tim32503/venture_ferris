# Taipeicooc2018 → Rails 重構盤點報告

來源路徑：`/Users/curihaosity/Desktop/Taipeicooc2018`

## 結論摘要

這是一個 2018 年為台北某活動（美麗華摩天輪／城市定向遊戲，網域 `taipeicooc2018.escapeholics.com`）做的**團隊實境解謎遊戲網站**，CodeIgniter 3.1.9 + MySQL。核心玩法：玩家掃 QR code 帶著 16 碼序號登入 → 組隊（隊長/隊員各一角色）→ 選職業 → 依序解 10 道地點謎題（含拼圖、問答）→ 打王（Boss 戰，攻擊次數/血量）→ 結算積分 → 兌獎（QR code 兌獎序號）。全站無帳號密碼登入，身份完全靠 URL 帶的序號寫入 CI session；後台（序號產生器）用 Firebase Auth 做前端登入畫面，但 controller 完全沒有伺服器端驗證，`/admin/home`、`/admin/generate` 可直接繞過登入存取。專案內有明文 DB 密碼與過期的個人 Firebase 專案金鑰，上架前必須清除/換掉；前端資源全吃 CDN（Bootstrap 4.1.3、jQuery 3.3.1、Firebase 5.3.0），本地素材只有 CSS 兩份、一個拼圖 jQuery plugin、45 張圖片，可直接搬。沒有找到任何 SQL dump／migration，資料表結構是從程式碼的 Active Record 呼叫反推出來的，非官方 schema。

## 1. 框架與版本

- CodeIgniter **3.1.9** — `system/core/CodeIgniter.php:58`（`const CI_VERSION = '3.1.9';`）
- 專案內無 `composer.json` / `composer.lock`，無法從程式碼直接讀出 PHP 版本鎖定（查無明確 `version_compare(PHP_VERSION, ...)` 門檔或宣告）
- 【推論，非程式碼明示】CI 3.1.9 為 2018 年版本，官方相容 PHP 5.6 ~ 7.2/7.3；`user_guide/changelog.html` 內多處提到 PHP 5.6+ / PHP 7.2 的修正（如 `user_guide/changelog.html:466`, `:477`），可作為旁證但非本專案的強制宣告
- 專案根目錄找不到 `index.php`（只有 `.claude/`、`application/`、`contents/`、`system/`、`user_guide/`），CI 標準入口檔案在這份備份中缺失——查無，可能是備份/複製時遺漏

## 2. 路由與功能清單

`application/config/routes.php:52-54` 只設定了預設路由（`default_controller = welcome`），**沒有任何自訂路由規則**，所有 URL 走 CI 預設 `/controller/method/param` 對應。完整表格見附錄 A。

四個 controller：`Welcome`、`Wheel`（核心遊戲，31 個 public method）、`Admin`（後台序號產生器，4 個 method）、`Test`（開發期測試頁，1 個 method，與遊戲無關的滑鼠框選 demo）。

## 3. 資料模型

`find -iname "*.sql"` 對整個專案（含 system/、user_guide/）搜尋**查無任何 .sql 檔或 migration 檔**（`application/config/migration.php:14` 也顯示 `migration_enabled = FALSE`，從未使用過 CI migration 機制）。以下資料表清單是**從 `application/models/wheel/Wheel_model.php` 內所有 `$this->db->select/where/from` 呼叫反推**，只能保證「程式碼用到的欄位」，不保證是完整 schema（可能還有程式碼沒碰過的欄位/表）。完整表格見附錄 B。

7 張表：`WHEEL_PLAYER_MAIN`、`WHEEL_PLAYER_USER`、`CODE_MAIN`、`QUEST_MAIN`、`QUEST_LOG`、`BOSS_LOG`、`WHEEL_PLAYER_REWARD`、`QUEST_SCORE`。`application/models/wheel/Register_model.php` 是空殼 model（只有 constructor，無任何方法）——死代碼。

## 4. Views 與頁面

`application/views/` 下共 24 個功能性 `.php` view（不含 CI 內建的 `errors/` 目錄與 `index.html` 佔位檔）。分類：

- **公開頁（遊戲玩家用，`wheel/` + 根層）**：`wheel_index`（首頁/劇情導覽）、`wheel_login`、`wheel_team`、`wheel_job`、`wheel_home`（主選單）、`wheel_map1/2/3`、`wheel_question`、`wheel_puzzle`、`wheel_bear`、`wheel_boss`、`wheel_solved`、`wheel_score`、`wheel_reward`、`wheel_record`、`privacy.php`（隱私權條款）、`error_msg.php`（共用錯誤頁，Welcome 與 Wheel 都用）
- **後台/管理頁（`admin/`）**：`admin_index.php`（Firebase 登入畫面）、`admin_identify.php`（登入後前端驗證信箱）、`admin_home.php`（單筆序號＋QR code 產生器）、`admin_generate.php`（一次產生 5000 筆遊戲序號 + 20000×2 筆獎品序號的純前端隨機表格，**不寫入資料庫**，純展示用來人工複製）
- **開發測試/死代碼**：`test_index.php`（滑鼠框選特效 demo，與遊戲無關）、`welcome_message.php`（CI 預設歡迎頁，`Welcome` controller 未呼叫它，目前無路由指向，屬孤兒 view）
- **共用 layout**：`_layouts/header.php`、`_layouts/footer.php`（所有頁面共用的 CDN 資源載入與版頭）

完整檔案清單見附錄 C。

## 5. 靜態資源

`contents/`（專案唯一的 assets 目錄）：

- `site.css`、`boss.css`：專案自訂樣式，檔頭以非 UTF-8 編碼寫入中文註解（`site.css:1` 讀出來是亂碼，`boss.css:1` 是正常 UTF-8「字型設定」註解——同一專案兩個 CSS 檔編碼不一致，搬遷時要統一轉 UTF-8）
- `jquery.snap-puzzle.min.js`（2.8KB）：自訂/第三方拼圖拖拉 jQuery plugin，僅 `wheel_puzzle.php` 用到，供拼圖題目使用；Rails 化時建議找對應的原始未壓縮版或用現代 JS（Stimulus/Sortable）重寫，而不是直接搬 minified 檔
- `images/`：45 個檔案（28 png、10 gif、7 jpg），內容為怪物素材（`mon01~11.gif`）、地點/謎題圖（`P01~11`、`R01~11`）、地圖背景、Boss 素材（`bossBg.png`、`bossGrass.png`）、角色立繪（`uncle.png`、`senior.png`、`netizen.png`、`celebrity.png`）、logo、說明圖（`description.png`）——這些**都是純展示素材，可直接搬進 Rails 的 `app/assets/images` 或 `public/`**，不需要轉換
- CSS/JS 框架**全部走 CDN**，沒有 vendor 進本地：Bootstrap 4.1.3、jQuery 3.3.1、jQuery UI 1.12.1、Font Awesome 5.4.1、Firebase 5.3.0 + FirebaseUI 3.3.0/3.4.0（`application/views/_layouts/header.php:11-26`）。Rails 版可直接用對應版本的 gem/importmap 或升級版重新引入，本地無檔案需要搬遷

## 6. 對外整合與設定

- **資料庫**：MySQL，`mysqli` driver，DB 名稱 `AP_WHEEL`（`application/config/database.php:76-96`）
- **Email/SMTP**：查無——`application/config/autoload.php:61` 的 `$autoload['libraries']` 是空陣列，且全專案 grep 不到任何 `email` library 載入或 SMTP 設定
- **金流**：查無——沒有任何金流/付款相關程式碼或設定
- **Google**：
  - Google 已棄用的 **Image Charts API**（`https://chart.googleapis.com/chart?cht=qr...`）用來即時產生 QR code 圖片，出現在 `application/views/admin/admin_home.php:16` 與 `:19`——Rails 化要換成本地產生（如 `rqrcode` gem）
  - Google Fonts「Noto Sans TC」透過 `@import` 載入，`contents/site.css:2`、`contents/boss.css:2`
- **Firebase**：只用於**後台登入**的前端 UI（FirebaseUI + Firebase Auth），專案 ID `ferris-wheel-1534499577183`，設定寫在 `application/views/admin/admin_index.php:15-22`、`application/views/wheel/wheel_home.php:38-45`（同一組設定重複貼在多個 view 裡，非集中管理）。這組 Firebase 專案應已隨活動結束而停用/失效，Rails 版不建議沿用，需重建全新驗證機制
- **其他自訂設定**：`application/config/sys_settings.php:5-6` 定義 `test_mode`（0/1 開關測試序號）與 `img_url`（指向正式站的圖片絕對網址，而非站內相對路徑——views 裡很多 `<img>` 也直接寫死 `https://taipeicooc2018.escapeholics.com/...` 絕對網址，如 `wheel_home.php:29`）

## 7. 使用者驗證機制

**沒有傳統帳密登入，分兩套完全不同、且都不安全的機制：**

- **玩家端**：靠 URL 網址帶參數。`/wheel/login/{SERIAL_NO}/{CHAR_TYPE}`（`application/controllers/Wheel.php:19-31`）把 16 碼序號＋角色類型（Leader/Member）丟給 view；真正「登入」動作在 `/wheel/register/{sno}/{type}/{uid}/{gender}`（`Wheel.php:258-279`），呼叫 `Wheel_model::checkUserData()`（`application/models/wheel/Wheel_model.php:64-108`）驗證序號長度與是否存在於 `WHEEL_PLAYER_MAIN`，通過後用 `$this->session->set_userdata($data)` 把整包資料寫進 CI session（第 105 行）。之後所有頁面靠 session 裡的 `SERIAL_NO`/`USER_ID`/`CHAR_TYPE` 認人，**沒有密碼，沒有 token 過期以外的保護**，session 用 CI 內建 `session` library，`files` driver，cookie 名稱 `ci_session`，過期時間 7200 秒（`application/config/config.php:380-386`）。`csrf_protection` 是關閉的（`application/config/config.php:451`）
- **後台端**：`Admin` controller（`application/controllers/Admin.php`）四個 method **完全沒有任何伺服器端驗證**——不檢查 session、不檢查 token。畫面上用 Firebase Authentication + FirebaseUI 讓人用 Google/Email 登入，登入後由 `admin_identify.php:14-24` 這段**前端 JavaScript**檢查 `user.email != "<個人 Gmail，已遮蔽>"` 來決定要不要導去 `/admin/home`。也就是說任何人只要直接打 `GET /admin/home` 或 `/admin/generate` 就能看到序號產生器內容，Firebase 驗證只是「畫面導引」，不是真正的存取控制

## 8. 敏感資訊清單（只列位置，不貼值）

| # | 位置 | 內容類型 |
|---|------|---------|
| 1 | `application/config/database.php:79` | MySQL 帳號明文 |
| 2 | `application/config/database.php:80` | MySQL 密碼明文 |
| 3 | `application/views/admin/admin_index.php:17-22` | Firebase Web SDK 設定（apiKey/authDomain/databaseURL/projectId/storageBucket/messagingSenderId），舊活動專案，應視為需棄用 |
| 4 | `application/views/wheel/wheel_home.php:38-45` | 同一組 Firebase 設定重複出現 |
| 5 | `application/views/wheel/wheel_boss.php:12-20`（header 區塊，載入 Firebase JS/CSS） | 與上同一 Firebase 專案的 SDK 引用 |
| 6 | `application/views/admin/admin_home.php:16` | 寫死的個人 Gmail 帳號（個人 Gmail，已遮蔽）被當成「是否為管理員」唯一判斷依據 |
| 7 | `application/views/admin/admin_home.php:6,18,20,23,27,29` | 寫死指向個人測試網域 `https://test.curihaosity.xyz`，與正式網域（`application/config/config.php:26`：`https://taipeicooc2018.escapeholics.com/`）不一致，屬殘留的開發期硬編碼 |
| 8（次要，非洩漏） | `application/core/config/database.php` | 整個 `application/core/config/` 是與 `application/config/` 內容不同的孤兒複本（帳密欄位是空的，CI 也不會載入這個路徑，`grep -rn "core/config"` 全專案查無引用），清理時建議確認排除、不要誤搬進新專案 |

## 9. 舊專案 `.claude/` 資料夾

`/Users/curihaosity/Desktop/Taipeicooc2018/.claude/` 內只有一個檔案：`settings.local.json`，內容僅是權限允許清單（`Bash(mkdir:*)`、`Bash(find:*)`、`Bash(cp:*)`、`Bash(ls:*)`），**沒有任何先前分析筆記、規劃或指示**可摘要。

---

## 附錄 A：完整 Controller / Method → URL 對照表

### Welcome（`application/controllers/Welcome.php`）
| URL | Method | 行號 | 說明 |
|---|---|---|---|
| `/` `/welcome` `/welcome/index` | `index()` | 6-9 | 載入 `wheel/wheel_index`（遊戲首頁/劇情頁），實際上是全站入口 |
| `/welcome/privacy` | `privacy()` | 11-14 | 載入 `privacy` view（隱私權條款） |
| `/welcome/error/{errCode}` | `error($errCode)` | 16-21 | 載入 `error_msg`，訊息永遠寫死「測試」——測試期殘留 |

### Admin（`application/controllers/Admin.php`，**無伺服器端驗證**）
| URL | Method | 行號 | 說明 |
|---|---|---|---|
| `/admin` `/admin/index` | `index()` | 5-8 | Firebase 登入畫面 |
| `/admin/identify` | `identify()` | 10-13 | 登入後導頁邏輯（純前端） |
| `/admin/home` | `home()` | 15-18 | 單筆序號＋QR code 產生器 |
| `/admin/generate` | `generate()` | 20-22 | 批量產生遊戲序號/獎品序號（純展示，不寫 DB） |

### Test（`application/controllers/Test.php`）
| URL | Method | 行號 | 說明 |
|---|---|---|---|
| `/test` `/test/index` | `index()` | 6-9 | 滑鼠框選效果 demo，與遊戲功能無關 |

### Wheel（`application/controllers/Wheel.php`，核心遊戲，31 個 public method）
| URL | Method | 行號 | 說明 |
|---|---|---|---|
| `/wheel` `/wheel/index` | `index()` | 13-17 | 印出錯誤文字，無實際用途 |
| `/wheel/login/{sno}/{type}` | `login($sno, $type)` | 19-31 | 登入頁（帶序號與角色類型） |
| `/wheel/team/{src?}` | `team($src)` | 33-58 | 隊伍頁；`src=Login` 且已命名隊伍時直接轉到 home |
| `/wheel/job` | `job()` | 60-66 | 選職業頁 |
| `/wheel/home` | `home()` | 68-85 | 遊戲主選單 |
| `/wheel/map/{no?}` | `map($no)` | 87-112 | 依解題數顯示 map1/2/3，`no=2` 強制顯示 map2 |
| `/wheel/question/{qno}` | `question($qno)` | 114-187 | 依 qno(1~11) 顯示拼圖/問答/熊讚題頁，硬編碼 switch |
| `/wheel/boss/{bno}` | `boss($bno)` | 189-198 | Boss 戰頁面 |
| `/wheel/score/{qno?}` | `score($qno)` | 200-223 | 成績結算（提示次數、耗時、boss 分數加總） |
| `/wheel/reward` | `reward()` | 225-229 | 任務獎勵頁 |
| `/wheel/record` | `record()` | 231-246 | 已解題記錄頁 |
| `/wheel/error/{errCode}` | `error($errCode)` | 248-255 | 錯誤頁，訊息查 `CODE_MAIN` |
| `/wheel/register/{sno}/{type}/{uid}/{gender}` | `register(...)` | 258-279 | 玩家「登入/註冊」動作，寫入 session + `WHEEL_PLAYER_USER` |
| `/wheel/teamReg/{teamNM}` | `teamReg($teamNM)` | 281-285 | AJAX 設定隊名 |
| `/wheel/teamNMGet` | `teamNMGet()` | 287-293 | AJAX 取得隊名 |
| `/wheel/jobSelect/{job}` | `jobSelect($job)` | 295-299 | AJAX 設定職業 |
| `/wheel/jobCheck` | `jobCheck()` | 301-305 | AJAX 取得隊員職業列表 |
| `/wheel/jobIsNull` | `jobIsNull()` | 307-311 | AJAX 檢查是否有隊員未選職業 |
| `/wheel/timer/{table}/{no}/{type}` | `timer(...)` | 313-321 | AJAX 開始/結束題目或 Boss 計時 |
| `/wheel/attack/{bno}/{times?}` | `attack(...)` | 323-329 | AJAX 記錄攻擊次數 |
| `/wheel/getBossHP/{bno}` | `getBossHP($bno)` | 331-336 | AJAX 取得 Boss 血量百分比 |
| `/wheel/questionIsStart` | `questionIsStart()` | 338-342 | AJAX 輪詢：目前是否有進行中的題目計時 |
| `/wheel/bossIsStart` | `bossIsStart()` | 344-348 | AJAX 輪詢：目前是否有進行中的 Boss 戰 |
| `/wheel/teamIsReady` | `teamIsReady()` | 350-354 | AJAX 輪詢隊伍預備人數 |
| `/wheel/ready/{bno}` | `ready($bno)` | 356-360 | AJAX 標記隊員預備完成 |
| `/wheel/setHintCount/{qno}` | `setHintCount($qno)` | 362-366 | AJAX 增加提示使用次數 |
| `/wheel/getHintCount/{qno}` | `getHintCount($qno)` | 368-372 | AJAX 取得提示使用次數 |
| `/wheel/getHint/{qno}` | `getHint($qno)` | 374-381 | AJAX 依已用次數回傳提示內容 |
| `/wheel/setInfo/{name}/{gender}/{mobile}` | `setInfo(...)` | 383-387 | AJAX 儲存兌獎聯絡資訊 |
| `/wheel/getInfo` | `getInfo()` | 389-393 | AJAX 檢查兌獎資訊是否填齊 |
| `/wheel/setQRCode` | `setQRCode()` | 395-399 | AJAX 配發 2 組未使用的兌獎序號 |
| `/wheel/getQRCode` | `getQRCode()` | 401-405 | AJAX 取得已配發的兌獎序號 |
| `/wheel/getQuestionSolved` | `getQuestionSolved()` | 407-411 | AJAX 取得已解題號列表 |
| `/wheel/checkTimerEnd/{qno}` | `checkTimerEnd($qno)` | 413-417 | 除錯用，直接 print_r |
| `/wheel/setScore/{qno}/{question}/{time}/{hint}/{boss}/{total}/{job}` | `setScore(...)` | 419-423 | AJAX 寫入最終成績列 |
| `/wheel/checkJob/{job}` | `checkJob($job)` | 426-430 | AJAX 驗證某職業是否已被目前 session 玩家佔用 |
| `/wheel/updateSNo` | `updateSNo()` | 432-436 | AJAX 依 session 重新綁定序號/角色到 `WHEEL_PLAYER_USER` |
| `/wheel/test` | `test()` | 439-443 | 與 `updateSNo()` 邏輯重複，測試期殘留別名 |

## 附錄 B：資料表清單（從 Active Record 呼叫反推，非官方 schema，查無 SQL dump/migration）

| 表名 | 出現欄位（程式碼可見範圍） | 用途 |
|---|---|---|
| `WHEEL_PLAYER_MAIN` | `SERIAL_NO`, `SERIAL_TYPE`, `TEAM_NM` | 序號主檔／隊伍名稱 |
| `WHEEL_PLAYER_USER` | `SERIAL_NO`, `CHAR_TYPE`(Leader/Member), `USER_ID`, `CHAR_JOB`, `USER_NAME`, `USER_GENDER`, `USER_MOBILE` | 隊員個人資料 |
| `CODE_MAIN` | `CODE_TYPE`, `CODE_ID`, `CODE_NM` | 通用代碼表（目前只看到拿來查 ERROR 訊息） |
| `QUEST_MAIN` | `QUESTION_NO`, `QUESTION_TITLE`, `QUESTION_PASSWORD`, `QUESTION_CONTENT`, `QUESTION_LEVEL`, `QUESTION_HINT1`, `QUESTION_HINT2`, `QUESTION_EXPLAIN` | 題目主檔 |
| `QUEST_LOG` | `SERIAL_NO`, `QUESTION_NO`, `TIME_BEGIN`, `TIME_END`, `HINT_COUNT` | 解題計時紀錄 |
| `BOSS_LOG` | `SERIAL_NO`, `BOSS_NO`, `TIME_BEGIN`, `TIME_END`, `ATTACK_TIMES`, `BOSS_HP`, `READY_COUNT` | Boss 戰計時/血量/預備狀態 |
| `WHEEL_PLAYER_REWARD` | `REWARD_NO`, `USER_ID`, `REWARD_TYPE`, `UPD_DT` | 兌獎序號池 |
| `QUEST_SCORE` | `SERIAL_NO`, `QUESTION_NO`, `QUESTION_SCORE`, `TIME_SCORE`, `HINT_SCORE`, `BOSS_SCORE`, `TOTAL_SCORE`, `JOB_SCORE` | 最終積分明細 |

來源：`application/models/wheel/Wheel_model.php`（全部 `$this->db->select/where/from/insert/update` 呼叫逐一比對得出，行號範圍見該檔第 10~1137 行各方法）。`application/models/wheel/Register_model.php` 為空殼，未使用。

## 附錄 C：完整 View 檔案清單

```
views/welcome_message.php        （CI 預設歡迎頁，孤兒 view，無路由指向）
views/privacy.php                （公開：隱私權條款）
views/test_index.php             （開發測試 demo，與遊戲無關）
views/error_msg.php              （公開：共用錯誤頁）
views/admin/admin_index.php      （後台：Firebase 登入畫面）
views/admin/admin_identify.php   （後台：登入後前端驗證信箱並導頁）
views/admin/admin_home.php       （後台：單筆序號 + QR code 產生器）
views/admin/admin_generate.php   （後台：批量序號產生，純展示不寫 DB）
views/wheel/wheel_index.php      （公開：遊戲首頁/劇情導覽）
views/wheel/wheel_login.php      （公開：登入頁）
views/wheel/wheel_puzzle.php     （公開：拼圖題頁）
views/wheel/wheel_team.php       （公開：隊伍頁）
views/wheel/wheel_record.php     （公開：解題記錄頁）
views/wheel/wheel_home.php       （公開：遊戲主選單）
views/wheel/wheel_solved.php     （公開：題目已解過提示頁）
views/wheel/wheel_boss.php       （公開：Boss 戰頁）
views/wheel/wheel_score.php      （公開：成績結算頁）
views/wheel/wheel_job.php        （公開：選職業頁）
views/wheel/wheel_reward.php     （公開：任務獎勵頁）
views/wheel/wheel_map2.php       （公開：地圖2）
views/wheel/wheel_question.php   （公開：問答題頁）
views/wheel/wheel_bear.php       （公開：熊讚特殊題頁）
views/wheel/wheel_map3.php       （公開：地圖3）
views/wheel/wheel_map1.php       （公開：地圖1）
views/_layouts/header.php        （共用：頁首/CDN 資源載入）
views/_layouts/footer.php        （共用：頁尾）
views/errors/html/*.php          （CI 內建錯誤頁模板，框架預設，未客製）
views/errors/cli/*.php           （CI 內建 CLI 錯誤頁模板，框架預設，未客製）
```
（`views/index.html`、`views/errors/index.html`、`views/errors/html/index.html`、`views/errors/cli/index.html` 為 CI 標準防目錄瀏覽佔位檔，非功能頁，未列入上表。）
