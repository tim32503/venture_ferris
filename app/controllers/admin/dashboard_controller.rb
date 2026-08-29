# Operational overview (A2 — docs/ADMIN_CONSOLE_PLAN.md: "既有統計保留；
# 新增：各題完成隊數的進度分布、進行中戰鬥數、已結算隊伍數、兌獎序號池餘量").
# Everything here is a plain read-only aggregate query; no chart library is
# introduced, the progress distribution renders as Tailwind bars in the view.
class Admin::DashboardController < Admin::BaseController
  def show
    @team_count = Team.count
    @player_count = Player.count
    @claimed_reward_code_count = RewardCode.claimed.count

    @question_progress = question_progress
    @active_battle_count = BossBattle.in_progress.count
    @settled_team_count = settled_team_count
    @reward_pool = reward_pool_stats
  end

  private

  # Per-question count of teams that have a completed attempt, in question
  # order — feeds the dashboard's "各題完成隊數" bar chart.
  def question_progress
    completed_counts = QuestionAttempt.completed.group(:question_id).count

    Question.order(:number).map do |question|
      { question: question, completed_count: completed_counts[question.id] || 0 }
    end
  end

  # A team is "settled" once it has a ScoreEntry for every question — i.e.
  # scoring has run to completion for that team (see
  # ScoreEntry.record_pending_for! — it only ever adds rows, one per solved
  # + boss-defeated question).
  def settled_team_count
    total_questions = Question.count
    return 0 if total_questions.zero?

    Team.joins(:score_entries)
        .group("teams.id")
        .having("COUNT(score_entries.id) >= ?", total_questions)
        .count
        .size
  end

  def reward_pool_stats
    {
      real_available: RewardCode.available.where(test_mode: false).count,
      real_claimed: RewardCode.claimed.where(test_mode: false).count,
      test_available: RewardCode.available.where(test_mode: true).count,
      test_claimed: RewardCode.claimed.where(test_mode: true).count
    }
  end
end
