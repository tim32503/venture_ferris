# 部署主機定價與規格查證（2026-08 現況）

> 查證目的：為 Rails 7.2 作品集（Kamal 部署、單機 app + PostgreSQL、觀眾在台灣、月流量極低）挑選固定月費 VPS。
> 查閱日期：2026-08-30 ～ 2026-08-31。資料來源優先序：官方定價/文件頁 > 官方部落格 > 第三方彙整站（僅作交叉參考，已於內文標註）。
> 幣別與稅務：Hetzner 官網預設顯示「未稅」（excl. VAT）；其餘美系廠商（Vultr/Linode/DO/Render/Fly）官網價格皆為稅前，實際扣款是否加稅依帳單地址而定，本文未逐一查證。

---

## 結論摘要

1. **Hetzner 已有亞洲機房（新加坡，2024 年起）**——推翻「只有歐美」的舊認知，但新加坡機房**不提供最低階 CX 系列**，只有 CPX／CCX，且新加坡含量流量遠低於歐洲（0.5–5TB vs 20TB）、超量費率也不同（US$8.49/TB）。從台灣連新加坡延遲低，是候選之一，但不是「查到最低價 CX22 €3.79」就能套用到新加坡。
2. **Vultr 東京（nrt）**目前官方 API 可查到的最低方案是 Regular Cloud Compute `vc2-1c-1gb`：1 vCPU / 1GB RAM / 25GB SSD / 含 1TB 流量，**US$5/月**；有 IPv6-only 更便宜方案但東京不提供。超量費率 US$0.01/GB，**不斷線只加收費**。
3. **Linode/Akamai** 最低階 Shared CPU（Nanode）1 vCPU/1GB/25GB，**US$5/月**，東京、大阪皆有；超量約 US$0.005/GB（US$5/TB），**不斷線只加收費**。
4. **DigitalOcean 新加坡（SGP1）**最低 Basic Droplet 512MiB/1vCPU/10GB，**US$4/月**，含 500GiB 流量，全區域同價無新加坡加價；超量 US$0.01/GiB，**不斷線只加收費**。
5. **Render**：付費 Web Service 最低 Starter US$7/月（0.5vCPU/512MB，常駐不休眠）；免費層 15 分鐘無流量即休眠、喚醒約 1 分鐘。免費 PostgreSQL 30 天到期＋14 天寬限後**直接刪除資料**；付費 Postgres 最低約 US$6/月起（256MB）。2026/4 起 Hobby（免費）workspace **無月費底價**，只算用量，這點對「固定費用」情境是利多。
6. **Fly.io**：2024/10/7 起**新用戶已無免費額度**（僅剩 7 天或 2 VM-hours 試用）。最小機器（256MB shared-cpu-1x）約 US$2/月起，但要接 Postgres 就要另外付費——官方 Managed Postgres 最低 Basic US$38/月（相對貴），若自架 Postgres on Machine 則另計 volume（US$0.15/GB/月）。Auto-stop 機制仍在且預設開啟，**停止狀態不計 CPU/RAM 費用**，但這代表「固定月費」不成立，帳單會隨流量/用量浮動。
7. **Kamal 官方文件完全沒寫最低 RAM**；只有社群共識（多篇部落格）建議 1GB 是底線、2GB 較舒適，因為 Docker image build 在低記憶體時會吃 swap。kamal-proxy 官方 README 只明確要求 **443 port 需開放**（未提 80，可能走 TLS-ALPN-01），且需設定 `host`（即需一個能解析到伺服器的網域，隱含需要 DNS A record，但文件未逐字寫「A record」三個字）。
8. **超量計費行為**：Hetzner／Vultr／DigitalOcean／Linode 官方文件都明確寫「超量只加收費，不斷線不降速」——這支持「小 VPS 流量爆量不會被斷線，只是帳單變高」的說法，**但帳單本身不是固定的**，跟「固定月費」的訴求有出入，需另外設定監控/告警或選有月流量上限保護的方案。Render／Fly 是用量制平台，本來就沒有「固定月費」這回事，只有 Render 免費層文件提到「異常高流量可能被暫停服務」。

