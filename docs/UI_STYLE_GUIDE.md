# UI 風格指南（TailwindCSS）

> U3 Tailwind 改版的設計基礎。本文件定義 tokens 與元件配方（具體 class 字串），後續批次（U3b 遊戲頁、U3c 移除 Bootstrap）直接照抄，不要重新發明。
> 現況：Bootstrap 4 CDN CSS（`app/views/layouts/application.html.erb`）與 `site.scss` 本批仍保留，供尚未轉換的頁面（`app/views/game/**`）使用。Tailwind utilities 一律用「class 選擇器」，具體度天生高於 site.scss 的 element 選擇器（`body`、`header`、`main`），衝突時 Tailwind 會贏，不需要 `!important`。

## 兩套主題

專案有兩種介面語氣，靠 `content_for :body_class` 切換（見下方「頁面骨架」）：

| 主題 | 適用範圍 | 基調 |
|---|---|---|
| **玩家端（冒險）** | `welcome/*`（首頁、隱私權、錯誤頁）、未來 U3b 的 `game/**` | 深色、amber 強調色的冒險遊戲感 |
| **Admin 後台** | `admin/**` | 明亮乾淨，與玩家端明顯區隔，像一般後台工具 |

`game/**` 本批不動，維持 Bootstrap／site.scss 原樣，等 U3b 再套用「玩家端」配方。

## Design Tokens

### 玩家端（深色冒險）

| 用途 | Token |
|---|---|
| 底色（body 背景漸層） | `bg-gradient-to-b from-slate-900 via-slate-900 to-slate-800` |
| 卡片底色 | `bg-slate-800/80` |
| 卡片邊框 | `ring-1 ring-white/10` |
| 主要文字 | `text-slate-100` |
| 次要文字 | `text-slate-300` / `text-slate-400` |
| 主行動色（冒險金） | `amber-400` / `amber-500`（hover 用 `amber-400`，預設 `amber-500`） |
| 輔助色 | `indigo-400` / `indigo-500` |
| 危險／錯誤 | `rose-400` / `rose-500` |
| 成功 | `emerald-400` / `emerald-500` |
| 字體 | Noto Sans TC（沿用 `site.scss` 的全域 `*{font-family:'Noto Sans TC'}`，Tailwind 不重複宣告） |

### Admin 後台（明亮）

| 用途 | Token |
|---|---|
| 底色 | `bg-slate-50` |
| 卡片底色 | `bg-white` |
| 卡片邊框/陰影 | `ring-1 ring-slate-200 shadow-sm` |
| 主要文字 | `text-slate-800` |
| 次要文字 | `text-slate-500` |
| 主行動色 | `indigo-600`（hover `indigo-500`） |
| 危險 | `rose-600` |
| 成功 | `emerald-600` |

## 頁面骨架（layout）

`app/views/layouts/application.html.erb` 的 `<body>` 用 `content_for :body_class` 決定主題；沒有設定時（目前只有 `game/**`）維持空字串，交給 `site.scss` 的既有規則接手，不受 Tailwind 影響：

```erb
<body class="<%= yield(:body_class) %> min-h-screen">
```

各頁在最上方宣告：

```erb
<% content_for :body_class, "bg-gradient-to-b from-slate-900 via-slate-900 to-slate-800 text-slate-100" %>  <%# 玩家端 %>
<% content_for :body_class, "bg-slate-50 text-slate-800" %>                                                  <%# admin %>
```

## 元件配方

> **重要**：下面的範例為求簡潔，沒有逐一標示 `!`。實作時請看完文末「已知陷阱」一節——Bootstrap reboot 對 `a`／`button`／`table`／`h1`-`h6` 等裸標籤都有 `color`/`background-color`/`margin` 等 reset，`site.scss` 對 `body`/`header`/`main`/`footer`/`.dialog` 也有類似 reset，這些 reset 全部是 unlayered CSS，會直接蓋掉 Tailwind utility（即使 Tailwind 選擇器具體度更高）且不會有任何錯誤訊息。本批的實際作法是**幫這 6 個頁面用到的每一個 utility class 都加上 `!`**（本文件的程式碼範例本身沒加，是為了維持可讀性），而不是每次都去判斷「這個標籤會不會被 reset」——判斷成本比直接全部加 `!` 高，尤其 `link_to`/`button_to` 渲染出來的是 `<a>` 標籤，最容易漏掉（Bootstrap 對 `a` 有 `color`＋`background-color`＋`text-decoration` 三個 reset，用 `<a>` 做按鈕沒加 `!` 會整個看起來像沒套到樣式的裸連結）。

