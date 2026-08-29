# One boss fight per question, via a declared `question_id` foreign key
# (docs/SCHEMA_REDESIGN.md §2-1 replaced the old bare `boss_no` integer, which
# shared numbering with `Question#number` but had nothing enforcing it).
# `ended_at` NULL means the fight is still in progress. Victory threshold is
# `attack_count >= hp`.
#
# Keyed on the question rather than on the monster on purpose: questions 10
# and 11 are two fights against the same `Boss`, so a team has two rows here
# pointing at one `bosses` row.
class BossBattle < ApplicationRecord
  belongs_to :team
  belongs_to :question
  has_many :boss_readies, dependent: :destroy
  has_many :boss_skill_uses, dependent: :destroy

  # Anti-cheat throttle for the client-claimed `critical` attack param
  # (Game::BossesController#attacks). The client decides *when* a weak-point
  # target is on screen and reports whether a given click landed on one, so
  # the server cannot trust that claim outright — it only honors one
  # critical per this many seconds, matched to the front end's own weak-point
  # reappearance cadence (boss_poll_controller.js). A claimed critical inside
  # the throttle window is scored as a normal attack instead of rejected
  # outright, so a spammed/faked client never loses attacks, just the bonus
  # damage.
  #
  # 罔美 (celebrity)'s 聚光燈 active skill (docs/JOB_SKILLS_DESIGN.md) is the
  # one deliberate exception to this gate: `critical_ready?` skips the
  # throttle entirely while `spotlight_active?` — see both methods below.
  CRITICAL_THROTTLE_SECONDS = 2

  # Active-skill constants (docs/JOB_SKILLS_DESIGN.md). Kept here rather than
  # in the controller so BossBattle-level tests can exercise the effects
  # directly without going through a request.
  UNCLE_SKILL_BONUS_SECONDS = 10
  NETIZEN_SKILL_DAMAGE = 5
  SPOTLIGHT_SECONDS = 5

  validates :question_id, uniqueness: { scope: :team_id }
  validates :attack_count, numericality: { greater_than_or_equal_to: 0 }
  validates :hp, numericality: { greater_than: 0 }
  validates :bonus_time_seconds, numericality: { greater_than_or_equal_to: 0 }

  scope :completed, -> { where.not(ended_at: nil) }
  scope :in_progress, -> { where(ended_at: nil) }

  def defeated?
    attack_count >= hp
  end

  # Whether a critical claimed `at` would be accepted right now (does not
  # mutate `last_critical_at` — the caller applies that once it decides to
  # honor the critical). 罔美's 聚光燈 skill bypasses the throttle outright
  # while its window is open — this only removes the *gate*, the client
  # still has to actually claim a critical (i.e. land the weak-point click)
  # for one to be scored.
  def critical_ready?(at = Time.current)
    return true if spotlight_active?(at)

    last_critical_at.blank? || at - last_critical_at >= CRITICAL_THROTTLE_SECONDS
  end

  # Whether 罔美's 聚光燈 window is currently open.
  def spotlight_active?(at = Time.current)
    spotlight_until.present? && at < spotlight_until
  end

  def ready_count
    boss_readies.count
  end

  def hp_percent
    remaining = [ hp - attack_count, 0 ].max
    (remaining / hp.to_f * 100).round(2)
  end
end