**針對「台灣觀眾、固定費用、Kamal 單機」情境的排序建議**：
1. **DigitalOcean 新加坡 US$4/月**（512MB）太小，建議選 2GB 檔位（約 US$18/月，未逐一查證此檔位確切數字，見下表）以確保 Kamal build 順暢；地緣近、生態成熟、文件多。
2. **Vultr 東京 US$5–6/月**（1GB）規格相近、東京延遲對台灣友善，是 DO 的有力替代。
3. **Linode/Akamai 東京/大阪 US$5/月**（1GB）第三選擇，價格相同但生態工具略少。
4. **Hetzner 新加坡**：CP/性能比佳，但最低檔規格與確切月費本次查證中**查無**（官方頁為動態計價元件，需登入/選幣別才顯示數字），且流量比其他家保守，需再次確認實際數字後再決定。
5. **Render／Fly.io**：不建議作為「固定月費」首選——Render 免費層會休眠不適合展示型作品集之外的常駐需求，付費最低約 US$13/月（Web US$7 + Postgres US$6）但仍是用量制平台的思維；Fly.io 靠 Managed Postgres 最低就要 US$38/月，用自架 Postgres 便宜但要自己顧備份/HA，且非固定月費。

---

## 逐家細節

### 1. Hetzner Cloud

