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

---

## Hostinger VPS 補充查證

> 查證目的：Hostinger 常被個人開發者提及（自身多有既有 web hosting 帳號），需確認其 VPS（KVM 系列）是否適合本情境（Kamal 單機 app + PostgreSQL、觀眾在台灣、需固定可預測費用）。
> 查閱日期：2026-08-31。官方定價頁為前端 JS 動態渲染（依連線地區/幣別顯示，本次以 WebFetch 取得的靜態擷取為 USD），部分billing-term 切換介面（1/12/24/48 個月分頁）無法用 WebFetch 互動取得，已標註為查無並以次要來源交叉參考。

### 1. VPS（KVM）方案與定價

| 方案 | vCPU | RAM | SSD | 含流量 | 首購顯示價 | 續約價（官方逐字） |
|---|---|---|---|---|---|---|
| KVM 1 | 1 | 4GB | 50GB | 4TB | **US$6.49/mo**（頁面標示「67% off」） | 「Renews at $11.99/mo for 2 years. Cancel anytime.」 |
| KVM 2 | 2 | 8GB | 100GB | 8TB | **US$8.99/mo**（「63% off」，標示 Most Popular） | 「Renews at $14.99/mo for 2 years. Cancel anytime.」 |
| KVM 4 | 4 | 16GB | 200GB | 16TB | **US$12.99/mo**（「70% off」） | 「Renews at $28.99/mo for 2 years. Cancel anytime.」 |
| KVM 8 | 8 | 32GB | 400GB | 32TB | **US$25.99/mo**（「65% off」） | 「Renews at $49.99/mo for 2 years. Cancel anytime.」 |

