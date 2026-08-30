# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# NOTE: the original 2018 event's SQL dump was recovered on 2026-08-29 and the
# question content below (title/content/level/hints/explanation) is
# restored verbatim from its `QUEST_MAIN` table. The plain-text answers are
# never stored — only `Question.digest_for(answer)` is persisted, same as
# before (see app/models/question.rb). Questions 1, 2 and 9 (kind: puzzle /
# bear) are the exception: their `QUESTION_PASSWORD` was an EMPTY string in
# the original dump, because the legacy game judged them entirely
# client-side — a solved jigsaw (wheel_puzzle.php) or 5 correctly-found
# hotspots (wheel_bear.php) WAS the answer, with no text ever compared
# server-side. This batch restores that behavior instead of papering over it
# with a placeholder answer: these three questions have no `answer:` key at
# all below, and `answer_digest` stays NULL for them (see
# `Question#interactive?` and `Game::QuestionsController#answer`).

# ---------------------------------------------------------------------------
# 1. Questions (11 stations, restored from the 2018 QUEST_MAIN dump)
# ---------------------------------------------------------------------------
# kind mapping follows the legacy Wheel controller's `question($qno)` switch
# (application/controllers/Wheel.php:143-172): qno 1-2 render the puzzle view,
# qno 9 renders the "bear" view, everything else renders the plain quiz view.
QUESTION_SEEDS = [
  { number: 1, kind: :puzzle, title: "美福飯店", level: "★☆☆☆☆",
    puzzle_rows: 4, puzzle_cols: 4,
    content: "美福飯店中的房客非常喜歡門口屋簷天花上的圖樣，於是用畫紙記錄下來，因為圖樣太大而分成數張記錄下來，" \
             "沒想到卻不小心打亂了，可以請你們幫他復原嗎？",
    explanation: "" },
  { number: 2, kind: :puzzle, title: "一鷺炭火燒鳥工房", level: "★☆☆☆☆",
    puzzle_rows: 1, puzzle_cols: 9,
    content: "日以繼夜的冒險讓勇者們身心俱疲，來到了聲名遠播的一鷺燒烤店歇腳，希望飽餐一頓後再重新踏上旅途，" \
             "沒想到用餐居然有特定的順序，否則將會被趕出店門，究竟這順序為何呢？",
    explanation: "" },
  { number: 3, kind: :quiz, title: "美麗華A", level: "★★★☆☆",
    answer: "STARWARS",
    content: "離開了新手村後，你們來到了美麗華樂園，經過影城售票亭時，卻聽見了一陣微弱的喊叫聲，" \
             "走近一看發現是一名老人，究竟他有何事求助於你們呢？",
    hints: [
      "所謂兩館之間高聳的植栽，指的好像是海景大道中間的八顆棕櫚樹，而線索上的字母剛好也是八個，這其中會有什麼關聯嗎？",
      "八顆棕梠樹的坐台上總共有1到8的數字，會不會是跟順序有關呢？如果按照這個順序把字母排列的話...."
    ],
    explanation: "" },
  { number: 4, kind: :quiz, title: "美麗華B", level: "★★★☆☆",
    answer: "COIN",
    content: "「據說美麗華兩館之間的走道中有一面神秘的石板...」「石板上的刻痕都不盡相同」" \
             "「若是能參透下列線索中的奧秘」「就能夠解答出石板中所蘊藏的訊息」",
    hints: [
      "網頁線索上的這些圖形，似乎都可以在石板上找出來相同的形狀。",
      "從石板上找出了相同圖形，分別在不同的四個角落，線索中圖形之間的箭頭會是連線的意思嗎？"
    ],
    explanation: "" },
  { number: 5, kind: :quiz, title: "北投", level: "★★★★☆",
    answer: "1896",
    content: "嘉年華活動中，各個攤位都賣力地宣傳，忽然收到溫泉商店廣告單的你們，收到折扣吸引，決定去一探究竟。",
    hints: [
      "仔細觀察現場立牌上的符號，似乎在手冊上的好幾頁中都有看到部分的圖形，依照立牌上的步驟，應該就可以組合出正確的符號。",
      "組合出正確的符號後，依照立牌上的箭頭順序，才可以解出正確的密碼喔！"
    ],
    explanation: "沒錯！答案就是1896，<br/>也就是北投開設第一家溫泉旅館的年份唷！" },
  # No `hints:` key at all — which is exactly why the old explicit
  # `hints_enabled: false` on this question could be dropped: it was a
  # derived value that always equalled "this question has hint text"
  # (docs/SCHEMA_REDESIGN.md §0-E6). No hint rows now means the hint button
  # is never rendered and POST /hints answers 403, same as before.
  { number: 6, kind: :quiz, title: "龍山寺", level: "★★☆☆☆",
    answer: "224",
    content: "好熱啊....快熱死了....村民一個個在抱怨，似乎因為怪物出沒的緣故，使的附近區域的氣溫不斷攀升，" \
             "再不想辦法解決的話，還未到目的地就會因為酷暑而昏倒在半途中了。",
    explanation: "沒錯！答案就是224，<br/>龍山寺商圈的青草巷就位在西昌街224巷，<br/>有空不妨可以去拜訪看看喔！" },
  { number: 7, kind: :quiz, title: "朝陽", level: "★★☆☆☆",
    answer: "3736",
    content: "「一行人來到了新手村的裝備屋」「佈告欄上貼了一道大大的題目」「據說解開題目就可以獲得免費的裝備」" \
             "「究竟下列算式的答案為何？」「據說新手村中的朝陽商店，有相關的線索唷！」",
    hints: [
      "這些數字中的圖示好像是鈕扣的造型、跟商店現場的立牌會不會有什麼關聯呢？",
      "原來題目中的鈕扣圖示，都可以從立牌上找出來、但是又好像有點不同的地方...立牌上的鈕扣多了縫線，會是解題的關鍵嗎？"
    ],
    explanation: "" },
  { number: 8, kind: :quiz, title: "公館", level: "★★★★☆",
    answer: "WILLIAM",
    content: "由於旅途勞累，大夥兒希望在公館商店買上一杯知名的調飲紓解身心，沒想到商家卻面色凝重的擺上暫停販售，" \
             "究竟是怎麼一回事呢？",
    explanation: "沒錯！答案就是William，William. K. Burton就是人稱台灣自來水之父的威廉·巴爾頓，" \
                 "現在的自來水園區內仍鑄有他的銅像喔！" },
  { number: 9, kind: :bear, title: "熊讚", level: "★☆☆☆☆",
    content: "為了標註旅途的路線，你們將熊讚的雕像畫在地圖上，但好像有些地方畫錯了，究竟是哪些地方呢？",
    explanation: "" },
  { number: 10, kind: :quiz, title: "摩天輪F1", level: "★★★☆☆",
    answer: "FRONT",
    content: "終於成功收集到了九項物品，你們馬上前往魔王佔據的摩天輪，希望召喚出神器將魔王打倒，" \
             "但在這之前...必須通過神器的考驗。",
    hints: [
      "在地面上的紅色車廂即為摩天輪的售票口，請至側邊觀看，即可找到與線索上排列方式相同的字樣。",
      "找出排列位置中空格的地方，對照售票亭上的字母，按照順序就可以獲得解答。"
    ],
    explanation: "沒錯、正解就是「FRONT」，也就是前方的意思，接下來就前往紅色車廂的正面，準備完成下一個考驗吧！" },
  { number: 11, kind: :quiz, title: "摩天輪F2", level: "★★★★★",
    auto_start: true, base_score: 3000, answer: "HEART",
    content: "請留意題目圖片上方的敘述喔！",
    hints: [
      "從售票亭的正面可找出與線索排列方式相同的字樣，對照後可發現網頁上頁碼符號的位置，在售票亭上的字樣皆為數字。",
      "對照售票亭上的數字，找出該數字在手冊上的頁碼，依照箭頭的順序排列手冊頁碼符號上的字母，即可獲得解答。"
    ],
    explanation: "" }
].freeze

