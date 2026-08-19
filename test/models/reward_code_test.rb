require "test_helper"

class RewardCodeTest < ActiveSupport::TestCase
  def seed_pool(count, test_mode: false, prefix: "P")
    count.times { |i| RewardCode.create!(code: "#{prefix}#{SecureRandom.hex(6)}#{i}", test_mode: test_mode) }
  end

  test "rejects duplicate code" do
    RewardCode.create!(code: "DUPCODE", test_mode: false)
    dup = RewardCode.new(code: "DUPCODE", test_mode: false)
    assert_raises(ActiveRecord::RecordInvalid) { dup.save! }
  end

  test "allocate_pair! hands out exactly 2 unclaimed codes" do
    seed_pool(4)
    email = "player@example.com"

    codes = RewardCode.allocate_pair!(email, test_mode: false)

    assert_equal 2, codes.size
    assert codes.all? { |c| c.player_email == email }
    assert codes.all?(&:claimed_at)
  end

  test "allocate_pair! is idempotent for the same email (repeat call returns the same pair)" do
    seed_pool(6)
    email = "player@example.com"

    first_call = RewardCode.allocate_pair!(email, test_mode: false).map(&:id).sort
    second_call = RewardCode.allocate_pair!(email, test_mode: false).map(&:id).sort

    assert_equal first_call, second_call
    assert_equal 2, RewardCode.where(player_email: email).count
  end

  test "allocate_pair! only draws from the matching test_mode pool" do
    seed_pool(2, test_mode: true, prefix: "T")
    seed_pool(2, test_mode: false, prefix: "P")
    email = "player@example.com"

    codes = RewardCode.allocate_pair!(email, test_mode: true)

    assert codes.all?(&:test_mode?)
  end

  test "allocate_pair! raises when the pool is exhausted" do
    seed_pool(1)

    assert_raises(ActiveRecord::RecordNotFound) do
      RewardCode.allocate_pair!("someone@example.com", test_mode: false)
    end

    # The failed allocation must not have partially claimed the single code.
    assert_equal 0, RewardCode.claimed.count
  end
end