### 頁面容器

```html
<!-- 玩家端 -->
<main class="mx-auto max-w-2xl px-4 py-8 sm:py-12">...</main>

<!-- admin -->
<main class="mx-auto max-w-4xl px-4 py-8 sm:py-12">...</main>
```

### 卡片

```html
<!-- 玩家端 -->
<div class="rounded-xl bg-slate-800/80 p-6 ring-1 ring-white/10 backdrop-blur">
  ...
</div>

<!-- admin -->
<div class="rounded-xl bg-white p-6 ring-1 ring-slate-200 shadow-sm">
  ...
</div>
```

### 按鈕

```html
<!-- 玩家端：主按鈕 -->
<button class="inline-flex items-center justify-center rounded-lg bg-amber-500 px-5 py-2.5 font-semibold text-slate-900 transition hover:bg-amber-400 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-amber-400">
  按鈕文字
</button>

<!-- 玩家端：次按鈕 -->
<button class="inline-flex items-center justify-center rounded-lg bg-slate-700 px-5 py-2.5 font-semibold text-slate-100 ring-1 ring-white/10 transition hover:bg-slate-600">
  按鈕文字
</button>

<!-- admin：主按鈕 -->
<button class="inline-flex items-center justify-center rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-indigo-500">
  按鈕文字
</button>

<!-- admin：次按鈕 -->
<button class="inline-flex items-center justify-center rounded-lg bg-white px-4 py-2 text-sm font-semibold text-slate-700 ring-1 ring-slate-300 transition hover:bg-slate-50">
  按鈕文字
</button>
```

### 表單 input

```html
<!-- 玩家端 -->
<label class="mb-1 block text-sm font-medium text-slate-300">標籤</label>
<input class="w-full rounded-lg border-0 bg-slate-900/60 px-3 py-2 text-slate-100 ring-1 ring-inset ring-white/10 placeholder:text-slate-500 focus:ring-2 focus:ring-inset focus:ring-amber-400">

<!-- admin -->
<label class="mb-1 block text-sm font-medium text-slate-700">標籤</label>
<input class="w-full rounded-lg border-0 px-3 py-2 text-slate-800 ring-1 ring-inset ring-slate-300 placeholder:text-slate-400 focus:ring-2 focus:ring-inset focus:ring-indigo-500">
```

### 表格（admin 用）

```html
<div class="overflow-x-auto rounded-xl bg-white ring-1 ring-slate-200">
  <table class="min-w-full divide-y divide-slate-200 text-sm">
    <thead class="bg-slate-50">
      <tr>
        <th class="px-4 py-3 text-left font-semibold text-slate-600">欄位</th>
      </tr>
    </thead>
    <tbody class="divide-y divide-slate-100">
      <tr>
        <td class="px-4 py-3 text-slate-700">內容</td>
      </tr>
    </tbody>
  </table>
</div>
```

### Flash 訊息

```html
<!-- success -->
<div class="rounded-lg bg-emerald-50 px-4 py-3 text-sm text-emerald-800 ring-1 ring-emerald-200">…</div>
<!-- 玩家端深色底下的 success -->
<div class="rounded-lg bg-emerald-500/10 px-4 py-3 text-sm text-emerald-300 ring-1 ring-emerald-500/30">…</div>

<!-- alert / error -->
<div class="rounded-lg bg-rose-50 px-4 py-3 text-sm text-rose-800 ring-1 ring-rose-200">…</div>
<!-- 玩家端深色底下的 alert -->
<div class="rounded-lg bg-rose-500/10 px-4 py-3 text-sm text-rose-300 ring-1 ring-rose-500/30">…</div>
```

### `<dialog>`（原生對話框，如 Turbo confirm）

沿用玩家端卡片配方，深色底＋amber 主按鈕：

```html
<div class="rounded-xl bg-slate-800 p-6 text-center ring-1 ring-white/10 shadow-2xl" style="max-width:22rem;width:90%;">
  <p class="mb-4 text-slate-100"></p>
  <div class="flex justify-center gap-3">
    <button type="button" class="rounded-lg bg-amber-500 px-4 py-2 font-semibold text-slate-900 hover:bg-amber-400" data-confirm-accept>確認</button>
    <button type="button" class="rounded-lg bg-slate-700 px-4 py-2 font-semibold text-slate-100 ring-1 ring-white/10 hover:bg-slate-600" data-confirm-cancel>取消</button>
  </div>
</div>
```