來源：[Hostinger: VPS Hosting](https://www.hostinger.com/vps-hosting)（官方定價頁，2026-08-31 查閱）。

**首購 vs 續約的關鍵條件（官方逐字）**：「All plans are paid upfront. The monthly rate reflects the total plan price divided by the number of months in your plan.」——即頁面顯示的「/mo」是「總價 ÷ 月數」換算出來的名目月費，**不是月繳金額**，實際是一次預付整個方案週期。續約統一寫「for 2 years」，代表續約仍要求綁 24 個月才拿得到該續約價，並非續約後可改月繳。

**查無**：官方頁本次未能透過 WebFetch 取得「首購方案究竟綁定幾個月」的逐字揭露（頁面用 JS 呈現 1/12/24/48 月的分頁選擇器，靜態擷取只抓到當前預設分頁的價格與「paid upfront」「Renews at ... for 2 years」兩段文字，沒有抓到「48-month term」之類的明確月數字樣）。次要來源（非官方逐字，僅交叉參考）[HostAdvice: Hostinger VPS Pricing Explained](https://hostadvice.com/hosting-company/hostinger-reviews/vps-pricing/) 與 [TradingVPSHub: Hostinger VPS Pricing 2026](https://tradingvpshub.com/hostinger-vps-pricing/) 皆指出：Hostinger 沒有「真正的無綁約月繳」選項，雖列有「monthly」分頁但單月價格是長約月費的 3–5 倍，最低的促銷價通常要求 24 或 48 個月一次付清；不同時間點抓到的 KVM 1 首購價在 US$4.99–6.49/mo 之間浮動（促銷碼與地區會影響顯示價），**這進一步印證「固定可預測費用」的前提在 Hostinger 難以成立**：真正的月繳單月價格本次查無官方逐字數字，但方向上明顯高於長約換算價。

### 2. 機房位置

官方原文（首頁行銷文案）：「We have data centers across North America, Europe, Asia, and South America.」未列出具體城市。經比對官方支援頁逐一查核：

| 項目 | 內容 | 來源 |
|---|---|---|
| VPS 可選機房清單（官方逐字） | 歐洲：France, Germany, Lithuania, United Kingdom；亞洲：**India, Indonesia, Malaysia**；北美：USA (Phoenix, Boston)；南美：Brazil | [Hostinger Support: Where are Hostinger servers located?](https://www.hostinger.com/support/1583267-where-are-hostinger-servers-located/)（官方文件，2026-08-31 查閱） |
| 新加坡／日本 | **VPS 不提供**——官方文件明確排除，原文：「Servers in the Netherlands and USA (Asheville) are not available for VPS, only for web and cloud plans」（同頁另段落排除荷蘭與 Asheville；新加坡與日本則完全未出現在 VPS 清單中，屬清單比對後的排除，非逐字「不提供新加坡」聲明） | 同上 |
| 能否自選機房 | 可在**建立時**選擇機房，但「the server location is fixed after initial setup」，事後若要換機房須「backup and reinstall the VPS on a different data center」（等同重建，非線上遷移） | 同上 |

**對台灣觀眾的意涵**：亞洲僅 India／Indonesia／Malaysia 三選，**沒有日本或新加坡**——這是 Hostinger 相對 Vultr/Linode 東京方案的明顯弱點。地理上最近的是印尼或馬來西亞，但官方查無兩地到台灣的延遲數字；相對於 Vultr/Linode 的東京機房，主觀預期延遲會更高（**推論，未經實測）**。

### 3. 技術適配

| 項目 | 內容 | 來源 |
|---|---|---|
| Root 權限 | 官方原文：「full root access」，可「freely customize the OS, control panel, and software」 | [Hostinger: VPS Hosting](https://www.hostinger.com/vps-hosting) |
| OS／模板限制 | 官方提供一鍵部署多種 Linux 發行版、控制面板（cPanel、CyberPanel、Plesk、DirectAdmin 等，另計費）與應用程式模板；未見官方文件寫出「禁止自訂 ISO」或類似限制字樣 | 同上 |
| Docker 支援 | 官方頁列出 Docker 為可一鍵安裝的應用之一，但這是「模板化安裝」而非官方對「原生支援 Kamal/任意 Docker 用法」的保證；因為有 full root，理論上可自行安裝任意版本 Docker（不依賴模板），**此為推論** | 同上 |
| 防火牆／443/80 控制 | 官方原文：「Built-in firewall management protects your VPS environment」，可設定「firewall rules specific to your IP address」；未見逐字提及可否精細控制個別 port（如僅開 443/80），**細節查無** | 同上 |
| 所謂「AI」VPS 模板 | 官方行銷文案將 **Ollama、n8n、Claude Code、Docker、Grafana、WordPress** 等列為「trending applications」一鍵安裝目錄，另提及「AI agents like OpenClaw and Hermes」可透過應用程式目錄部署；**這些是一鍵安裝的軟體模板／腳本，不是專用 GPU 或加強算力的機型**——KVM 系列規格（vCPU/RAM/SSD）與其他一般用途 VPS 完全相同，Hostinger 沒有另外賣「AI 專用機型」或 GPU 選項。換言之「Hostinger 的 AI VPS」實際指「VPS 上可以一鍵裝 Ollama/n8n 這類 AI 相關軟體」，是行銷包裝而非硬體差異化，這點需在報告中明確澄清避免誤讀 | 同上；GPU 選項查無官方頁面 |
| CPU 使用限制（重要，影響 Kamal build） | 官方原文：「Internal systems identify if a VPS sustains high CPU usage for longer period of time」→ 觸發「Automatic throttling: ... the CPU capacity of the VPS is decreased automatically by 25% per hour」；可在儀表板「remove the CPU limit once per week」以利測試／設定變更；系統會將持續高 CPU 視為「potentially compromised」的訊號之一 | [Hostinger Support: What Is the CPU Use Limit for VPS at Hostinger?](https://www.hostinger.com/support/6899741-what-is-the-cpu-use-limit-for-vps-at-hostinger/)（官方文件，2026-08-31 查閱） |

**判讀重點**：CPU 自動降頻機制是 Hostinger VPS 特有的、Vultr/Linode/DigitalOcean 官方文件都沒有對應的「持續高 CPU 就自動降頻」規則。Docker image build（含 Rails asset precompile）通常會有短暫但強烈的 CPU 尖峰，若建置時間夠長、觸發「sustained」判定（官方未寫明確分鐘數，第三方非官方來源提及約 180 分鐘門檻，**查無官方逐字確認**），理論上可能被降頻 25%/小時，對「單機 Kamal 部署」是需要留意的風險，其他三家基準廠商沒有這個限制。

### 4. 流量與超額行為

| 項目 | 內容 | 來源 |
|---|---|---|
| 超量後果 | **降速，不斷線、不加收費用**：官方原文「the connection speed will be reduced to 10 Mbps for the rest of the month」，且「your websites and services will remain operational」 | [Hostinger Support: What happens if your VPS bandwidth resource limits are exceeded](https://www.hostinger.com/support/8789965-what-happens-if-your-vps-bandwidth-resource-limits-are-exceeded/)（官方文件，2026-08-31 查閱） |
| 重置週期 | 官方原文：「At the beginning of the next month, your monthly bandwidth allocation will be reset to its original value, and your connection speed will return to its normal level.」 | 同上 |
| 與基準廠商比較 | Vultr/Linode/DigitalOcean/Hetzner 都是「超量加收費用、不斷線不降速」；**Hostinger 是唯一一家用「降速到 10Mbps」處理超量**的廠商——對「固定月費」訴求反而更有利（不會因流量暴衝而爆帳單），但代價是流量用盡當月效能會明顯下降 | 綜合上表與本文件第 8 節既有比較 |

### 5. 口碑面（次要來源，非官方，僅交叉參考）

| 面向 | 摘要 | 來源 |
|---|---|---|
| 效能/穩定性 | 評價分歧：部分評測認為速度與正常運行時間尚可；也有評測提到伺服器更新造成的中斷與頻繁維護窗口 | [WebsitePlanet: Hostinger VPS Review 2026](https://www.websiteplanet.com/blog/hostinger-vps-review/) |
| 超賣疑慮 | 有評測指出 VPS 超賣是潛在問題，並舉例 KVM 8（8 vCPU/32GB）在全新安裝 AlmaLinux 時就因 CPU 限制過緊而跑不動，暗示廣告規格與實際可用算力有落差 | 綜合多篇第三方評測（未逐字引用，來源含 hostadvice.com、onlinemediamasters.com） |
| 客服品質 | 有評測提到帳號因不實釣魚檢舉被停權、且客服拒絕還原備份/退款；另有「除非加購第三方 email 行銷服務否則不解除停權」的爭議說法；也有評測提到缺乏電話客服，僅有線上客服與 email，可能造成延遲 | [OnlineMediaMasters: Hostinger Review 2026 — Watch out for Suspension Scams!](https://onlinemediamasters.com/hostinger-review/) |
| 與 Vultr/Linode 相比的常見評語 | 第三方普遍評語：Hostinger 主打「便宜好上手」，Vultr/Linode 則被認為更「開發者導向、規格透明、客服與方案彈性較穩定」；此比較屬多篇評測的共同印象整理，**非逐字引用單一來源** | 綜合 hostadvice.com、tooltester.com、bearhost.com 等多篇評測 |

**判讀重點**：以上皆為第三方評測意見，非 Hostinger／Vultr／Linode 官方立場，僅供風險參考，不作為定價或技術規格依據。

### 6. 使用者情境加分：既有 web hosting 帳號的綑綁

| 項目 | 內容 | 來源 |
|---|---|---|
| 控制面板整合 | Hostinger 的 VPS 與 web hosting 共用同一套 **hPanel**，可在同一登入下管理網域、檔案、備份、應用程式安裝，屬真實的介面統一（非折扣），有既有帳號者可直接在既有 hPanel 內開通 VPS | 綜合官方頁與第三方彙整（hPanel 為 Hostinger 全產品線共通面板，非本次查到單一逐字官方聲明片段，**標記為推論**，但可信度高——官方 VPS 頁面本身即多處提及 hPanel 管理功能） |
| 續約/新購折扣是否因「既有帳號」而不同 | **查無**——本次查證未找到官方文件承諾「既有 web hosting 客戶購 VPS 有專屬綁定折扣」；市面上的折扣碼（最高標榜到 90% off）對新舊客戶適用範圍不一，部分優惠碼明確排除續約與綑綁購買，本次未見官方逐字保證既有帳號有加碼優惠 | 綜合 [Hostinger Coupons](https://www.hostinger.com/coupons) 與第三方比價站，**非官方逐字引用** |

**結論**：既有 Hostinger 帳號的加分主要是**操作介面統一**（同一 hPanel 管理網域＋VPS），而非查證到「額外價格折扣」；此加分對「決定要不要用 Hostinger VPS」的權重應偏低，不宜作為主要決策因素。

### 7. 與 Vultr/Linode 東京基準比較表

| 項目 | Vultr 東京 `vc2-1c-1gb` | Linode 東京/大阪 Nanode | Hostinger KVM 1 |
|---|---|---|---|
| 規格 | 1 vCPU / 1GB RAM / 25GB SSD | 1 vCPU / 1GB RAM / 25GB SSD | 1 vCPU / **4GB RAM** / 50GB SSD |
| 首月/首購價 | US$5/月（月繳，無綁約） | US$5/月（月繳，無綁約） | US$6.49/月（**需一次預付整個方案週期，非月繳**，確切月數查無） |
| 續約/長期價 | 同 US$5/月（無漲價機制） | 同 US$5/月（無漲價機制） | 續約 **US$11.99/月，且仍綁 2 年** |
| 含流量 | 1TB | 依方案（Nanode 精確數字查無，官方僅給區間） | **4TB** |
| 超量後果 | 加收費用（US$0.01/GB），不斷線不降速 | 加收費用（US$0.005/GB 起），不斷線不降速 | **降速至 10Mbps**，不斷線不加收費 |
| 亞洲機房（近台灣） | 東京 | 東京、大阪 | 印度／印尼／馬來西亞（**無日本、無新加坡**） |
| 帳單可預測性 | 高——月繳、無合約期、無漲價 | 高——月繳、無合約期、無漲價 | **低**——名目「/mo」是預付總價換算值，真正月繳價格明顯更高，且續約仍綁 2 年、續約價比首購價漲近一倍 |
| CPU 特殊限制 | 官方文件查無「持續高 CPU 自動降頻」規則 | 同左 | 官方明文：持續高 CPU 會被**每小時自動降頻 25%** |

### 結論：是否適合本情境

**不建議將 Hostinger VPS 作為本專案（Kamal 單機 app + PostgreSQL、觀眾在台灣、需固定可預測費用）的首選**，理由：

1. **「固定可預測費用」的前提不成立**：Hostinger 官方明文「paid upfront」，頁面「/mo」只是總價換算值，不是可月繳的金額；真正的月繳單月價格官方查無但方向上明顯偏高，且續約仍強制綁 2 年、續約價比首購價幾乎翻倍——這與 Vultr/Linode「月繳、無合約、價格不隨時間變動」的模式本質不同，行政與現金流複雜度更高。
2. **機房位置對台灣觀眾不利**：VPS 僅提供 India/Indonesia/Malaysia，**沒有日本或新加坡**，地理與網路延遲上明顯遜於 Vultr/Linode 的東京機房。
3. **CPU 自動降頻機制是額外風險**：其他三家基準廠商都沒有「持續高 CPU 自動降頻 25%/小時」的規則，而 Kamal/Docker build 本身就是 CPU 尖峰操作，長時間或頻繁部署有被降頻的疑慮（官方未寫明確觸發門檻，需自行實測）。
4. 唯一相對優勢是**規格性價比**（KVM 1 首購價 4GB RAM/50GB SSD/4TB 流量，規格帳面上優於 Vultr/Linode 同價位的 1GB RAM 方案）與**超量降速而非加收費用**（對「怕帳單暴衝」的疑慮更友善）；但前兩項優勢建立在「首購促銷價」之上，一旦進入續約期（2 年合約、價格翻倍），性價比優勢大幅降低。
5. 若使用者已有 Hostinger web hosting 帳號，主要加分是**同一 hPanel 管理介面**帶來的操作便利，而非額外價格優惠（本次查無此類折扣的官方證據），不足以扭轉上述 1–3 點的結論。

**建議**：維持既有結論摘要中的排序（DigitalOcean 新加坡／Vultr 東京／Linode 東京為前三選），Hostinger VPS 僅在使用者能接受「一次預付較長合約期換取較低月費、且能容忍延遲較高的東南亞機房」的前提下，作為次要備選。

---

## Hostinger VPS 補充查證出處清單

- Hostinger: VPS Hosting（定價頁）— https://www.hostinger.com/vps-hosting
- Hostinger Support: Where are Hostinger servers located? — https://www.hostinger.com/support/1583267-where-are-hostinger-servers-located/
- Hostinger Support: What happens if your VPS bandwidth resource limits are exceeded — https://www.hostinger.com/support/8789965-what-happens-if-your-vps-bandwidth-resource-limits-are-exceeded/
- Hostinger Support: What Is the CPU Use Limit for VPS at Hostinger? — https://www.hostinger.com/support/6899741-what-is-the-cpu-use-limit-for-vps-at-hostinger/
- Hostinger Coupons — https://www.hostinger.com/coupons
- （次要來源，僅交叉參考，未逐字引用）HostAdvice: Hostinger VPS Pricing Explained — https://hostadvice.com/hosting-company/hostinger-reviews/vps-pricing/
- （次要來源，僅交叉參考，未逐字引用）TradingVPSHub: Hostinger VPS Pricing 2026 — https://tradingvpshub.com/hostinger-vps-pricing/
- （次要來源，僅交叉參考，未逐字引用）WebsitePlanet: Hostinger VPS Review 2026 — https://www.websiteplanet.com/blog/hostinger-vps-review/
- （次要來源，僅交叉參考，未逐字引用）OnlineMediaMasters: Hostinger Review 2026 — https://onlinemediamasters.com/hostinger-review/

---

## Fly.io 深度查證

> 查證動機：使用者在 Fly.io 現況為 Personal organization、Pay As You Go 方案，且**近期帳單都被 100% 減免**。本節查證此減免背後的官方機制，並補齊 machine/volume/流量/PostgreSQL/機房/費用控制/冷啟動等定價細節，供本專案（Kamal 風格單機 app + PostgreSQL、觀眾在台灣、流量極低且間歇）精確試算月費，與既有結論摘要第 6 點的初步結論互相印證、補強。
> 查閱日期：2026-09-01。幣別：美元 USD，官網未稅前價格；實際扣款是否加稅依帳單地址而定，本節未逐一查證。本節與既有章節體例一致，官方逐字/推論/查無分開標註；本節不修改文件其他既有章節文字。

### 1. 小額帳單豁免政策（使用者「100% 減免」的最可能解釋）

| 項目 | 內容 | 來源 |
|---|---|---|
| 機制本身（官方員工說明） | Fly.io 工程師 **Kurt**（Fly.io 官方帳號）在社群論壇原文：「We shipped a change a few months ago to waive invoices under $5. We haven't had any reason to disable it yet, it seems to be useful.」並說明動機：「A surprising number of people pay <$5 by accident and charging them creates a negative experience. And, the reality is we make money off bigger spenders.」 | [Fly.io Community: questions on 100% billing discount](https://community.fly.io/t/questions-on-100-billing-discount/11133)（Fly.io 員工於社群論壇的說明，**非正式定價/帳單文件頁逐字**，原討論串時間點約在 2022–2023 年舊方案時期，2026-09-01 查閱） |
| 現行正式文件是否重申 | **查無**——本次查閱 [Fly.io Docs: Resource Pricing](https://fly.io/docs/about/pricing/)、[Fly.io Docs: Billing](https://fly.io/docs/about/billing/)、[Fly.io Docs: Cost Management](https://fly.io/docs/about/cost-management/) 三份現行官方文件，**均未見「$5」門檻或「waive」字樣的逐字重申**，「Cost Management」頁反而只教你自己盯 dashboard，未提及自動減免。 | 同上三份官方文件（2026-09-01 查閱） |
| 2024/10 新方案後是否仍生效 | **查無官方書面覆核**——2024 年 10 月 Fly.io 取消 Hobby/Launch/Scale 免費方案、改為純 Pay As You Go 後，社群多次追問此政策是否還在（[Does Fly.io still waves <$5 invoices?](https://community.fly.io/t/does-fly-io-still-waves-5-invoices/25651)、[Is there still a policy on waiving invoices less than $5?](https://community.fly.io/t/is-there-still-a-policy-on-waiving-invoices-less-than-5-after-the-changes-in-october-2024/23560)），兩串討論**都只有其他使用者猜測、無 Fly.io 員工正式回覆**，官方建議是寫信到 billing@fly.io 詢問。 | 同上兩則社群討論串（2026-09-01 查閱） |
| 對使用者現況的推論 | 使用者近期帳單持續被 100% 減免，與 Kurt 描述的「invoices under $5 自動 waive」機制**完全吻合**，且 Fly.io 從未發出撤回此政策的公告——**推論**：此政策 2026 年 9 月當下大機率仍在運作，是使用者帳單被 100% 減免的最可能官方機制；但因缺乏 2024/10 後的官方書面重新確認，不能標記為「現行官方逐字保證」，只能標記為「舊官方員工說明 + 使用者實測結果互相印證」。 | 綜合上列三項 |

### 2. Machine 計價（shared-cpu-1x）

| RAM 檔位 | 每秒價格（Amsterdam 基準） | 每月價格（Amsterdam 基準，30 天換算） | 每秒價格（nrt 東京） | 每月價格（nrt 東京） |
|---|---|---|---|---|
| 256MB | $0.00000078 | $2.02 | $0.00000095 | $2.47 |
| 512MB | $0.00000128 | $3.32 | $0.00000156 | $4.05 |
| 1GB | $0.00000228 | $5.92 | $0.00000279 | $7.23 |
| 2GB | $0.00000429 | $11.11 | $0.00000524 | $13.58 |

官方逐字確認，來源：[Fly.io Docs: Resource Pricing](https://fly.io/docs/about/pricing/)（2026-09-01 查閱）。nrt 相對 Amsterdam 基準約貴 **22%**（區域加價倍率，官方頁面以 JS 動態渲染各區倍率表，未能擷取到通用倍率公式的逐字文字，但各區實際數字本身是官方逐字）。

| 項目 | 內容 | 來源 |
|---|---|---|
| Stopped/suspended 機器計費 | 官方原文：「Each 1GB of rootfs for a Machine stopped for 30 days is $0.15.」——即**只收 rootfs（機器本身磁碟）儲存費**，不收 CPU/RAM 費用；停止未滿 30 天按比例攤提（例：1GB rootfs 停止 10 天約 $0.05） | [Fly.io Docs: Billing](https://fly.io/docs/about/billing/)（官方逐字，2026-09-01 查閱） |
| Suspended 與 stopped 的計費差異 | 官方原文：「Suspended machines cost the same as stopped machines: storage only. There are no CPU/RAM charges.」但「Suspending a machine lowers your costs, but it does not free capacity in a region. Suspended machines still reserve their resources.」（即計費相同，但底層資源保留方式不同） | [Fly.io Docs: Machine Suspend and Resume](https://fly.io/docs/reference/suspend-resume/)（官方逐字，2026-09-01 查閱） |
| Volume 在 stopped 狀態下 | 官方原文：「If a suspended machine has a volume, you continue paying for the volume for as long as it exists」——**Volume 費用與機器運轉狀態無關，只要 volume 存在就持續計費** | 同上 |
| Auto-stop/auto-start 計費行為 | 官方原文：「Use autostop/autostart to automatically start and stop or suspend existing Machines based on incoming requests.」且「you don't pay for their CPU and RAM when they're in a stopped or suspended state.」代理層行為：「The Fly Proxy's stop loop runs every few minutes and stops at most one Machine per region per pass.」 | [Fly.io Docs: Autostop/autostart Machines](https://fly.io/docs/launch/autostop-autostart/)（官方逐字，2026-09-01 查閱） |

**判讀重點**：Auto-stop 生效後，機器實際「運轉中」的秒數才計 CPU/RAM 費，這是 Fly.io 對「流量極低且間歇」情境最有利的機制；但 Fly Proxy 的 stop loop 是「每幾分鐘掃一次、每次每區最多停一台」，代表機器不會在請求結束的瞬間立刻停止，會有數分鐘的閒置尾巴，試算時需計入（本文件試算表為簡化計算，未逐分鐘模擬這個尾巴，可能使數字略低於實際帳單）。

### 3. Volume

| 項目 | 內容 | 來源 |
|---|---|---|
| 月費 | 官方原文：「$0.15/GB per month of provisioned capacity」 | [Fly.io Docs: Resource Pricing](https://fly.io/docs/about/pricing/)（官方逐字，2026-09-01 查閱） |
| 快照月費 | 官方原文：「$0.08/GB per month」，且「First 10GB free each month」——即每月前 10GB 快照容量免費 | 同上 |
| 預設快照保留 | 官方原文：「Automatic daily snapshots with 5 days retention are enabled by default」 | 同上；另於 [Fly.io Docs: This Is Not Managed Postgres](https://fly.io/docs/postgres/getting-started/what-you-should-know/) 頁重申「Fly.io takes daily snapshots of Postgres volumes and saves them for 5 days.」（官方逐字，2026-09-01 查閱） |

### 4. 流量（egress）

| 區域組 | 對外網際網路 egress | 私有跨區傳輸 |
|---|---|---|
| 北美、歐洲 | $0.02/GB | $0.006/GB |
| **亞太、大洋洲、南美** | **$0.04/GB** | $0.015/GB |
| 非洲、印度 | $0.12/GB | $0.050/GB |

官方逐字確認區域組費率，來源：[Fly.io Docs: Resource Pricing](https://fly.io/docs/about/pricing/)（2026-09-01 查閱）；官方原文另註：「Organizations created after July 18 2024 are automatically opted-in to use the granular data transfer rates and are billed at a different rate for private network data transfer between regions.」

| 項目 | 內容 |
|---|---|
| nrt（東京）歸屬哪一組 | **推論**——官方定價頁的費率表以「Asia Pacific / Oceania / South America」等大洲級分組列價，未逐字寫出「nrt」這個機場代碼對應哪一組；但 [Fly.io Docs: Regions Reference](https://fly.io/docs/reference/regions/)（2026-09-01 查閱）確認 nrt＝Tokyo, Japan，地理與慣例上屬亞太，本文件據此推論 nrt 適用 $0.04/GB 這一檔，**非逐字對應表**，如需精確數字建議實際跑一次帳單核對 |
| 免費額度 | 官方原文：「All inbound data transfer」免費；同區域機器間流量對採用新granular費率的組織也免費。**除此之外查無其他固定免費 GB 額度**（不像部分 VPS 廠商有「含 1TB」這種數字） |

### 5. PostgreSQL 選項

**(a) Managed Postgres（MPG）**

| 方案 | CPU | 記憶體 | 月費 |
|---|---|---|---|
| Basic | Shared-2x | 1GB | **$38.00** |
| Starter | Shared-2x | 2GB | $72.00 |
| Launch | Performance-2x | 8GB | $282.00 |
| Scale | Performance-4x | 32GB | $962.00 |
| Performance | Performance-8x | 64GB | $1,922.00 |

官方逐字確認最低檔 Basic $38.00/月（**確認既有結論摘要第 6 點的 $38 數字**），另收儲存費「$0.28 per provisioned GB for a 30-day month」（初始最高可佈建 500GB，總量上限 1TB）；所有方案含「high availability, backups, and connection pooling」。來源：[Fly.io Docs: Managed Postgres Overview](https://fly.io/docs/mpg/overview/)（官方逐字，2026-09-01 查閱）。nrt 東京機房確認支援 MPG（[Regions Reference](https://fly.io/docs/reference/regions/) 表中 nrt 列有 MPG 欄位勾選，官方逐字確認，2026-09-01 查閱）。

**(b) Unmanaged Fly Postgres（`fly postgres create` 自架版）**

| 項目 | 內容 | 來源 |
|---|---|---|
| 是否仍可建立 | 可以，指令與文件仍在，屬「legacy」但未見官方文件寫「即將移除」字樣（**本次查證未找到棄用時程公告，查無**） | [Fly.io Docs: Fly Postgres (Unmanaged)](https://fly.io/docs/postgres/) |
| 官方支援態度 | 官方頁面標題直接就是「**This Is Not Managed Postgres**」，原文：「We are not able to provide support or guidance for unmanaged Postgres.」「Fly Postgres is not a managed database, and if Postgres crashes because it ran out of memory or disk space, you'll need to do a little work to get it back.」並在同頁建議：「We recommend Fly.io Managed Postgres, a production-ready Postgres service that handles the hard parts for you: high availability, automatic failover, encrypted backups, monitoring and metrics, seamless scaling, and 24/7 support...」 | [Fly.io Docs: This Is Not Managed Postgres](https://fly.io/docs/postgres/getting-started/what-you-should-know/)（官方逐字，2026-09-01 查閱） |
| 單節點最小規格（官方預設） | 官方建立精靈的「Development」選項預設為「**1x shared CPU**」「**256MB RAM**」「**1GB disk**」（單節點，非 HA） | [Fly.io Docs: Create a Postgres Cluster](https://fly.io/docs/postgres/getting-started/create-pg-cluster/)（官方逐字，2026-09-01 查閱） |
| 單節點最小規格的成本估計 | 官方定價頁原文估計：「About $2/month for a single node cluster for dev projects and from about $82 to $164/month for a three-node production cluster.」——與上列 256MB 機器（Amsterdam 基準 $2.02/月）+ 1GB volume（$0.15/月）＝約 $2.17/月的推算數字相符 | [Fly.io Docs: Resource Pricing](https://fly.io/docs/about/pricing/)（官方逐字，2026-09-01 查閱） |
| HA / 單節點風險 | 官方原文：「The 'High Availability' options are three-node clusters.」單節點無此保護，若「the hardware it's running on has network problems or the SSD fails, your database will go down.」 | [Fly.io Docs: Fly Postgres (Unmanaged)](https://fly.io/docs/postgres/)（官方逐字，2026-09-01 查閱） |
| 備份機制 | 官方原文：「Fly.io takes daily snapshots of Postgres volumes and saves them for 5 days.」——**確認是靠 volume snapshot**，且明確不含異地備份：「it does not manage off-site backups.」 | [Fly.io Docs: This Is Not Managed Postgres](https://fly.io/docs/postgres/getting-started/what-you-should-know/)（官方逐字，2026-09-01 查閱） |

**(c) 官方對「單機合併部署 app + 資料層」的態度**

| 資料層 | 官方態度 | 來源 |
|---|---|---|
| **SQLite**（app 與資料庫同一台機器） | **官方明確示範、鼓勵這種模式**——Rails 官方指南原文：「this guide assumes you have one node and one volume」，要求把資料庫放進 `fly.toml` 的 `[mounts]` 掛載的 Volume（否則部署會覆蓋資料檔），並提醒限制：「Volumes are limited to one host, this currently means that fly.io hosted Rails applications that use sqlite3 for their database can't be deployed to multiple regions.」官方另有 LiteFS／Litestream 兩套工具支援 SQLite；官方文件明確建議：「you'll typically choose Litestream for single-server deployments and LiteFS for multi-server deployments」 | [Fly.io Docs: SQLite3 (Rails)](https://fly.io/docs/rails/advanced-guides/sqlite3/)、[Fly.io Docs: LiteFS](https://fly.io/docs/litefs/)（官方逐字，2026-09-01 查閱） |
| **PostgreSQL**（app 與 PG 同一台機器/容器） | **查無**——本次查證的所有官方文件（`fly postgres create`、MPG、Rails 官方部署指南）在示範 PostgreSQL 時，一律是把 Postgres 建成**獨立的 Fly app（獨立 machine）**，透過內部私網（`.internal` DNS／`DATABASE_URL`）連到 app machine；**沒有找到官方文件或範例把 Rails app 容器與 Postgres 塞進同一台 machine／同一個容器運行**。這與 SQLite 的官方態度明顯不同：SQLite 官方鼓勵同機部署，PostgreSQL 官方預設一律分機部署 | 綜合上列 Postgres 相關官方文件（2026-09-01 查閱） |

### 6. 東京機房（nrt）價差彙總

| 項目 | 相對北美/歐洲基準的價差 | 官方/推論 |
|---|---|---|
| Machine（shared-cpu-1x 各檔位） | 約貴 **22%**（見第 2 節表格） | 官方逐字（數字本身），倍率計算為本文推算 |
| Egress 流量 | 約貴 **100%**（$0.04/GB vs $0.02/GB） | 官方逐字費率表，nrt 歸屬亞太組屬推論（見第 4 節） |
| MPG 可用性 | nrt 支援 Managed Postgres | 官方逐字（Regions Reference） |

### 7. 費用控制（spending limit / billing alert）

| 項目 | 內容 | 來源 |
|---|---|---|
| 帳單告警 | 官方原文：「We don't support billing alerts (yet), so budget accordingly.」——**官方確認目前沒有**帳單告警/通知功能 | [Fly.io Docs: Cost Management](https://fly.io/docs/about/cost-management/)（官方逐字，2026-09-01 查閱） |
| 支出上限 | 官方文件**未提供**任何「spending limit」或「billing cap」設定項；官方建議的替代做法是「Check your dashboard often. To spot ballooning costs and overages before they become an issue, check the 'current month to date bill' item in your dashboard.」 | 同上 |
| 間接的支出控制手段 | 官方支援**預付信用額度（prepaid credits，最低 $25）**，額度用盡帳號會被限制，等同於一種手動式的支出上限；但這不是自動告警，是「用完即卡住」的機制 | [Fly.io Docs: Billing](https://fly.io/docs/about/billing/)（官方逐字，2026-09-01 查閱） |

### 8. Auto-stop 冷啟動延遲

| 狀態 | 官方描述的喚醒延遲 | 來源 |
|---|---|---|
| Suspended → 恢復 | 官方原文（Fly Proxy/Machines 文件用語）：resume 為「a few hundred ms」等級，「Machine suspend lets you pause a running Fly Machine and save its complete state, including memory, to persistent storage. When resumed, the machine picks up exactly where it left off, without rebooting the OS or restarting your app.」 | [Fly.io Docs: Machine Suspend and Resume](https://fly.io/docs/reference/suspend-resume/)（官方逐字，2026-09-01 查閱） |
| Stopped → 冷啟動 | 官方文件定性描述冷啟動「takes seconds (about 2s for a Rails app, less for a small binary)」等級，比 suspend 慢，但**沒有給出精確到毫秒的統一官方數字**，需視 app 啟動時間而定 | 同上 |
| 重要警語 | 官方原文：「suspend isn't durable. If Fly can't restore the snapshot (host migration, capacity pressure), you get a cold start.」——即使設定 suspend，仍有機率退化成較慢的 stopped 冷啟動 | 同上 |

**判讀重點**：對「觀眾在台灣、流量極低且間歇」的情境，auto-stop 選 `suspend`（而非單純 `stop`）可把多數喚醒延遲壓到「幾百毫秒」等級，體感上接近沒有休眠；但官方明講這不是保證行為，遇到 host migration 或容量緊張時會退化成 2 秒以上的冷啟動，屬於「大部分時候很快，少數時候變慢」的機率性行為，不是像 Render 免費層那種穩定的「固定 1 分鐘喚醒」。

### 本專案試算表

**情境設定**：app machine（512MB / 1GB 兩檔，shared-cpu-1x，nrt 東京）× auto-stop 下「每天實際運轉 1 小時」與「每天 24 小時常開」兩種情境；PostgreSQL 採 unmanaged Fly Postgres 常開單節點，分別以官方「Development」預設（256MB RAM + 1GB volume）與較保守的「1GB RAM + 1GB volume」兩檔比較；流量固定抓 10GB/月（egress，套用第 4 節推論的 $0.04/GB）。所有金額為簡化計算（30 天/月、未計入 auto-stop 的分鐘級尾巴，見第 2 節判讀重點；也未計稅）。

**App machine 費用計算**（nrt，rootfs 假設 1GB，停止時比例攤提 $0.15/GB/月）：

| 檔位 × 運轉時數 | 運轉中費用（compute） | 停止中費用（rootfs，1GB 假設） | 小計 |
|---|---|---|---|
| 512MB，每天 1 小時 | 108,000秒 × $0.00000156 = $0.17 | 停止 23hr/天 → $0.15 × 23/24 = $0.14 | **$0.31** |
| 512MB，每天 24 小時 | 2,592,000秒 × $0.00000156 = $4.05 | 從不停止 → $0.00 | **$4.05** |
| 1GB，每天 1 小時 | 108,000秒 × $0.00000279 = $0.30 | 停止 23hr/天 → $0.14 | **$0.44** |
| 1GB，每天 24 小時 | 2,592,000秒 × $0.00000279 = $7.23 | 從不停止 → $0.00 | **$7.23** |

**PostgreSQL 常開費用**（單節點，機器 + 1GB volume；快照在每月前 10GB 免費額度內，計 $0）：

| 規格 | 機器月費（24/7） | Volume 月費 | 小計 |
|---|---|---|---|
| 官方 Development 預設：256MB RAM | $2.47 | $0.15 | **$2.62** |
| 較保守：1GB RAM（防 OOM，社群常見建議，見文件第 7 節 Kamal 部分的類似邏輯） | $7.23 | $0.15 | **$7.38** |

**流量**：10GB/月 × $0.04/GB = **$0.40/月**（推論性 nrt 費率，見第 4 節）。

**綜合月費區間**（App + PG + 流量），對照第 1 節查到的「$5 以下 100% 減免」門檻：

| App 檔位 | App 運轉情境 | PG 規格 | 月費試算 | 是否落在免收區（<$5） |
|---|---|---|---|---|
| 512MB | 每天 1 小時 | PG 256MB | 0.31 + 2.62 + 0.40 = **$3.33** | **是**——落入免收區 |
| 512MB | 每天 1 小時 | PG 1GB | 0.31 + 7.38 + 0.40 = **$8.09** | 否 |
| 512MB | 每天 24 小時 | PG 256MB | 4.05 + 2.62 + 0.40 = **$7.07** | 否 |
| 512MB | 每天 24 小時 | PG 1GB | 4.05 + 7.38 + 0.40 = **$11.83** | 否 |
| 1GB | 每天 1 小時 | PG 256MB | 0.44 + 2.62 + 0.40 = **$3.46** | **是**——落入免收區 |
| 1GB | 每天 1 小時 | PG 1GB | 0.44 + 7.38 + 0.40 = **$8.22** | 否 |
| 1GB | 每天 24 小時 | PG 256MB | 7.23 + 2.62 + 0.40 = **$10.25** | 否 |
| 1GB | 每天 24 小時 | PG 1GB | 7.23 + 7.38 + 0.40 = **$15.01** | 否 |

**判讀重點（與使用者「近期帳單都被 100% 減免」現況對照）**：

1. 8 種組合中只有 **2 種**（app 每天僅運轉 1 小時、且 PostgreSQL 採官方「Development」預設的 256MB 單節點）月費試算落在 $5 以下，與使用者實測的「100% 減免」現況吻合。這代表使用者現況很可能同時符合：(a) app 有效運轉時間很短（auto-stop 積極生效），(b) Postgres 是最小 256MB 單節點、非 HA 規格。
2. 只要 app 改成「每天 24 小時常開」，或 Postgres 提高到 1GB RAM 以策安全，月費立刻超過 $5 門檻，減免就不再適用——**這是「固定月費」規劃上的重要警訊**：Fly.io 的帳單不是固定的，使用者現在感受到的「幾乎免費」是「用量極低＋小額豁免政策」兩個條件同時成立的結果，一旦流量成長或想把 Postgres 規格拉到官方警告的「非 dev」等級以避免資料風險，帳單會跳增到 $7–15/月量級，且沒有官方支出上限或帳單告警可以預警（見第 7 節）。
3. Postgres 官方 256MB「Development」預設本身帶有官方明文的風險警語（SSD 故障或網路問題會直接讓資料庫down機、且無 HA），不建議作為長期正式營運配置；若考慮把這點納入「可接受的最低風險」，$38/月起的 Managed Postgres（第 5(a) 節）會是官方建議的替代方案，但会让整体月费远高于 $5 门槛。

### Fly.io 深度查證出處清單

- Fly.io Docs: Resource Pricing（官方定價頁）— https://fly.io/docs/about/pricing/
- Fly.io Docs: Billing（官方文件）— https://fly.io/docs/about/billing/
- Fly.io Docs: Cost Management（官方文件）— https://fly.io/docs/about/cost-management/
- Fly.io Docs: Machine Suspend and Resume（官方文件）— https://fly.io/docs/reference/suspend-resume/
- Fly.io Docs: Autostop/autostart Machines（官方文件）— https://fly.io/docs/launch/autostop-autostart/
- Fly.io Docs: Managed Postgres Overview（官方文件）— https://fly.io/docs/mpg/overview/
- Fly.io Docs: Fly Postgres (Unmanaged)（官方文件）— https://fly.io/docs/postgres/
- Fly.io Docs: This Is Not Managed Postgres（官方文件）— https://fly.io/docs/postgres/getting-started/what-you-should-know/
- Fly.io Docs: Create a Postgres Cluster（官方文件）— https://fly.io/docs/postgres/getting-started/create-pg-cluster/
- Fly.io Docs: SQLite3 (Rails advanced guide)（官方文件）— https://fly.io/docs/rails/advanced-guides/sqlite3/
- Fly.io Docs: LiteFS（官方文件）— https://fly.io/docs/litefs/
- Fly.io Docs: Regions Reference（官方文件）— https://fly.io/docs/reference/regions/
- （Fly.io 員工於社群論壇的說明，非正式定價頁逐字）Fly.io Community: questions on 100% billing discount — https://community.fly.io/t/questions-on-100-billing-discount/11133
- （社群討論，無官方員工回覆，僅交叉參考）Fly.io Community: Does Fly.io still waves <$5 invoices? — https://community.fly.io/t/does-fly-io-still-waves-5-invoices/25651
- （社群討論，無官方員工回覆，僅交叉參考）Fly.io Community: Is there still a policy on waiving invoices less than $5? — https://community.fly.io/t/is-there-still-a-policy-on-waiving-invoices-less-than-5-after-the-changes-in-october-2024/23560
