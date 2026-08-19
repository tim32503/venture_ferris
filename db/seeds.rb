# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# NOTE: the original 2018 event's question content was lost (no SQL dump survived — see
# docs/legacy/ANALYSIS.md / docs/REFACTOR_PLAN.md §0). Everything below is sample/demo
# content written for this portfolio rebuild, not a recovery of the real answers.

# ---------------------------------------------------------------------------
# 1. Questions (11 stations, sample content)
# ---------------------------------------------------------------------------
# kind mapping follows the legacy Wheel controller's `question($qno)` switch
# (application/controllers/Wheel.php:143-172): qno 1-2 render the puzzle view,
# qno 9 renders the "bear" view, everything else renders the plain quiz view.
QUESTION_SEEDS = [
  { number: 1, kind: :puzzle, title: "美福飯店（示範拼圖）", level: "1",
    puzzle_rows: 4, puzzle_cols: 4, answer: "meifu",
    content: "示範內容：拼出美福飯店的正面照片，找出隱藏的字母組合。",
    hint1: "示範提示一：注意拼圖邊角的顏色是否相鄰。",
    hint2: "示範提示二：中央區塊拼好後答案就會浮現。",
    explanation: "示範解說：答案為飯店招牌上的英文縮寫。" },
  { number: 2, kind: :puzzle, title: "燒烤（示範拼圖）", level: "1",
    puzzle_rows: 1, puzzle_cols: 9, answer: "yakiniku",
    content: "示範內容：把橫向切成 9 條的照片拼回原樣，讀出招牌上的店名。",
    hint1: "示範提示一：先找出最左邊與最右邊的兩條。",
    hint2: "示範提示二：店名是四個字的日文燒烤店。",
    explanation: "示範解說：答案為招牌店名的羅馬拼音。" },
  { number: 3, kind: :quiz, title: "美麗華Ａ－石牆（示範問答）", level: "2",
    answer: "meilihua",
    content: "示範內容：石牆上刻著一段文字，請找出其中的關鍵詞。",
    hint1: "示範提示一：文字位於石牆左下角。",
    hint2: "示範提示二：關鍵詞是這座摩天輪所在的商場名稱。",
    explanation: "示範解說：答案為美麗華百樂園的簡稱。" },
  { number: 4, kind: :quiz, title: "美麗華Ｂ－植栽（示範問答）", level: "2",
    answer: "zhiwu",
    content: "示範內容：數一數花圃裡某種植物的數量，作為答案。",
    hint1: "示範提示一：只計算開花的植株。",
    hint2: "示範提示二：答案是一個兩位數字。",
    explanation: "示範解說：答案為花圃植株的示範計數。" },
  { number: 5, kind: :quiz, title: "北投（示範問答）", level: "3",
    answer: "beitou",
    content: "示範內容：找出北投地熱谷告示牌上的溫度數值。",
    hint1: "示範提示一：告示牌在入口右側。",
    hint2: "示範提示二：答案是攝氏度數。",
    explanation: "示範解說：答案為告示牌上的示範溫度。" },
  { number: 6, kind: :quiz, title: "龍山寺（示範問答，不開放提示）", level: "3",
    hints_enabled: false, answer: "longshan",
    content: "示範內容：本題不提供提示，請仔細觀察龍山寺正殿的匾額文字。",
    explanation: "示範解說：答案為匾額上的示範字詞。" },
  { number: 7, kind: :quiz, title: "朝陽（示範問答）", level: "2",
    answer: "zhaoyang",
    content: "示範內容：朝陽市場招牌上寫著創立年份，請填入答案。",
    hint1: "示範提示一：招牌在市場正門上方。",
    hint2: "示範提示二：答案是四位數的西元年份。",
    explanation: "示範解說：答案為示範創立年份。" },
  { number: 8, kind: :quiz, title: "公館（示範問答）", level: "2",
    answer: "gongguan",
    content: "示範內容：公館河堤上的標語牌寫著一句口號，請找出關鍵字。",
    hint1: "示範提示一：標語牌沿著河堤步道設置。",
    hint2: "示範提示二：關鍵字與河川保護有關。",
    explanation: "示範解說：答案為示範口號關鍵字。" },
  { number: 9, kind: :bear, title: "熊讚（示範特殊題）", level: "4",
    answer: "xiongzan",
    content: "示範內容：找到熊讚吉祥物立牌，讀出立牌底部的編號。",
    hint1: "示範提示一：立牌位於廣場中央。",
    hint2: "示範提示二：編號是三位數字。",
    explanation: "示範解說：答案為示範吉祥物編號。" },
  { number: 10, kind: :quiz, title: "摩天（示範問答）", level: "4",
    answer: "moutian",
    content: "示範內容：摩天輪車廂上標示的載客人數上限即為答案。",
    hint1: "示範提示一：標示貼在車廂門邊。",
    hint2: "示範提示二：答案是個位數字。",
    explanation: "示範解說：答案為示範載客人數上限。" },
  { number: 11, kind: :quiz, title: "終極謎題（示範最終關）", level: "5",
    auto_start: true, base_score: 3000, answer: "finale",
    content: "示範內容：綜合前面 10 題的關鍵字首字母，組成最終密語。",
    hint1: "示範提示一：依解題順序排列首字母。",
    hint2: "示範提示二：最終密語共 6 個字母。",
    explanation: "示範解說：答案為示範最終密語。" }
].freeze

# Demo-friendly boss difficulty: this is a portfolio showcase, not a live
# multi-hour event, so every boss fight uses a short fixed HP/time-limit
# rather than the legacy production values (kept as column defaults in the
# migration for documentation purposes).
DEMO_BOSS_HP = 10
DEMO_BOSS_TIME_LIMIT = 60

QUESTION_SEEDS.each do |attrs|
  attrs = attrs.dup
  answer = attrs.delete(:answer)

  question = Question.find_or_initialize_by(number: attrs.fetch(:number))
  question.assign_attributes(
    kind: attrs.fetch(:kind),
    title: attrs.fetch(:title),
    level: attrs.fetch(:level),
    content: attrs.fetch(:content),
    hint1: attrs[:hint1],
    hint2: attrs[:hint2],
    explanation: attrs.fetch(:explanation),
    hints_enabled: attrs.fetch(:hints_enabled, true),
    auto_start: attrs.fetch(:auto_start, false),
    base_score: attrs.fetch(:base_score, Question::DEFAULT_BASE_SCORE),
    puzzle_rows: attrs[:puzzle_rows],
    puzzle_cols: attrs[:puzzle_cols],
    boss_hp: DEMO_BOSS_HP,
    boss_time_limit: DEMO_BOSS_TIME_LIMIT,
    answer_digest: Question.digest_for(answer),
  )
  question.save!
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

puts "Seeded: #{Question.count} questions, #{Team.count} teams, " \
     "#{Player.count} players, #{RewardCode.count} reward codes, #{Admin.count} admins."
