# Pool of prize-redemption codes. `test_mode` mirrors the legacy REWARD_TYPE
# flag (rehearsal pool vs. real pool). `player_email` is nil until allocated;
# allocation is keyed by email (not by team/session) so that a player who
# re-enters with a different serial number still gets back the same pair —
# matching the legacy semantics described in REFACTOR_PLAN.md §1.1.
class RewardCode < ApplicationRecord
  PAIR_SIZE = 2

  validates :code, presence: true, uniqueness: true
  validates :test_mode, inclusion: { in: [ true, false ] }

  scope :available, -> { where(player_email: nil) }
  scope :claimed, -> { where.not(player_email: nil) }

  # Atomically allocates exactly PAIR_SIZE reward codes to `email`. If the
  # email already has codes allocated, returns those unchanged (idempotent —
  # repeated calls for the same email never allocate more than PAIR_SIZE).
  # Uses `FOR UPDATE SKIP LOCKED` so concurrent requests never race for the
  # same rows.
  def self.allocate_pair!(email, test_mode: false)
    transaction do
      existing = where(player_email: email).order(:id).to_a
      return existing if existing.size >= PAIR_SIZE

      needed = PAIR_SIZE - existing.size
      candidates = available.where(test_mode: test_mode)
                             .order(:id)
                             .lock("FOR UPDATE SKIP LOCKED")
                             .limit(needed)
                             .to_a

      if candidates.size < needed
        raise ActiveRecord::RecordNotFound, "reward code pool exhausted for test_mode=#{test_mode}"
      end

      now = Time.current
      candidates.each { |reward_code| reward_code.update!(player_email: email, claimed_at: now) }

      existing + candidates
    end
  end
end