## 文章排版（`privacy` 頁）

未安裝 `@tailwindcss/typography`（需額外 gem/plugin，本批未評估相依性），改用手工 prose 樣式，套在條款內容的外層容器：

```html
<div class="space-y-4 leading-relaxed text-slate-300 [&_h4]:mt-6 [&_h4]:mb-2 [&_h4]:text-lg [&_h4]:font-semibold [&_h4]:text-slate-100 [&_ul]:list-disc [&_ul]:space-y-1 [&_ul]:pl-6">
  ...
</div>
```

## 遊戲美術素材

背景圖／立繪／地圖等素材本批不換，繼續用 `asset_path`／`image_tag`；只有外層容器與版面元件（卡片、按鈕、表格、表單）改用上面的配方。`welcome/index` 的 hero 背景圖（`loginBg.jpg`）保留，用 `style="background-image:url(...)"` 搭配 Tailwind 版面 class。

## 已知陷阱：Tailwind v4 的 `@layer` 會輸給舊 CSS（body/header/main/footer）

Tailwind v4 產出的 CSS 全部包在 `@layer theme, base, components, utilities, properties;` 裡；`site.scss`（sassc 編譯）與 Bootstrap CDN CSS 完全沒有 `@layer` 包裝，屬於「unlayered」。CSS 層疊規則規定：**任何 unlayered 的一般（非 `!important`）宣告，優先度永遠高於任何 layered 宣告，跟選擇器具體度、`<link>` 載入順序都無關。**

`site.scss` 對 `body`／`header`／`main`／`footer` 這幾個元素本身下了 element 選擇器規則（背景圖、margin、padding、color），Bootstrap reboot 對 `body` 也下了 `color`／`background-color`。只要 Tailwind utility class 直接套在這四個元素標籤本身，且剛好撞到同一個 CSS 屬性，Tailwind 會被無聲蓋掉（不會報錯，畫面就是不對）。範例：本批一開始 `<body class="bg-gradient-to-b ...">` 完全沒有生效，因為 `site.scss` 的 `body{background-image:...}` unlayered 贏了。

**對策**：只在直接套用到 `body`／`header`／`main`／`footer` 標籤上、且會撞到 `site.scss`／Bootstrap 既有屬性（`background-image`／`background-color`／`color`／`margin`／`padding-bottom`）的那幾個 utility class 後面加 Tailwind v4 的 important 修飾字尾 `!`（例如 `mx-auto!`、`bg-gradient-to-b!`、`text-slate-100!`、`py-12!`）。套在其他一般 wrapper `<div>`／`<dl>`／`<table>` 等元素上的 utility class 不需要，因為 `site.scss` 沒有對應的裸元素選擇器去搶。

實際用法（見本批 `welcome/*`、`admin/*` views）：

```erb
<% content_for :body_class, "bg-gradient-to-b! from-slate-900 via-slate-900 to-slate-800 text-slate-100!" %>  <%# 玩家端；background-image + color 撞 site.scss/Bootstrap，需要 ! %>
<% content_for :body_class, "bg-slate-50! bg-none! text-slate-800!" %>                                          <%# admin；bg-none! 蓋掉 site.scss 的 bg.jpg 圖 %>
<% content_for :footer_class, "text-slate-400!" %>                                                              <%# 撞 site.scss 的 footer{color:white} %>
<header class="mx-auto! max-w-2xl ...">                                                                        <%# 撞 site.scss 的 header{margin:2rem} %>
<main class="mx-auto! max-w-2xl px-4 pb-12! ...">                                                               <%# 撞 site.scss 的 main{padding-bottom:5em} %>
```

U3b（`game/**`）套用玩家端配方時會遇到同樣的問題（那些頁面本身也是 `main`／`.dialog` 等元素），照同一套「撞到就加 `!`」規則處理即可；`.dialog` 等 class 選擇器規則本身具體度較高，即使 unlayered，也建議一律用 `!` 保險，不要每次都重新судить要不要加。

## Admin 表格 RWD

Admin 序號表格資料量小、欄位少（4 欄），維持一般 `<table>` 搭配 `overflow-x-auto` 外層即可，不需卡片化。
