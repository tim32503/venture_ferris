# Periodic cleanup for the public "Demo" entry point (README「部署待辦」):
# every homepage Demo click leaves behind a `test_mode` Team + Player row
# (Game::SessionsController#create_demo!) that nobody ever comes back to
# delete. Meant to run on a schedule (e.g. hourly via cron — see the README
# for the exact line), not by hand.
namespace :demo do
  desc "Delete test_mode teams older than DEMO_CLEANUP_HOURS (default 24), releasing their reward codes"
  task cleanup: :environment do
    hours = Integer(ENV.fetch("DEMO_CLEANUP_HOURS", 24))
    cutoff = hours.hours.ago

    # `Team::DEMO_SERIAL_NO` is the fixed seeded demo team the homepage's
    # "Demo" *link text* references in docs/screenshots — unlike every other
    # test_mode team it is meant to live forever, so it is excluded by
    # serial number regardless of age.
    stale_teams = Team.where(test_mode: true)
                       .where.not(serial_no: Team::DEMO_SERIAL_NO)
                       .where(created_at: ...cutoff)

    count = stale_teams.count
    stale_teams.find_each(&:purge_with_reward_release!)

    puts "已刪除 #{count} 個超過 #{hours} 小時的測試隊伍（DEMO_SERIAL_NO 展示隊伍已排除，兌獎序號已釋回池中）"
  end
end
