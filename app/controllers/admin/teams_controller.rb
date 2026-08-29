# Team management (A3 — docs/ADMIN_CONSOLE_PLAN.md). Destroying a team is
# a real, cascading delete (Team's `dependent: :destroy` associations), so
# it is restricted to `test_mode` teams only: production teams are
# operational data and must never disappear from the back office, even by
# admin mistake — see `#destroy` below.
class Admin::TeamsController < Admin::BaseController
  PER_PAGE = 25

  def index
    scope = filtered_teams
    @total_count = scope.count
    @page = requested_page
    @teams = scope.order(created_at: :desc).offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    @total_pages = [ (@total_count.to_f / PER_PAGE).ceil, 1 ].max
  end

  def show
    @team = Team.find(params[:id])
    @players = @team.players.order(:role, :id)
    @question_attempts = @team.question_attempts.includes(:question).joins(:question).order("questions.number")
    @boss_battles = @team.boss_battles.includes(:question).joins(:question).order("questions.number")
    @score_entries = @team.score_entries.includes(:question).joins(:question).order("questions.number")
    @reward_codes = RewardCode.where(player_email: @players.map(&:email))
  end

  # Only ever allowed for rehearsal/demo teams (`test_mode: true`).
  # Production team data is protected here at the controller layer (not
  # just hidden in the view) so a direct DELETE request against a real
  # team's id is refused the same way the UI refuses to render the button.
  def destroy
    @team = Team.find(params[:id])

    unless @team.test_mode?
      return redirect_to admin_teams_path, alert: "正式隊伍不可刪除，僅限測試模式隊伍"
    end

    serial_no = @team.serial_no
    @team.destroy!
    redirect_to admin_teams_path, notice: "已刪除測試隊伍 #{serial_no}"
  end

  private

  def filtered_teams
    scope = Team.all

    if params[:test_mode].present?
      value = ActiveModel::Type::Boolean.new.cast(params[:test_mode])
      scope = scope.where(test_mode: value) unless value.nil?
    end

    if params[:q].present?
      like = "%#{params[:q].strip}%"
      scope = scope.where("serial_no ILIKE :like OR name ILIKE :like", like: like)
    end

    scope
  end

  def requested_page
    page = params[:page].presence&.to_i || 1
    page < 1 ? 1 : page
  end
end
