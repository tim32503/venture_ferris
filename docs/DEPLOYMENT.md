# 部署手冊：Fly.io

本文件是「從零到上線」的完整操作序列。目標配置與定價依據見
`docs/DEPLOYMENT_RESEARCH.md`「Fly.io 深度查證」節——結論是 app machine
shared-cpu-1x／512MB＋512MB swap（auto-suspend）＋ unmanaged Fly Postgres
單節點 Development 預設（256MB）＋東京 nrt，這個組合的月費試算落在
Fly.io 目前對 <$5 帳單的小額豁免區間內（非合約保證，見查證文件第 1 節）。

配置檔已就緒：`fly.toml`、`.github/workflows/deploy.yml`、
`config/environments/production.rb`（`assume_ssl`＋`force_ssl`）、
`Dockerfile`（Rails 預設產生，未做任何修改，見下方「Dockerfile 相容性」）。
以下指令你需要本機登入 flyctl 後親自執行——這份文件只是準備工作，
不包含任何已執行過的 Fly 帳號操作。

## 前置需求

- `flyctl` 已安裝（本機已確認 `v0.4.19`）。
- 一個 Fly.io 帳號（Personal organization 或其他 org）。

## 1. 登入

```bash
fly auth login
```

跳出瀏覽器完成登入。之後所有指令都會用這個 session 的憑證。

## 2. 建立 app（不含 Postgres）

```bash
fly apps create venture-ferris
```

`fly.toml` 的 `app = "venture-ferris"` 已經寫死這個名字。**若這個名字已被別人註冊**，
`fly apps create` 會直接報錯——這時要：

1. 換一個名字重跑，例如 `fly apps create venture-ferris-<your-suffix>`。
2. 回頭把 `fly.toml` 的 `app = "..."` 改成同一個名字。
3. 同步更新 `config/environments/production.rb` 中 `ALLOWED_HOSTS` 註解提到的
   `venture-ferris.fly.dev`，以及本文件後續所有 `venture-ferris.fly.dev` /
   `-a venture-ferris` 出現的地方，換成新名字對應的 `<app>.fly.dev`。

## 3. 建立 PostgreSQL（unmanaged Fly Postgres，nrt，256MB 單節點）

```bash
fly postgres create \
  --name venture-ferris-db \
  --region nrt \
  --initial-cluster-size 1 \
  --vm-size shared-cpu-1x \
  --vm-memory 256 \
  --volume-size 1 \
  --org <your-org-slug>
```

旗標對應官方互動精靈的「Development」預設（1x shared CPU／256MB RAM／1GB
disk／單節點，見查證文件第 5(b) 節）。`--org` 換成 `fly orgs list` 查到的
slug（Personal org 通常是你的帳號 slug）。

這一步會印出資料庫的 superuser 密碼——**記下來但不需要手動用它**，下一步
`fly postgres attach` 會自動處理連線字串。

⚠️ 官方文件明講這是 unmanaged／非 HA 的資料庫：單顆磁碟壞掉或網路問題會
直接讓資料庫下線，且只有「每日快照、保留 5 天」這一層備份，沒有異地備援
（查證文件第 5(b)／第 3 節）。這是本專案（單機、流量低、成本優先）刻意接受
的取捨，不適合直接套用到有 SLA 要求的專案。

## 4. 把資料庫接到 app

```bash
fly postgres attach venture-ferris-db -a venture-ferris
```

這個指令會自動在 `venture-ferris` app 建立一個 `DATABASE_URL` secret，內容
指向剛建立的資料庫（含使用者、密碼、內部網域）。`config/database.yml` 的
production 區塊本來是給沒有 `DATABASE_URL` 時的 fallback 用的（見該檔案
註解與 `VENTURE_FERRIS_DATABASE_PASSWORD`）——一旦 `DATABASE_URL` 存在，
Rails 會用它覆蓋掉 `database.yml` 裡的所有連線細節，所以**不需要另外設定
`VENTURE_FERRIS_DATABASE_PASSWORD`**。

## 5. 設定其餘 secrets

```bash
fly secrets set \
  RAILS_MASTER_KEY="$(cat config/master.key)" \
  ADMIN_PASSWORD="<選一個夠強的密碼>" \
  ALLOWED_HOSTS="venture-ferris.fly.dev" \
  -a venture-ferris
```

- `RAILS_MASTER_KEY`：`cat config/master.key` 讀出本機的 master key（這個檔案
  不會被打包進 image，見 `.dockerignore`），讓正式環境能解密 `credentials.yml.enc`。
