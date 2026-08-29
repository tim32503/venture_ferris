require "test_helper"

module Game
  # M0 金標測試（docs/SCHEMA_REDESIGN.md §7）：計分是這次 schema 正規化裡
  # 唯一「不能變」卻又最容易被悄悄改掉的東西——它橫跨 QuestionAttempt 的
  # 計時、QuestionHint 的提示扣分、BossBattle 的擊敗加分與 Player#job 的
  # 職業加分，四張表全部都在本次重構的動刀範圍內。
  #
  # 所以這裡不用「>= 0」「< 0」這種區間斷言，而是把整條鏈（timer → 提示×N →
  # answer → ready → attack 擊敗 → score）跑在 `travel_to` 凍結的時間上，
  # 讓經過秒數變成確定值，再對 6 個分項逐一寫死字面量。重構前後這個檔案的
  # 斷言值必須逐位元相同；只要有任何一個數字需要調整，就代表某處的遊戲行為
  # 被動到了，而不是「測試需要更新」。
  #
  # 三個變體覆蓋 ScoreCalculator 全部三條分支：無職業（基準）、senior
  # （提示不扣分）、celebrity（+100 職業分）。
  class ScoringGoldenTest < ActionDispatch::IntegrationTest
    FROZEN_START = Time.utc(2026, 3, 1, 4, 0, 0)
    ELAPSED_SECONDS = 90
    QUESTION_NUMBER = 7
    BASE_SCORE = 1000
    BOSS_HP = 3
    HINTS_USED = 2

    test "golden breakdown: no job on the team" do
      team = play_full_chain

      assert_golden_entry(
        team,
        question_score: 1000,
        time_score: -90,
        hint_score: -100,
        boss_score: 666,
        job_score: 0,
        total_score: 1476
      )
    end

    test "golden breakdown: senior on the team makes hints free" do
      team = play_full_chain(job: :senior)

      assert_golden_entry(
        team,
        question_score: 1000,
        time_score: -90,
        hint_score: 0,
        boss_score: 666,
        job_score: 0,
        total_score: 1576
      )
    end

    test "golden breakdown: celebrity on the team adds the job bonus" do
      team = play_full_chain(job: :celebrity)

      assert_golden_entry(
        team,
        question_score: 1000,
        time_score: -90,
        hint_score: -100,
        boss_score: 666,
        job_score: 100,
        total_score: 1576
      )
    end

    private

    # Plays the whole chain on a one-player team so the boss "ready" gate is
    # satisfied by a single click, with wall-clock time pinned to exactly two
    # instants: everything before the answer happens at FROZEN_START, and the
    # answer/boss fight/settlement all happen ELAPSED_SECONDS later. That
    # makes `QuestionAttempt#elapsed_seconds` — the only input to the score
    # that would otherwise be wall-clock dependent — exactly ELAPSED_SECONDS.
    def play_full_chain(job: nil)
      team = create_team
      sign_in_leader(team, job: job)
      seed_golden_question

      travel_to FROZEN_START do
        post timer_game_question_path(QUESTION_NUMBER)
        HINTS_USED.times { post hints_game_question_path(QUESTION_NUMBER) }

        attempt = team.question_attempts.sole
        assert_equal HINTS_USED, attempt.hint_count
      end

      travel_to FROZEN_START + ELAPSED_SECONDS.seconds do
        post answer_game_question_path(QUESTION_NUMBER), params: { answer: "golden" }
        assert_redirected_to game_boss_path(QUESTION_NUMBER)

        post ready_game_boss_path(QUESTION_NUMBER)
        BOSS_HP.times { post attacks_game_boss_path(QUESTION_NUMBER) }

        post game_score_path
      end

      team
    end

    def assert_golden_entry(team, **expected)
      assert_equal 1, team.score_entries.count
      entry = team.score_entries.sole

      expected.each do |component, value|
        assert_equal value, entry.public_send(component),
                     "#{component} drifted — the scoring chain changed behavior"
      end
    end

    def create_team
      Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: true)
    end

    def sign_in_leader(team, job: nil)
      post game_session_path,
           params: { serial_no: team.serial_no, role: "leader", email: "leader@example.com", gender: "male" }
      player = team.players.find_by!(email: "leader@example.com")
      player.update!(job: job) if job
      player
    end

    def seed_golden_question
      question = Question.create!(
        number: QUESTION_NUMBER,
        kind: :quiz,
        title: "黃金值題目",
        content: "黃金值內容",
        level: "1",
        explanation: "黃金值解說",
        base_score: BASE_SCORE,
        boss_hp: BOSS_HP,
        # Long enough that the frozen-time fight can never trip
        # BossesController#expire_if_timed_out!.
        boss_time_limit: 600,
        boss: seed_boss_for(QUESTION_NUMBER),
        answer_digest: Question.digest_for("golden")
      )

      HINTS_USED.times { |i| question.hints.create!(position: i + 1, content: "黃金值提示 #{i + 1}") }

      question
    end
  end
end