# ---------------------------------------------------------------------------
# 1b. Bosses (10 monsters, 11 questions)
# ---------------------------------------------------------------------------
# The one place the boss<->question mapping is stated. Questions 10 and 11
# deliberately share a single row: they are phase 1 and phase 2 of the same
# 摩天輪魔王, which is also why `mon10.gif` never existed in the recovered
# asset set (docs/SCHEMA_REDESIGN.md §2-3). `phase` is omitted — and stored as
# NULL — for every single-phase boss, which is what makes the phase badge
# render for exactly two questions and nothing else.
BOSS_ASSIGNMENTS = {
  1 => { sprite: "mon01" },
  2 => { sprite: "mon02" },
  3 => { sprite: "mon03" },
  4 => { sprite: "mon04" },
  5 => { sprite: "mon05" },
  6 => { sprite: "mon06" },
  7 => { sprite: "mon07" },
  8 => { sprite: "mon08" },
  9 => { sprite: "mon09" },
  10 => { sprite: "mon11", phase: 1 },
  11 => { sprite: "mon11", phase: 2 }
}.freeze

# Demo-friendly boss difficulty: this is a portfolio showcase, not a live
# multi-hour event, so every boss fight uses a short fixed HP/time-limit
# rather than the legacy production values (kept as column defaults in the
# migration for documentation purposes).
DEMO_BOSS_HP = 10
DEMO_BOSS_TIME_LIMIT = 60

