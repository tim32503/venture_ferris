require "test_helper"
require "rake"

# Smoke-tests `rails demo:cleanup` (lib/tasks/demo_cleanup.rake). The actual
# delete + reward-code-release behavior is Team#purge_with_reward_release!,
# already covered directly in test/models/team_test.rb — this file only
# checks the task's own job: picking the right teams (age threshold,
# test_mode only, DEMO_SERIAL_NO excluded) and being safe to run repeatedly.
class DemoCleanupTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("demo:cleanup")
    Rake::Task["demo:cleanup"].reenable
  end

  test "deletes only test_mode teams older than the threshold, sparing fresh teams, production teams, and the seeded demo team" do
    old_team = Team.create!(serial_no: "OLDTESTTEAM00001", test_mode: true, created_at: 25.hours.ago)
    old_player = Player.create!(team: old_team, role: :leader, email: "old-cleanup@example.com")
    old_code = RewardCode.create!(code: "CLEANUPRELEASE01", test_mode: true,
                                   player_email: old_player.email, claimed_at: Time.current)

    fresh_test_team = Team.create!(serial_no: "FRESHTESTTEAM001", test_mode: true, created_at: 1.hour.ago)
    seeded_demo_team = Team.create!(serial_no: Team::DEMO_SERIAL_NO, test_mode: true, created_at: 30.hours.ago)
    old_real_team = Team.create!(serial_no: "REALOLDTEAM00001", test_mode: false, created_at: 30.hours.ago)

    assert_output(/已刪除 1 個/) { Rake::Task["demo:cleanup"].invoke }

    assert_not Team.exists?(old_team.id), "team past the 24h threshold should be deleted"
    assert_nil old_code.reload.player_email, "its reward code should be released back to the pool"
    assert_nil old_code.claimed_at

    assert Team.exists?(fresh_test_team.id), "team within the threshold must survive"
    assert Team.exists?(seeded_demo_team.id), "the seeded DEMO_SERIAL_NO team must never be swept up"
    assert Team.exists?(old_real_team.id), "non-test_mode teams must never be deleted"
  end

  test "respects DEMO_CLEANUP_HOURS" do
    Team.create!(serial_no: "TENHOURSOLDTEAM1", test_mode: true, created_at: 10.hours.ago)

    original = ENV["DEMO_CLEANUP_HOURS"]
    ENV["DEMO_CLEANUP_HOURS"] = "5"
    assert_output(/已刪除 1 個/) { Rake::Task["demo:cleanup"].invoke }
  ensure
    ENV["DEMO_CLEANUP_HOURS"] = original
  end

  test "is idempotent -- a second run finds nothing left to delete" do
    Team.create!(serial_no: "OLDTESTTEAM00002", test_mode: true, created_at: 25.hours.ago)

    Rake::Task["demo:cleanup"].invoke
    Rake::Task["demo:cleanup"].reenable

    assert_output(/已刪除 0 個/) { Rake::Task["demo:cleanup"].invoke }
  end
end
