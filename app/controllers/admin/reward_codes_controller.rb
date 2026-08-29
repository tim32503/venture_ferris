# Reward-code pool management (A5 — docs/ADMIN_CONSOLE_PLAN.md). Batch
# generation mirrors Admin::SerialCodesController's pattern exactly
# (insert_all + collision retry) — this closes the gap noted in the plan:
# "現況只有隊伍序號產生器".
class Admin::RewardCodesController < Admin::BaseController
  DEFAULT_COUNT = 50
  MAX_COUNT = 500
  MAX_GENERATION_ATTEMPTS = 5
  CODE_CHARSET = ("A".."Z").to_a + ("0".."9").to_a
  CODE_LENGTH = 12
  INDEX_LIMIT = 200

  def index
    @real_available_count = RewardCode.available.where(test_mode: false).count
    @real_claimed_count = RewardCode.claimed.where(test_mode: false).count
    @test_available_count = RewardCode.available.where(test_mode: true).count
    @test_claimed_count = RewardCode.claimed.where(test_mode: true).count

    @reward_codes = filtered_reward_codes.order(created_at: :desc).limit(INDEX_LIMIT)
  end

  def create
    count = requested_count
    test_mode = requested_test_mode

    insert_reward_codes(count, test_mode)

    redirect_to admin_reward_codes_path, notice: "已產生 #{count} 筆兌獎序號"
  end

  private

  def filtered_reward_codes
    scope = RewardCode.all
    return scope if params[:email].blank?

    scope.where("player_email ILIKE ?", "%#{params[:email].strip}%")
  end

  def requested_count
    value = params[:count].presence&.to_i || DEFAULT_COUNT
    value = DEFAULT_COUNT if value <= 0
    value.clamp(1, MAX_COUNT)
  end

  def requested_test_mode
    ActiveModel::Type::Boolean.new.cast(params[:test_mode]) || false
  end

  # Same collision-retry shape as Admin::SerialCodesController#insert_serial_codes.
  def insert_reward_codes(count, test_mode)
    attempts = 0

    begin
      RewardCode.insert_all!(build_rows(count, test_mode))
    rescue ActiveRecord::RecordNotUnique
      attempts += 1
      raise if attempts >= MAX_GENERATION_ATTEMPTS

      retry
    end
  end

  def build_rows(count, test_mode)
    now = Time.current

    generate_unique_codes(count).map do |code|
      { code: code, test_mode: test_mode, created_at: now, updated_at: now }
    end
  end

  def generate_unique_codes(count)
    existing = RewardCode.pluck(:code).to_set
    generated = Set.new

    while generated.size < count
      candidate = random_code
      next if existing.include?(candidate) || generated.include?(candidate)

      generated << candidate
    end

    generated.to_a
  end

  def random_code
    Array.new(CODE_LENGTH) { CODE_CHARSET.sample }.join
  end
end
