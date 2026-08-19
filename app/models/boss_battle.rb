# One boss fight per question (`boss_no` shares numbering with
# `Question#number` — REFACTOR_PLAN.md §8-3). `ended_at` NULL means the fight
# is still in progress. Victory threshold is `attack_count >= hp`.
class BossBattle < ApplicationRecord
  belongs_to :team
  has_many :boss_readies, dependent: :destroy

  validates :boss_no, presence: true, uniqueness: { scope: :team_id }
  validates :attack_count, numericality: { greater_than_or_equal_to: 0 }
  validates :hp, numericality: { greater_than: 0 }

  scope :completed, -> { where.not(ended_at: nil) }
  scope :in_progress, -> { where(ended_at: nil) }

  def defeated?
    attack_count >= hp
  end

  def ready_count
    boss_readies.count
  end

  def hp_percent
    remaining = [ hp - attack_count, 0 ].max
    (remaining / hp.to_f * 100).round(2)
  end
end
