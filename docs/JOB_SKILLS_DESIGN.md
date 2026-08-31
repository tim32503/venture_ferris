# 職業技能設計（Boss 戰主動技）

> 狀態：定案（2026-08-30，使用者授權「依合適建議直接調整」）。實作於 schema 正規化（`docs/SCHEMA_REDESIGN.md`）之後，蓋在新 schema 上。
> 原則：與既有被動效果互補、每場王戰每人一次、**效果判定與授權全在伺服器端**（延續全案敘事）、單人 Demo 與 4 人隊都成立。

## 現況（被動，保留不動）

| 職業 | 既有被動 | 作用面 |
|---|---|---|
| 阿北 uncle | Boss 時限 +10 秒 | 戰鬥 |
| 鄉民 netizen | 每次攻擊 +2 | 戰鬥 |
| 鞋姊 senior | 提示不扣分 | 計分 |
| 罔美 celebrity | job_score +100 | 計分 |

問題：senior/celebrity 在戰鬥中毫無存在感；技能不可見，選職業像抽籤。

## 新增主動技（每場王戰每人限用一次）

| 職業 | 技能名 | 效果 | 伺服器實作 |
|---|---|---|---|
| 阿北 | 倚老賣老 | 本場戰鬥時限再 +10 秒 | `boss_battles.bonus_time_seconds += 10`（新欄位，int default 0）；剩餘時間計算納入 |
| 鄉民 | 肉搜公審 | 立即造成 5 點傷害 | `attack_count += 5`（可直接擊殺，走既有 defeated 判定） |
| 鞋姊 | 醍醐灌頂 | 自己的下一次攻擊必定爆擊（×2，無視節流） | skill_use 記 `pending`，該玩家下次 attack 消耗之→強制 crit 並 bypass throttle |
| 罔美 | 聚光燈 | 立即召喚弱點並使爆擊窗開啟 5 秒（期間爆擊宣告不受 2 秒節流限制） | `boss_battles.spotlight_until = now + 5s`（新欄位）；client 收到成功回應即生成弱點標記 |

## 資料模型

- `boss_skill_uses`：`boss_battle_id` FK、`player_id` FK、`skill`(string enum：與 job 同名或技能 key)、`consumed_at`(senior 用)、timestamps；**unique [boss_battle_id, player_id]**（每人每場一次，DB 保證）。
- `boss_battles` 加 `bonus_time_seconds`(int, default 0, null false)、`spotlight_until`(datetime, null)。
- 技能與職業綁定：玩家只能發動自己職業的技能（伺服器依 `current_player.job` 決定效果，client 傳意圖不傳效果）。

## 路由與介面

- `POST /game/bosses/:number/skill`（新 member action，routes 需加一行）：無參數（技能由玩家職業決定）；回 JSON `{skill:, effect:, ...}` 或 redirect（與 attacks 一致採 fetch＋JSON）。
- 失敗情境：戰鬥未開始/已結束、已用過（unique 擋）、未選職業 → 明確錯誤回應。
- `status.json` 增加 `bonus_time_seconds`、`spotlight_active`，供隊友端同步倒數與弱點窗。

## UI

- Boss 戰畫面加「技能卡」：顯示玩家職業技能名＋一句描述，可用時高亮、用過後轉灰（狀態由伺服器 status 提供，不信任 client 記憶）。
- 發動回饋：uncle→倒數數字跳增＋提示；netizen→怪物連續受擊演出＋大傷害數字；senior→攻擊按鈕/怪物加「蓄力」光效直到下次攻擊；celebrity→立即弱點＋聚光燈視覺 5 秒。
- 職業選擇頁（carousel）補上各職業的被動＋主動技說明，讓選職業成為有資訊的決策。

## 測試要求

- Integration：四技能各自的伺服器效果、每場一次（第二次 422/redirect）、未開戰/已結束被拒、未選職業被拒、senior 的 pending 消耗與 bypass throttle、celebrity 窗內爆擊不受節流且窗外恢復節流（travel_to）。
- M0 黃金值計分測試不受影響（技能不改計分公式；netizen 主動技的 +5 屬 attack_count，boss_score 計算沿既有公式——如受影響需在測試中釘住新的字面量並說明）。
- System：技能卡顯示與發動後轉灰。

## 平衡備註（demo hp=10 基準）

單人 demo：netizen 主動技 5 傷＝半血，仍需點擊；celebrity 聚光燈使爆擊連發可觀但窗僅 5 秒；uncle/senior 在時限寬鬆的 demo 中偏保險型。正式難度（hp 120/30 秒）下四技均有明確位置。數值日後可調（都是常數）。
