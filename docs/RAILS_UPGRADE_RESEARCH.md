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
