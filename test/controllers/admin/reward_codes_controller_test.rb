require "test_helper"

class Admin::RewardCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = Admin.create!(email: "admin-reward-codes-test@example.com", password: "correct-password")
  end

  test "index redirects to login when not authenticated" do
    get admin_reward_codes_path
    assert_redirected_to admin_login_path
  end

  test "create redirects to login when not authenticated" do
    assert_no_difference "RewardCode.count" do
      post admin_reward_codes_path, params: { count: 5 }
    end
    assert_redirected_to admin_login_path
  end

  test "index shows pool stats and masks claimed player emails" do
    sign_in_as_admin
    RewardCode.create!(code: "RCTESTAVAILABLE1", test_mode: false)
    RewardCode.create!(code: "RCTESTCLAIMED001", test_mode: false,
                        player_email: "claimant@example.com", claimed_at: Time.current)

    get admin_reward_codes_path

    assert_response :success
    assert_no_match(/claimant@example\.com/, response.body)
    assert_match "c*******@example.com", response.body
  end

  test "index filters by email" do
    sign_in_as_admin
    RewardCode.create!(code: "RCFINDMEEMAIL001", test_mode: false,
                        player_email: "findme@example.com", claimed_at: Time.current)
    RewardCode.create!(code: "RCOTHEREMAIL0001", test_mode: false,
                        player_email: "other@example.com", claimed_at: Time.current)

    get admin_reward_codes_path, params: { email: "findme" }

    assert_response :success
    assert_match "RCFINDMEEMAIL001", response.body
    assert_no_match(/RCOTHEREMAIL0001/, response.body)
  end

  test "create writes the requested number of unique codes" do
    sign_in_as_admin

    assert_difference "RewardCode.count", 5 do
      post admin_reward_codes_path, params: { count: 5, test_mode: "1" }
    end

    assert_redirected_to admin_reward_codes_path
    new_codes = RewardCode.order(created_at: :desc).limit(5)
    assert_equal 5, new_codes.map(&:code).uniq.size
    assert new_codes.all?(&:test_mode?)
  end

  test "create defaults to 50 when count is not given" do
    sign_in_as_admin

    assert_difference "RewardCode.count", Admin::RewardCodesController::DEFAULT_COUNT do
      post admin_reward_codes_path
    end
  end

  test "create clamps an excessive count to the maximum" do
    sign_in_as_admin

    assert_difference "RewardCode.count", Admin::RewardCodesController::MAX_COUNT do
      post admin_reward_codes_path, params: { count: 999_999 }
    end
  end

  private

  def sign_in_as_admin
    post admin_session_path, params: { email: @admin.email, password: "correct-password" }
  end
end