- `ADMIN_PASSWORD`：後台登入密碼，`db/seeds.rb` 用 `ENV.fetch("ADMIN_PASSWORD", "changeme")`
  讀取——**正式環境務必蓋掉 `changeme` 這個預設值**。
- `ALLOWED_HOSTS`：啟用 `config/environments/production.rb` 的 Host header 保護，
  值是逗號分隔的允許網域清單。之後若加自訂網域（見第 10 節），要把新網域也
  加進這個清單並重新 `fly secrets set`。

`fly secrets set` 執行後會觸發一次部署（除非加 `--stage`）；此時 app 可能還沒
`fly deploy` 過，這次自動部署可能因為 image 還不存在而失敗或被跳過，屬正常
現象，下一步的 `fly deploy` 才是真正第一次上線。

## 6. 部署

```bash
fly deploy
```

flyctl 會用 `Dockerfile` 建 image（預設走 remote builder），推送後：

1. 先跑 `fly.toml` 的 `release_command`（`bin/rails db:prepare`）在一台獨立的
   release machine 上，建好 schema。
2. 再啟動 app machine，套用 `[[vm]]` 的 512MB＋512MB swap 規格，掛上
   `[http_service]` 的 `auto_stop_machines = "suspend"` 等設定。

## 7. 首次載入 seed 資料

```bash
fly ssh console -a venture-ferris -C "bin/rails db:seed"
```

`db/seeds.rb` 是 idempotent 的（見檔案開頭註解），可以重複執行不會產生重複
資料。這一步會建立題目、序號池、管理員帳號等正式環境需要的初始資料。

## 8. 驗證

```bash
fly status -a venture-ferris
curl -I https://venture-ferris.fly.dev/up
```

- `fly status` 應顯示至少一台 machine，且 `[http_service.checks]` 設定的
  `/up` 健康檢查通過。
- `curl` 對 `/up` 應回 `200`（Rails 內建的 `rails/health#show`，見
  `config/routes.rb`）。
- 瀏覽器打開 `https://venture-ferris.fly.dev/admin`，用第 5 步設定的
  `ADMIN_PASSWORD` 登入，確認後台功能正常。
- 打開首頁的 Demo 入口，確認遊戲流程可以正常跑一輪（`rack-attack` 節流規則
  見 `config/initializers/rack_attack.rb`，正常操作不會觸發 429）。

## 9. 設定 GitHub Actions 的 `FLY_API_TOKEN`

`.github/workflows/deploy.yml` 在 push 到 `main`／手動 `workflow_dispatch`／
每日排程時都會先檢查這個 secret 是否存在，不存在就印出警告並跳過（不會讓
build 變紅）。要讓自動部署與每日 `demo:cleanup` 生效：

```bash
fly tokens create deploy -a venture-ferris -x 8760h
```

`-x 8760h` 把 token 效期設成 1 年（預設是 20 年，正式環境建議設短一點、
到期再重發）。指令會印出一長串 `FlyV1 ...` 開頭的 token 字串。

接著到 GitHub repo 設定：

```bash
gh secret set FLY_API_TOKEN --repo <org>/venture_ferris
```

貼上剛剛的 token（或改用網頁：repo → Settings → Secrets and variables →
Actions → New repository secret，Name 填 `FLY_API_TOKEN`）。設定完成後，
下一次 push 到 `main` 就會自動部署；也可以到 Actions 分頁手動觸發
`workflow_dispatch` 立即測試。

## 10. 自訂網域與憑證（可選）

若之後要掛自訂網域（例如 `example.com`）：

```bash
fly certs add example.com -a venture-ferris
```

指令會印出需要在你的 DNS 供應商設定的 A/AAAA 或 CNAME 紀錄。設定好 DNS 後：

```bash
fly certs check example.com -a venture-ferris
```

確認驗證與憑證簽發狀態（Let's Encrypt 自動簽發，通常幾分鐘內完成）。別忘了
回到第 5 步，把新網域加進 `ALLOWED_HOSTS`：

```bash
fly secrets set ALLOWED_HOSTS="venture-ferris.fly.dev,example.com" -a venture-ferris
```

## 11. 費用監控提醒

