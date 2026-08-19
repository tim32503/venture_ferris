class Admin::DashboardController < Admin::BaseController
  def show
    @team_count = Team.count
    @player_count = Player.count
    @claimed_reward_code_count = RewardCode.claimed.count
  end
end
