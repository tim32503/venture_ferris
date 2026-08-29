# One boss fight per question (`boss_no` shares numbering with
# `Question#number` — REFACTOR_PLAN.md §8-3). `ended_at` NULL means the fight
# is still in progress. Victory threshold is `attack_count >= hp`.
class BossBattle < ApplicationRecord
  belongs_to :team
  has_many :boss_readies, dependent: :destroy

  # Anti-cheat throttle for the client-claimed `critical` attack param
  # (Game::BossesController#attacks). The client decides *when* a weak-point
  # target is on screen and reports whether a given click landed on one, so
  # the server cannot trust that claim outright — it only honors one
  # critical per this many seconds, matched to the front end's own weak-point
  # reappearance cadence (boss_poll_controller.js). A claimed critical inside
  # the throttle window is scored as a normal attack instead of rejected
  # outright, so a spammed/faked client never loses attacks, just the bonus
  # damage.
  CRITICAL_THROTTLE_SECONDS = 2

  validates :boss_no, presence: true, uniqueness: { scope: :team_id }
  validates :attack_count, numericality: { greater_than_or_equal_to: 0 }
  validates :hp, numericality: { greater_than: 0 }

  scope :completed, -> { where.not(ended_at: nil) }
  scope :in_progress, -> { where(ended_at: nil) }

  def defeated?
    attack_count >= hp
  end

  # Whether a critical claimed `at` would be accepted right now (does not
  # mutate `last_critical_at` — the caller applies that once it decides to
  # honor the critical).
  def critical_ready?(at = Time.current)
    last_critical_at.blank? || at - last_critical_at >= CRITICAL_THROTTLE_SECONDS
  end

  def ready_count
    boss_readies.count
  end

  def hp_percent
    remaining = [ hp - attack_count, 0 ].max
    (remaining / hp.to_f * 100).round(2)
  end
end