- Fly.io **目前沒有帳單告警／支出上限功能**（官方原文：「We don't support
  billing alerts (yet), so budget accordingly.」見查證文件第 7 節）。建議
  **每月至少手動看一次** [Fly.io dashboard](https://fly.io/dashboard) 的
  「current month to date bill」。
- 本文件開頭提到的「<$5 帳單 100% 減免」是 Fly.io 工程師在社群論壇的舊說明，
  **不是官方定價文件的逐字承諾**，且 2024/10 新方案後沒有官方書面重新確認
  （查證文件第 1 節）。不要把它當成合約保證——只要 app 常駐運轉時間拉長、
  或 Postgres 規格提高，月費會超過這個門檻。
- 若要更保守地控制風險，可以考慮加值 Fly.io 的最低 $25 預付額度作為隱性上限
  （額度用完帳號會被限制，等同手動式的支出天花板，見查證文件第 7 節）。

## 12. 常見問題

**Q: 首次打開網站很慢，是不是壞了？**

不是。`auto_stop_machines = "suspend"` 讓機器在沒有流量時進入 suspend 省錢，
第一個請求進來要喚醒機器。官方說明 suspend 恢復通常是「幾百毫秒」等級，
但**不是保證行為**——遇到 host migration 或容量緊張時會退化成較慢的
「stopped → 冷啟動」路徑（官方定性描述約 2 秒等級，無精確保證數字，見查證
文件第 8 節）。這是這個成本區間的正常取捨，不需要每次都當成故障處理。

**Q: PostgreSQL 資料庫掛掉/需要還原到之前某個時間點，怎麼辦？**

Unmanaged Fly Postgres 預設每天自動快照、保留 5 天（查證文件第 3 節）。還原
步驟：

```bash
# 1. 列出資料庫的 volume ID
fly volumes list -a venture-ferris-db

# 2. 列出這個 volume 的可用快照
fly volumes snapshots list <volume-id>

# 3a. 用某個快照建一個全新的 Postgres cluster（推薦，不動到現有壞掉的那顆）
fly postgres create --snapshot-id <snapshot-id> --region nrt --org <your-org-slug>

# 3b. 或者從既有 app 的某個 volume fork 出一個新 volume（同一顆快照來源的另一種操作方式）
fly volumes fork <volume-id> -a venture-ferris-db
```

還原成新 cluster 後，需要重新 `fly postgres attach` 到 `venture-ferris` app
（會覆蓋掉舊的 `DATABASE_URL` secret），再 `fly deploy` 讓新連線生效。因為
是單節點、非 HA 架構，這個「重建＋重接」流程沒有自動化 failover，需要人工
介入——這正是查證文件第 5(b) 節提醒的取捨。

## Dockerfile 相容性

`Dockerfile` 是 `rails new` 產生的預設版本，**未做任何修改**，逐項確認與
Fly.io 相容：

- `EXPOSE 3000` ＋ `CMD ["./bin/rails", "server"]`：對應 `fly.toml`
  `[http_service] internal_port = 3000`。
- `bin/docker-entrypoint` 在啟動 `rails server` 前跑一次 `bin/rails db:prepare`：
  與 `fly.toml` 的 `release_command = "bin/rails db:prepare"` 是兩層防護
  （release_command 在部署時的獨立 machine 跑一次；docker-entrypoint 在每次
  機器開機/從 suspend 恢復時再跑一次防禦性檢查）。`db:prepare` 是 idempotent
  的，兩者並存不是重複設定，是刻意的雙保險。
- `SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile`：build 階段不需要
  `RAILS_MASTER_KEY` 就能編譯 assets，與「secrets 要到 deploy 時才透過
  `fly secrets set` 注入」的 Fly.io 流程相容。
- `apt-get install ... libvips postgresql-client`：`pg` gem 需要的 client
  library 已包含，不需額外修改。

不需要對 Dockerfile 做任何微調。

## GitHub Actions token-guard 邏輯說明

`.github/workflows/deploy.yml` 的 `check-token` job 用一個獨立 step 把
`secrets.FLY_API_TOKEN` 讀進環境變數再用 `[ -n "$FLY_API_TOKEN" ]` 判斷是否
為空字串，把結果寫進 `has_token` output（而不是在 `if:` 條件式裡直接引用
secrets context，避免把 secret 值攪進條件運算式）。`deploy` 與
`demo-cleanup` 兩個 job 都用 `needs.check-token.outputs.has_token == 'true'`
當作 `if:` 前提——secret 不存在時兩個 job 直接被跳過（GitHub Actions 顯示
灰色 skipped，不是紅色 failed），並在 `check-token` job 印出
`::warning::` 提示，讓人知道要去設定 secret，但不會讓 CI 變紅。`deploy`
另外用 `github.event_name != 'schedule'` 排除排程觸發、`demo-cleanup` 用
`github.event_name == 'schedule'` 只在排程觸發時跑，兩者互斥，同一次
workflow run 不會同時部署又跑 cleanup。
