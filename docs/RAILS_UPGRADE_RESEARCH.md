# Rails 7.2 EOL 與升級路徑查證

> 查閱日期：2026-09-02。來源：rubyonrails.org/maintenance、guides.rubyonrails.org/upgrading_ruby_on_rails.html、rubygems.org（皆官方）。
> 註：原委派的研究 agent 因機器休眠中斷，本文件由主對話直接以官方來源完成查證。

## 結論摘要

1. **Rails 7.2.x 已完全 EOL**：安全修補止於 2026-08-09（官方 maintenance 頁；與 brakeman `EOLRails` 警告一致）。**必須升級**。
2. **升級目標選 8.1.x（現行 8.1.3.1）**，不要停在 8.0：8.0.x 的安全修補只到 **2026-11-07**（剩兩個月），8.1.x 的 bug 修補到 2026-10-10、安全修補到 **2027-10-10**。
3. **Ruby 3.3.5 可直上**：Rails 8.0/8.1 最低要求 Ruby 3.2.0。（Ruby 版本升級可另案，非本次前置。）
4. **官方建議逐個 minor 走**：7.2 → 8.0.5.1（app:update、修 deprecation、測試綠）→ 8.1.3.1（同流程）。
5. **Sprockets 在 Rails 8 仍是可用的 optional gem**（7.0 起即為 optional dependency）；官方升級指南對 8.x 未要求換 Propshaft。是否順勢把 sassc-rails→dartsass（README 既列的未來項）併入本次：**建議併入**——避免「升了框架還掛著 EOL 編譯器」的半吊子狀態，但作為升級後的獨立 commit，失敗可單獨退回。
6. 官方指南明列的 8.0→8.1 變更：`schema.rb` 欄位改字母排序（會有一次性的大 schema diff，屬預期）。7.2→8.0 的細節在 release notes（實作時逐項對照 `load_defaults 8.0` 的 new_framework_defaults 檔案）。

## 版本支援時間表（官方 maintenance 頁）

| 系列 | bug 修補 | 安全修補 | 狀態 |
|---|---|---|---|
| 8.1.x（8.1.3.1） | 至 2026-10-10 | 至 **2027-10-10** | ✅ 建議目標 |
| 8.0.x（8.0.5.1） | 已結束（2026-05-07） | 至 2026-11-07 | ⚠️ 僅升到此＝兩個月後再升 |
| 7.2.x（本專案） | 已結束 | **已結束（2026-08-09）** | ❌ 完全 EOL |
| ≤7.1 | — | — | ❌ 完全 EOL |

## 本專案受影響面初盤

- **Gemfile**：`rails ~> 7.2.2` → `~> 8.1.3`；其餘 gem（pg、puma、importmap/turbo/stimulus、rqrcode、rack-attack、tailwindcss-rails、bcrypt、sprockets-rails、sassc-rails）皆為活躍維護、預期相容（bundle update 時驗證）。
- **config**：`load_defaults 7.2` → 逐步 8.0 → 8.1；`app:update` 產生的 new_framework_defaults 逐項審閱（本專案自訂點：`assume_ssl`、`ALLOWED_HOSTS`＋`/up` 豁免、Taipei 時區、css_compressor nil——最後一項若換 dartsass 可移除）。
- **schema.rb**：8.1 起欄位字母排序——升級後 `db:migrate` 會產生一次大而無害的 schema diff。
- **測試安全網**：222 integration＋13 system＋M0 計分黃金值（升級全程不得改其字面量）。
- **enum**：已是新語法，無虞。無 ActiveStorage/ActionCable/ActionMailbox 實際使用，升級面小。
- **資產管線**（若併入換裝）：sassc-rails → dartsass-rails（沿用 sprockets）；`site.scss`/`boss.scss` 語法為一般 CSS＋巢狀，dart-sass 相容性風險低；`config.assets.css_compressor = nil` workaround 屆時可望移除（dart-sass 輸出不再經 libsass 壓縮——實作時驗證）。

## 建議實作批次

1. **B1：7.2 → 8.0.5.1**（Gemfile、bundle update、app:update 逐檔審閱、deprecation 清零、全測試綠＋M0 不變）
2. **B2：8.0 → 8.1.3.1**（同流程＋接受 schema 排序 diff）
3. **B3（可選但建議）：sassc-rails → dartsass-rails**（獨立 commit，失敗可退）
4. 全程一個 PR、三個 commit；verifier 總驗收（含 production boot、assets:precompile、demo 全鏈 curl）後合併——自動部署上線。