QUESTION_SEEDS.each do |attrs|
  attrs = attrs.dup
  answer = attrs.delete(:answer)

  assignment = BOSS_ASSIGNMENTS.fetch(attrs.fetch(:number))
  boss = Boss.find_or_create_by!(sprite: assignment.fetch(:sprite))

  question = Question.find_or_initialize_by(number: attrs.fetch(:number))
  question.assign_attributes(
    kind: attrs.fetch(:kind),
    boss: boss,
    boss_phase: assignment[:phase],
    title: attrs.fetch(:title),
    level: attrs.fetch(:level),
    content: attrs.fetch(:content),
    explanation: attrs.fetch(:explanation),
    auto_start: attrs.fetch(:auto_start, false),
    base_score: attrs.fetch(:base_score, Question::DEFAULT_BASE_SCORE),
    puzzle_rows: attrs[:puzzle_rows],
    puzzle_cols: attrs[:puzzle_cols],
    boss_hp: DEMO_BOSS_HP,
    boss_time_limit: DEMO_BOSS_TIME_LIMIT,
    # Interactive kinds (puzzle/bear — see Question#interactive?) have no
    # `answer:` key above, so `answer` is nil here and the digest stays
    # NULL; only quiz questions hash a real answer.
    answer_digest: answer ? Question.digest_for(answer) : nil,
  )
  question.save!

  # Hints live in their own table now (docs/SCHEMA_REDESIGN.md §2-4), so
  # "this question has no hints" is expressed by having no rows here rather
  # than by a separate `hints_enabled` flag. Two consequences worth knowing:
  #
  #   * `Game::QuestionsController#hints` caps at `question.hints.size`, so
  #     the number of entries in `hints:` *is* the per-question hint limit.
  #     Every question here has either 0 or 2, which is what makes this
  #     equivalent to the retired `HINT_LIMIT = 2` constant — change the
  #     count and you change the cap.
  #   * Questions 1/2/6/8/9 have no `hints:` key. In the 2018 dump their
  #     hint columns were empty strings and the legacy site still let players
  #     spend (and be charged for) a hint on blank text; no rows here makes
  #     that structurally impossible.
  Array(attrs[:hints]).each_with_index do |content, index|
    hint = QuestionHint.find_or_initialize_by(question: question, position: index + 1)
    hint.content = content
    hint.save!
  end
  question.hints.where("position > ?", Array(attrs[:hints]).size).destroy_all
end

# ---------------------------------------------------------------------------
# 2. Demo team (fixed 16-char serial, kept as showcase data — intentionally
#    seeded with zero players). Each visitor who clicks the homepage "Demo"
#    button gets their own brand-new single-player demo team created on the
#    fly by Game::SessionsController#create (see `create_demo!`), so this
#    fixed-serial team is not the one visitors actually play in; pre-seeding
#    it with 4 players used to permanently deadlock the single-visitor demo
#    flow (a lone visitor could never reach `ready 1/1` against a team of 4).
# ---------------------------------------------------------------------------
DEMO_SERIAL_NO = Team::DEMO_SERIAL_NO
raise "DEMO_SERIAL_NO must be exactly 16 chars" unless DEMO_SERIAL_NO.length == 16

demo_team = Team.find_or_initialize_by(serial_no: DEMO_SERIAL_NO)
demo_team.test_mode = true
demo_team.name = "Demo 體驗隊"
demo_team.save!

# ---------------------------------------------------------------------------
# 3. Production serial pool (20 real teams, test_mode: false)
# ---------------------------------------------------------------------------
PRODUCTION_TEAM_COUNT = 20

(1..PRODUCTION_TEAM_COUNT).each do |n|
  serial_no = format("TEAM%012d", n)
  raise "serial_no must be exactly 16 chars" unless serial_no.length == 16

  Team.find_or_create_by!(serial_no: serial_no) do |team|
    team.test_mode = false
  end
end

# ---------------------------------------------------------------------------
# 4. Reward code pool (100 codes, half test_mode true / half false)
# ---------------------------------------------------------------------------
REWARD_CODE_COUNT = 100
REWARD_CODE_TEST_MODE_COUNT = REWARD_CODE_COUNT / 2

(1..REWARD_CODE_COUNT).each do |n|
  test_mode = n <= REWARD_CODE_TEST_MODE_COUNT
  prefix = test_mode ? "RWDT" : "RWDP"
  code = format("%s%06d", prefix, n)

  RewardCode.find_or_create_by!(code: code) do |reward_code|
    reward_code.test_mode = test_mode
  end
end

# ---------------------------------------------------------------------------
# 5. Admin account (password from ENV, dev fallback only)
# ---------------------------------------------------------------------------
ADMIN_EMAIL = "admin@venture-ferris.example"

unless Admin.exists?(email: ADMIN_EMAIL)
  Admin.create!(
    email: ADMIN_EMAIL,
    password: ENV.fetch("ADMIN_PASSWORD", "changeme"),
  )
end

puts "Seeded: #{Question.count} questions, #{Boss.count} bosses, " \
     "#{QuestionHint.count} question hints, #{Team.count} teams, " \
     "#{Player.count} players, #{RewardCode.count} reward codes, #{Admin.count} admins."