| 項目 | 內容 | 來源 |
|---|---|---|
| 歐洲（德國/芬蘭）最低階共享 vCPU | CX22：2 vCPU、4GB RAM、40GB 硬碟，**€3.79/月**（€0.0060/hr，未稅） | [Hetzner Pressroom: New CX plans](https://www.hetzner.com/pressroom/new-cx-plans/)（官方新聞稿，2026-08-31 查閱） |
| 歐洲含流量 | 20TB／月 | 同上 |
| ARM 系列 | CAX11：2 vCPU (Ampere)、4GB RAM、40GB NVMe，僅 Nuremberg/Helsinki 提供；**確切月費本次查無**（官方頁為 JS 動態計價元件，價格欄位空白） | [Hetzner Cost-Optimized](https://www.hetzner.com/cloud/cost-optimized/)（2026-08-31 查閱，頁面本身承認「無法顯示價格」） |
| **亞洲機房** | **新加坡，自 2024 年起提供**——推翻舊認知的「只有歐美」 | 官方頁原文：「Since 2024, we have also been represented in Asia and provide cloud instances in Singapore.」[hetzner.com/cloud/](https://www.hetzner.com/cloud/)（2026-08-31 查閱） |
| 新加坡最低階方案 | **CX 系列在新加坡不提供**，只有 CCX、CPX；最低為 CPX12：1 vCPU、2GB RAM、40GB 硬碟。**確切月費查無**（動態計價元件未顯示數字） | [Hetzner Cloud Singapore](https://www.hetzner.com/cloud-singapore/)（2026-08-31 查閱）；不提供 CX 一事另見 [Hetzner Docs: Price Adjustment 2026-06-15](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/) |
| 新加坡含流量 | 依方案 0.5TB–5TB／月（遠低於歐洲 20TB） | 官方頁原文：「Our included traffic depends on the cloud plan and varies from 0.5 TB to 5 TB of outbound traffic per month.」[Hetzner Cloud Singapore](https://www.hetzner.com/cloud-singapore/) |
| 新加坡超量費率 | US$8.49／TB | 官方頁原文：「Beyond that, additional traffic is billed at $8.49 per TB.」同上 |
| 超量計費行為（全域） | **不斷線、不降速，只依 100MB 為單位累計加收費用** | 官方文件原文：「If you exceed the traffic included in your package, we will bill you for the over-usage in blocks of 100MB.」「these notifications... do not cap or stop it.」[Hetzner Docs: Billing FAQ](https://docs.hetzner.com/cloud/billing/faq/) |
| VAT | 官網標準顯示為未稅價；德國/歐盟客戶另计入加值稅（本文未逐一查證各國稅率，屬推論） | 綜合 WebSearch 結果，非直接官方引文，標記為**推論** |

**查無**：Hetzner 新加坡與 ARM CAX 系列的確切歐元/美元月費——官方定價頁是 JS 動態渲染的計價元件（依登入帳號的幣別/地區顯示），本次以無登入狀態的靜態擷取無法取得數字。第三方彙整站（如 whtop.com、costgoat.com）顯示舊版 CPX11（改版前規格）約 €4.49–5.99，但已不是目前 CPX12 規格，**不可直接引用**。

### 2. Vultr 東京

| 項目 | 內容 | 來源 |
|---|---|---|
| 最低階 Regular Cloud Compute（東京可選） | `vc2-1c-1gb`：1 vCPU、1024MB RAM、25GB SSD、含 1024GB（1TB）流量，**US$5.00/月** | Vultr 官方公開 API `GET https://api.vultr.com/v2/plans`（2026-08-31 直接查詢；此 plan 的 `locations` 陣列含 `nrt`） |
| 東京不提供的更低價方案 | US$2.50（IPv6-only，僅 sea/fra/mia）與 US$3.50（僅 ewr）兩檔**東京都不提供** | 同上 API 回應 |
| High Frequency / High Performance 最低階（東京可選） | `vhf-1c-1gb` 或 `vhp-1c-1gb-amd/intel`：1 vCPU、1024MB RAM、25–32GB 硬碟，含 1024–2048GB 流量，**US$6.00/月** | 同上 API |
| 超量費率 | US$0.01／GB | [Vultr Docs: What Is the Bandwidth Overage Rate?](https://docs.vultr.com/support/platform/billing/what-is-the-bandwidth-overage-rate)（官方文件原文：「Bandwidth usage exceeding your plan's allocated quota is billed at an overage rate of $0.01 per GB.」） |
| 超量計費行為 | 文件未提及斷線或降速，僅描述額外計費 | 同上 |
| 帳戶級流量池 | 官方部落格宣布全帳號流量池化＋每月 2TB 免費流量（此為疊加規則，非取代單機方案內建流量；發布年份**查無**，需注意可能是舊聞） | [Vultr Blog: Reduced Bandwidth Pricing](https://blogs.vultr.com/Vultr-Announces-Reduced-Bandwidth-Pricing-2-Tb-Of-Free-Monthly-Egress-Free-Ingress-And-Global-Pooling) |

### 3. Linode / Akamai 東京・大阪

| 項目 | 內容 | 來源 |
|---|---|---|
| 最低階 Shared CPU（Nanode） | 1 vCPU、1GB RAM、25GB SSD，**US$5/月起** | [Akamai TechDocs: Shared CPU Compute Instances](https://techdocs.akamai.com/cloud-computing/docs/shared-cpu-compute-instances)（官方文件，2026-08-31 查閱） |
| 東京／大阪可用性 | Shared CPU Linode 在「所有 core compute regions」提供，Osaka、Tokyo、Singapore 均列在服務區域中 | 同上；區域清單見 [Akamai TechDocs: Plans](https://techdocs.akamai.com/cloud-computing/docs/plans-distributed) |
| 含流量額度（Nanode 精確數字） | **查無**——官方文件僅說「依方案家族與大小，介於 0–20TB／月」，要求查價格頁或 Cloud Manager 取得精確值，本次未能取得 Nanode 專屬數字 | [Akamai TechDocs: Network Transfer Usage and Costs](https://techdocs.akamai.com/cloud-computing/docs/network-transfer-usage-and-costs) |
| 超量費率 | 一般起價 US$0.005/GB（US$5/TB）；Jakarta US$0.015/GB、São Paulo US$0.007/GB、分散式資料中心 US$0.01/GB 等區域例外 | 同上（官方文件原文摘述） |
| 超量計費行為 | 文件未提斷線，僅描述計費週期結束時依超量收費 | 同上 |
| 區域是否加價 | 第三方彙整（非官方逐字引用）指出 Akamai 傾向全球統一定價，本文未能在官方頁找到「東京/大阪不加價」的逐字保證，**標記為推論** | — |

### 4. DigitalOcean 新加坡（SGP1）

| 項目 | 內容 | 來源 |
|---|---|---|
| 最低階 Basic Droplet | 1 vCPU、512MiB RAM、10GiB SSD，**US$4.00/月** | [DigitalOcean: Droplet Pricing](https://www.digitalocean.com/pricing/droplets)（官方定價頁，2026-08-31 查閱） |
| 含流量 | 500GiB／月（進站流量永遠免費） | 同上 |
| 新加坡可用性 | SGP1 提供 Basic／General Purpose／CPU-optimized／Memory-optimized Droplet 及 Managed Databases | 官方部落格 [We're Excited to Announce Our Singapore Datacenter (SGP1)](https://www.digitalocean.com/blog/we-re-excited-to-announce-our-singapore-datacenter-sgp1)；區域服務清單交叉核對第三方彙整站（非逐字官方引用） |
| 全區域同價 | 官方定價頁未按區域列出不同價格，隱含全球統一定價；未見官方逐字聲明「新加坡不加價」，**標記為推論** | [DigitalOcean: Droplet Pricing](https://www.digitalocean.com/pricing/droplets) |
| 超量費率 | US$0.01／GiB | [DigitalOcean Docs: Bandwidth Billing](https://docs.digitalocean.com/platform/billing/bandwidth/)（官方文件原文：「Additional outbound transfer is billed at $0.01 per GiB.」） |
| 超量計費行為 | 文件未提斷線或降速，僅描述額外計費 | 同上 |

### 5. Render

| 項目 | 內容 | 來源 |
|---|---|---|
| 付費 Web Service 最低階 | Starter：0.5 vCPU、512MB RAM，**US$7/月**，常駐不休眠 | 多方第三方彙整交叉一致，惟本次未能從官方 `/pricing` 頁直接擷取到逐字表格（該頁為 JS 前端渲染，WebFetch 僅取得空殼），**標記為次要來源確認、非官方逐字引用** |
| 免費 Web Service 休眠行為 | 15 分鐘無入站流量即休眠，下次請求喚醒約需 1 分鐘 | 官方文件原文：「suspended after 15 minutes without receiving any inbound traffic」「takes about one minute」[Render Docs: Free Tier](https://render.com/docs/free)（2026-08-31 查閱） |
| 免費 Web Service 其他限制 | 每月 750 小時免費額度、檔案系統為 ephemeral（重啟即消失）、無持久磁碟、單一 instance、異常高流量可能被暫停服務 | 同上 |
| 免費 PostgreSQL | 固定 1GB 儲存，**建立後 30 天到期**，到期後有 **14 天寬限期**升級為付費方案，寬限期後**資料庫連同資料一併刪除** | 官方文件原文：「expire 30 days after creation」「grace period of 14 days」「After the grace period, Render deletes the database (along with all of its data).」[Render Docs: Free Tier](https://render.com/docs/free) |
| 付費 PostgreSQL 最低階 | Basic-256mb，約 **US$6/月**起（次要來源確認，官方逐字定價頁本次未能擷取到表格數字） | 交叉多篇第三方彙整站，**標記為次要來源、非官方逐字引用** |
| Workspace 底價 | 2026/4/23 起新方案：**Hobby（免費）workspace 無月費底價**，僅按用量計費；Pro 方案改為 US$25/月固定（取代舊制每人 US$19/月），Scale US$499/月固定 | [Render Docs: New Workspace Plans](https://render.com/docs/new-workspace-plans)、[Render Changelog: Updated plans for Render workspaces](https://render.com/changelog/updated-plans-for-render-workspaces)（官方文件/changelog） |

**查無**：Render 官方 `/pricing` 頁面本次因前端為 JS 動態渲染，WebFetch 只取得導覽列與空殼內容，未能直接引用逐字價格表；上列 Starter US$7 與 Postgres Basic-256mb US$6 為多篇第三方彙整站交叉一致的數字，建議實際下單前用瀏覽器親自確認一次官方頁面。

### 6. Fly.io

| 項目 | 內容 | 來源 |
|---|---|---|
| 免費額度現況 | **2024/10/7 起，新用戶已無常態免費額度**，僅剩「7 天或 2 VM-hours（以先到者為準）」的試用；舊制 Hobby/Launch/Scale 方案（含 3 台 shared-cpu-1x 256MB、3GB 儲存、區域出站流量額度）只保留給申辦於截止日前的既有帳戶 | 官方文件原文：「Fly.io no longer offers plans to new customers」（effective 2024-10-07）[Fly Docs: Discontinued Plans](https://fly.io/docs/about/discontinued-plans/)（2026-08-31 查閱） |
| 最小 Machine 月費（24/7 常駐） | shared-cpu-1x、256MB RAM，約 **US$2.02/月**（以阿姆斯特丹為例，價格依區域略有差異）；同規格 1GB RAM 約 US$5.92/月 | [Fly Docs: Pricing](https://fly.io/docs/about/pricing/)（官方定價頁） |
| Volume 儲存 | US$0.15／GB／月（provisioned capacity）；快照 US$0.08/GB/月，每月前 10GB 快照免費 | 同上 |
| Managed Postgres（MPG）最低階 | Basic：Shared-2x CPU、1GB 記憶體，**US$38.00/月**；儲存另計 US$0.28/provisioned GB（30 天月） | [Fly Docs: Managed Postgres](https://fly.io/docs/mpg/)（官方文件） |
| 自架 Fly Postgres（非 Managed） | 費用僅為底層 Machine ＋ Volume 費用加總（無額外服務費），但需自行處理備份/HA | [Fly Docs: Pricing](https://fly.io/docs/about/pricing/) |
| Auto-stop/auto-start 現況 | **仍存在且新 App 預設開啟**（`auto_stop_machines = "stop"`、`auto_start_machines = true`），機器閒置會自動停止、有請求再自動啟動 | [Fly Docs: Autostop/Autostart Machines](https://fly.io/docs/launch/autostop-autostart/)（官方文件，含 `fly.toml` 預設值原文） |
| 停止狀態計費 | **停止／suspended 狀態不計 CPU/RAM 費用**，僅計 Volume 儲存費（例：停止 30 天的 1GB rootfs 收費 US$0.15） | 官方文件原文：「you don't pay for their CPU and RAM when they're in a `stopped` or `suspended` state.」同上；儲存費率見 [Fly Docs: Pricing](https://fly.io/docs/about/pricing/) |

### 7. Kamal 部署最低規格門檻

| 項目 | 內容 | 來源 |
|---|---|---|
| 官方文件是否寫明最低 RAM/CPU | **官方文件未明確寫出**任何最低硬體規格（RAM、CPU、磁碟）——查閱安裝與設定頁皆無此類數字 | [Kamal Docs: Installation](https://kamal-deploy.org/docs/installation/)、[Kamal Docs: Configuration](https://kamal-deploy.org/docs/configuration/)（2026-08-31 查閱，均無規格章節） |
| 官方文件明確要求 | SSH 存取（預設 root，SSH key 驗證）；Kamal 會用 `get.docker.com` 自動安裝 Docker | 同上 |
| 社群共識（非官方，多篇部落格交叉一致） | **1GB RAM 是可行下限，但偏緊**（Docker image build 記憶體密集，2GB 以下容易被推進 swap）；**2GB RAM 較舒適**，官方未背書此數字 | 綜合 [Honeybadger: Deploy a Rails app to a VPS with Kamal](https://www.honeybadger.io/blog/deploy-rails-with-kamal/) 等多篇部落格，**標記為推論／社群共識，非官方文件**。本次未逐篇列出全部來源網址，可另行索取。 |
| kamal-proxy 自動 Let's Encrypt 需求 | 官方原文：「This requires that we are deploying to one server and the host option is set.」「Port 443 must be open for the Let's Encrypt challenge to succeed.」**未逐字提及 port 80** | [GitHub: basecamp/kamal-proxy README](https://github.com/basecamp/kamal-proxy)（官方原始碼儲存庫，2026-08-31 查閱） |
| DNS 需求 | 文件要求設定 `host`（需指向該伺服器的網域），實質上需要一筆能解析到伺服器 IP 的 DNS 紀錄；**文件未逐字使用「A record」一詞**，屬合理推論 | 同上 |

**判讀重點**：kamal-proxy 官方只寫「443 需開放」而未提 80，暗示其 ACME 挑戰走 TLS-ALPN-01（走 443）而非傳統 HTTP-01（走 80）；若你的防火牆只開 443 沒開 80，理論上仍可能簽出憑證，但本次未找到官方文件對挑戰機制類型的直接說明，此為**推論**，建議兩個 port 都開以策安全。

### 8. 各家超量／爆量計費行為總表

| 廠商 | 超量後果 | 費率 | 來源（官方逐字引用） |
|---|---|---|---|
| Hetzner | 不斷線不降速，以 100MB 為單位持續計費 | 新加坡 US$8.49/TB；歐洲費率查無 | [Hetzner Docs: Billing FAQ](https://docs.hetzner.com/cloud/billing/faq/)、[Hetzner Cloud Singapore](https://www.hetzner.com/cloud-singapore/) |
| Vultr | 文件未提斷線/降速，僅描述額外計費 | US$0.01/GB | [Vultr Docs](https://docs.vultr.com/support/platform/billing/what-is-the-bandwidth-overage-rate) |
| Linode/Akamai | 文件未提斷線，計費週期結束時計費 | US$0.005/GB 起（依區域） | [Akamai TechDocs](https://techdocs.akamai.com/cloud-computing/docs/network-transfer-usage-and-costs) |
| DigitalOcean | 文件未提斷線或降速，僅描述額外計費 | US$0.01/GiB | [DigitalOcean Docs](https://docs.digitalocean.com/platform/billing/bandwidth/) |
| Render | 免費層「異常高流量可能被暫停服務」；付費層計費方式**查無**（本次未取得官方逐字說明） | — | [Render Docs: Free Tier](https://render.com/docs/free) |
| Fly.io | 用量制，無「固定額度」概念，超量即照用量計費；停止狀態不計 CPU/RAM | 依資源別計價（見上表） | [Fly Docs: Pricing](https://fly.io/docs/about/pricing/) |

**結論**：Hetzner／Vultr／DigitalOcean／Linode 官方文件都支持「小 VPS 流量爆量＝加收費用，不會被斷線」的說法；但沒有一家承諾「帳單有上限」——真正要「帳單不會爆」，仍需自己在雲端主控台設定用量告警，或選擇本來就用量極低、不太可能觸頂的方案。Render／Fly 是用量制平台，「固定月費」的前提本身就不成立（Fly 尤其明確：停止時不計費、運作中則持續計價）。

---

## 出處清單

- Hetzner Pressroom: New CX plans — https://www.hetzner.com/pressroom/new-cx-plans/
- Hetzner Cloud（首頁，含「Since 2024...Singapore」原文）— https://www.hetzner.com/cloud/
- Hetzner Cloud Singapore — https://www.hetzner.com/cloud-singapore/
- Hetzner Cloud Cost-Optimized (CAX) — https://www.hetzner.com/cloud/cost-optimized/
- Hetzner Docs: Price Adjustment 2026-06-15 — https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/
- Hetzner Docs: Billing FAQ — https://docs.hetzner.com/cloud/billing/faq/
- Vultr Public API: GET /v2/plans — https://api.vultr.com/v2/plans
- Vultr Docs: What Is the Bandwidth Overage Rate? — https://docs.vultr.com/support/platform/billing/what-is-the-bandwidth-overage-rate
- Vultr Blog: Reduced Bandwidth Pricing — https://blogs.vultr.com/Vultr-Announces-Reduced-Bandwidth-Pricing-2-Tb-Of-Free-Monthly-Egress-Free-Ingress-And-Global-Pooling
- Akamai TechDocs: Shared CPU Compute Instances — https://techdocs.akamai.com/cloud-computing/docs/shared-cpu-compute-instances
- Akamai TechDocs: Plans — https://techdocs.akamai.com/cloud-computing/docs/plans-distributed
- Akamai TechDocs: Network Transfer Usage and Costs — https://techdocs.akamai.com/cloud-computing/docs/network-transfer-usage-and-costs
- DigitalOcean: Droplet Pricing — https://www.digitalocean.com/pricing/droplets
- DigitalOcean Docs: Bandwidth Billing — https://docs.digitalocean.com/platform/billing/bandwidth/
- DigitalOcean Blog: Singapore Datacenter (SGP1) — https://www.digitalocean.com/blog/we-re-excited-to-announce-our-singapore-datacenter-sgp1
- Render Docs: Free Tier — https://render.com/docs/free
- Render Docs: New Workspace Plans — https://render.com/docs/new-workspace-plans
- Render Changelog: Updated plans for Render workspaces — https://render.com/changelog/updated-plans-for-render-workspaces
- Fly Docs: Pricing — https://fly.io/docs/about/pricing/
- Fly Docs: Managed Postgres — https://fly.io/docs/mpg/
- Fly Docs: Autostop/Autostart Machines — https://fly.io/docs/launch/autostop-autostart/
- Fly Docs: Discontinued Plans — https://fly.io/docs/about/discontinued-plans/
- Kamal Docs: Installation — https://kamal-deploy.org/docs/installation/
- Kamal Docs: Configuration — https://kamal-deploy.org/docs/configuration/
- GitHub: basecamp/kamal-proxy README — https://github.com/basecamp/kamal-proxy
- （次要來源，僅交叉參考，未逐字引用）Honeybadger Blog: Deploy a Rails app to a VPS with Kamal — https://www.honeybadger.io/blog/deploy-rails-with-kamal/