---

## 實作附錄（2026-09-02 完成）

升級已完成並落地為三個 commit，全程未修改 M0 計分黃金值測試
（`test/integration/game/scoring_golden_test.rb`，MD5 前後皆為
`b5f9bf50204b0b7f74d063c26734d602`）。

| 批次 | commit | 內容 |
|---|---|---|
| B1 | `chore: 升級 Rails 7.2.2.1 至 8.0.5.1` | Gemfile、app:update 逐檔取捨、`load_defaults 8.0` |
| B2 | `chore: 升級 Rails 8.0.5.1 至 8.1.3.1` | 同流程、`load_defaults 8.1`、schema 字母排序重排 |
| B3 | `feat: 以 dartsass-rails 取代 EOL 的 sassc-rails` | CSS 編譯器換裝、移除 css_compressor workaround |

### app:update 的通則：範本會覆蓋自訂設定，每一批都要重做一次

`app:update` 在 B1 與 B2 都把下列自訂設定整段刪掉或註解掉，兩批都必須手動復原
（B2 甚至把 `assume_ssl`／`force_ssl` 兩行一起註解掉——若沒發現，production
會退回無 TLS 假設的狀態）：

- `config/application.rb`：Taipei 時區
- `config/environments/production.rb`：`assume_ssl`／`force_ssl`、
  `ALLOWED_HOSTS` 與 `/up` 的 host authorization 豁免、`assets.compile = false`
- `config/environments/development.rb`：sprockets 的
  `assets.quiet`／`assets.debug`／`assets.compile`
- `bin/brakeman`（範本會把移除過的 `--ensure-latest` 加回來）、
  `bin/dev`（範本改成直接 exec rails server，會廢掉 Procfile.dev）

**Rails 8 範本假設 Propshaft**，所以凡是 sprockets 專屬的設定（上面
`assets.*` 那幾項）範本都不會有，升級時要自己補回去，不能當成「範本刪掉了
表示不需要」。另外每批 `app:update` 都會重新複製三個 ActiveStorage
migration，本專案沒有相關資料表，兩批都需刪除。

### 8.1 的 schema.rb 重排

除了預期的欄位字母排序外，實際還有兩處差異（已逐行比對確認無欄位增刪）：
`ActiveRecord::Schema[7.2]` → `[8.1]`，以及 `enable_extension "plpgsql"` →
`"pg_catalog.plpgsql"`（8.1 改為輸出 schema 限定的擴充名稱）。

### dartsass 換裝：唯一的實質不相容是 `asset-url()`

兩份 scss 的語法 dart-sass 完全吃得下，沒有任何語法錯誤。真正的坑是
**dart-sass 沒有 sprockets 的 `asset-url()` helper**——它不會報錯，而是把
`asset-url("bg.jpg")` 當成未知的 CSS 函式原樣輸出，瀏覽器解不開，背景圖靜默
消失。3 處引用改為 CSS custom property（`--site-bg-image`／`--boss-bg-image`），
由 layout 與 Boss 頁 `yield :head` 用 `image_path` 注入帶 digest 的網址，
兼顧 dart-sass 與資產指紋。

連帶處理：`app/assets/config/manifest.js` 移除 `link_directory ../stylesheets .css`
（否則 sprockets 會試圖自己編 scss 而找不到 sassc）；刪除沒有任何地方引用、
且 `require_tree .` 會把 scss 拉進 sprockets 的 `app/assets/stylesheets/application.css`；
`Procfile.dev` 補上 `dartsass:watch`。

`config.assets.css_compressor = nil` 的 workaround 已移除並實測：libsass 不再
參與，production precompile 後 `tailwind.css` 的 digest 與移除前完全相同，
確認沒有壓縮器介入。

### 一個與 Rails 無關、但會污染輸出的坑

`dartsass:build` 會 `system()` 出一個新的 Ruby 行程，於是 `Gemfile.lock` 的
`BUNDLED WITH`（原為 2.5.16）與實際執行的 bundler（2.7.2）版本不一致就會在
每次測試輸出裡噴 8 對 `already initialized constant Gem::Platform::*` 警告。
把 `BUNDLED WITH` 對齊為 2.7.2 即可清零。注意 `bundle update --bundler` 會直接
跳到當時最新的 bundler 4.0.19（major 版本，Dockerfile 有 `BUNDLE_DEPLOYMENT=1`，
風險高），不要照單全收，手動寫回實際在跑的版本比較安全。
