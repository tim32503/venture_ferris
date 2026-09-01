# A Team is identified by a 16-character serial number scanned at check-in.
# `test_mode` mirrors the legacy `SERIAL_TYPE` flag: it does not change any
# game rules, it only marks the team as a rehearsal/demo run.
class Team < ApplicationRecord
  SERIAL_NO_LENGTH = 16
  # Fixed serial number for the portfolio "Demo" entry point (see
  # db/seeds.rb and app/views/welcome/index.html.erb) — a single source of
  # truth so the homepage link and the seeded demo team never drift apart.
  DEMO_SERIAL_NO = "DEMO000000000001"
  # Legacy game has 11 questions total; solving 9 of them unlocks the third
  # (final) map — see REFACTOR_PLAN.md §1.1 `Team#current_map`.
  FINAL_MAP_SOLVED_THRESHOLD = 9
  FINAL_MAP_NUMBER = 3
  FIRST_MAP_NUMBER = 1

  has_many :players, dependent: :destroy
  has_many :question_attempts, dependent: :destroy
  has_many :boss_battles, dependent: :destroy
  has_many :score_entries, dependent: :destroy

  validates :serial_no, presence: true,
                         length: { is: SERIAL_NO_LENGTH },
                         uniqueness: true
  validates :test_mode, inclusion: { in: [ true, false ] }

  # Only completed attempts (ended_at present) count toward progress.
  def solved_count
    question_attempts.completed.count
  end

  def current_map
    solved_count >= FINAL_MAP_SOLVED_THRESHOLD ? FINAL_MAP_NUMBER : FIRST_MAP_NUMBER
  end

  # The team-wide "someone is timing a question right now" attempt, if any
  # (REFACTOR_PLAN.md P3: replaces the legacy server-side long-poll
  # `questionIsStart()` — a teammate elsewhere starting a question's timer
  # is what the home/map pages poll for so everyone gets redirected there).
  # `started_at` present + `ended_at` nil is the in-progress signal; a row
  # can exist with `started_at` nil (e.g. a hint was used before the timer
  # was ever started) and must not count as "active".
  def active_question_attempt
    question_attempts.in_progress.where.not(started_at: nil).order(started_at: :desc).first
  end

  # The team-wide "a boss fight is currently underway" battle, if any
  # (REFACTOR_PLAN.md P4: connects the `active_question_poll_controller.js`
  # extension point the P3 batch reserved — a teammate whose boss fight has
  # started is what the home page's poll now also redirects everyone else
  # on the team toward). Mirrors `active_question_attempt`'s shape.
  def active_boss_battle
    boss_battles.includes(:question)
                .where.not(started_at: nil).where(ended_at: nil)
                .order(started_at: :desc).first
  end

  # Question numbers this team has completed, low-to-high. Used to show a
  # simple "已完成關卡" summary on the map pages — the legacy map views
  # (wheel_map1/2/3.php) have no such list at all (only wheel_record.php
  # does, which is P4 scope), so this is a small UX addition rather than a
  # port of existing behavior.
  def completed_question_numbers
    question_attempts.completed.joins(:question).order("questions.number").pluck("questions.number")
  end

  # Question numbers whose boss fight this team has actually defeated
  # (`boss_battles.ended_at` present), low-to-high. Deliberately distinct
  # from `completed_question_numbers` above: that one flips as soon as the
  # question's own answer is correct, *before* its boss fight even starts,
  # so it isn't precise enough for a hotspot that specifically stands in for
  # "this boss is defeated and there's nowhere to go" (Game::MapsController
  # ::AREAS' map3 Q11 fallback — gating on the weaker signal would let a
  # team reach Q11 without ever having fought boss 10 at all).
  def defeated_boss_numbers
    boss_battles.completed.joins(:question).order("questions.number").pluck("questions.number")
  end

  # Destroys this team and releases any reward codes its players had
  # claimed back to the pool. Shared by Admin::TeamsController#destroy (an
  # operator deleting one team by hand) and `rails demo:cleanup`
  # (lib/tasks/demo_cleanup.rake, batch-deleting stale demo teams) so the
  # "delete + release" behavior can never drift between the two callers.
  #
  # Reward codes are keyed by player email (a deliberate denormalization,
  # see docs/SCHEMA_REDESIGN.md §5), so destroying the team would otherwise
  # leave its allocated codes permanently drained from the pool.
  #
  # Only ever safe for `test_mode` teams — both callers are already
  # restricted to test_mode teams at their own layer (the admin controller
  # refuses non-test_mode ids before calling this; the cleanup rake task
  # only ever queries `test_mode: true`), but the guard is repeated here so
  # a future caller cannot accidentally destroy production data.
  def purge_with_reward_release!
    raise ArgumentError, "refusing to purge a non-test_mode team (id=#{id})" unless test_mode?

    member_emails = players.pluck(:email)
    self.class.transaction do
      destroy!
      RewardCode.where(player_email: member_emails).update_all(player_email: nil, claimed_at: nil)
    end
  end
end
