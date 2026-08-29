require "test_helper"

class Admin::TeamsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = Admin.create!(email: "admin-teams-test@example.com", password: "correct-password")
  end

  test "index redirects to login when not authenticated" do
    get admin_teams_path
    assert_redirected_to admin_login_path
  end

  test "show redirects to login when not authenticated" do
    team = Team.create!(serial_no: "TEAMSHOWTEST0001")
    get admin_team_path(team)
    assert_redirected_to admin_login_path
  end

  test "destroy redirects to login when not authenticated" do
    team = Team.create!(serial_no: "TEAMDESTROYAUTH1", test_mode: true)
    delete admin_team_path(team)
    assert_redirected_to admin_login_path
    assert Team.exists?(team.id)
  end

  test "index lists teams with progress and player counts when authenticated" do
    sign_in_as_admin
    team = Team.create!(serial_no: "TEAMINDEXTEST001", name: "隊伍A")
    Player.create!(team: team, role: :leader, email: "leader-index@example.com")

    get admin_teams_path

    assert_response :success
    assert_match team.serial_no, response.body
    assert_match "隊伍A", response.body
  end

  test "index filters by test_mode" do
    sign_in_as_admin
    real_team = Team.create!(serial_no: "TEAMFILTERREAL01", test_mode: false)
    test_team = Team.create!(serial_no: "TEAMFILTERTEST01", test_mode: true)

    get admin_teams_path, params: { test_mode: "true" }

    assert_response :success
    assert_match test_team.serial_no, response.body
    assert_no_match(/#{real_team.serial_no}/, response.body)
  end

  test "show renders masked contact info and never the raw mobile/email" do
    sign_in_as_admin
    team = Team.create!(serial_no: "TEAMSHOWMASK0001")
    Player.create!(team: team, role: :leader, email: "leader-mask@example.com", mobile: "0912345678")

    get admin_team_path(team)

    assert_response :success
    assert_match "09**-***-***", response.body
    assert_no_match(/0912345678/, response.body)
    assert_no_match(/leader-mask@example\.com/, response.body)
    assert_match "l**********@example.com", response.body
  end

  test "destroy is refused for a production (non test_mode) team" do
    sign_in_as_admin
    team = Team.create!(serial_no: "TEAMPRODNODELET1", test_mode: false)

    assert_no_difference "Team.count" do
      delete admin_team_path(team)
    end

    assert_redirected_to admin_teams_path
    assert Team.exists?(team.id)
  end

  test "destroy is refused for a production team even via a direct request bypassing the UI" do
    sign_in_as_admin
    team = Team.create!(serial_no: "TEAMPRODDIRECT01", test_mode: false)

    delete admin_team_path(team), as: :html

    assert Team.exists?(team.id), "production team must survive a direct DELETE"
  end

  test "production team's delete button is not rendered" do
    sign_in_as_admin
    team = Team.create!(serial_no: "TEAMNOBUTTONPROD", test_mode: false)

    get admin_team_path(team)

    assert_response :success
    assert_no_match(/刪除此測試隊伍/, response.body)
  end

  test "destroy removes a test_mode team and all associated records with no orphans left" do
    sign_in_as_admin
    question = Question.create!(
      number: 4, kind: :quiz, title: "第 4 題",
      boss: seed_boss_for(4), answer_digest: Question.digest_for("answer")
    )
    team = Team.create!(serial_no: "TEAMDESTROYTEST1", test_mode: true)
    player = Player.create!(team: team, role: :leader, email: "leader-destroy@example.com")
    attempt = team.question_attempts.create!(question: question, started_at: Time.current, ended_at: Time.current)
    battle = team.boss_battles.create!(question: question, hp: 10)
    team.score_entries.create!(question: question, total_score: 100)
    battle.boss_readies.create!(player: player)

    assert_difference "Team.count", -1 do
      delete admin_team_path(team)
    end

    assert_redirected_to admin_teams_path
    assert_not Player.exists?(player.id)
    assert_not QuestionAttempt.exists?(attempt.id)
    assert_not BossBattle.exists?(battle.id)
    assert_equal 0, ScoreEntry.where(team_id: team.id).count
    assert_equal 0, BossReady.where(boss_battle_id: battle.id).count
  end

  test "destroying a test_mode team releases its allocated reward codes back to the pool" do
    sign_in_as_admin
    team = Team.create!(serial_no: "TEAMDESTROYTEST2", test_mode: true)
    player = Player.create!(team: team, role: :leader, email: "release-me@example.com")
    allocated = RewardCode.create!(code: "RWDRELEASE000001", test_mode: true,
                                   player_email: player.email, claimed_at: Time.current)
    untouched = RewardCode.create!(code: "RWDRELEASE000002", test_mode: true,
                                   player_email: "someone-else@example.com", claimed_at: Time.current)

    delete admin_team_path(team)

    assert_nil allocated.reload.player_email
    assert_nil allocated.claimed_at
    assert_equal "someone-else@example.com", untouched.reload.player_email
  end

  private

  def sign_in_as_admin
    post admin_session_path, params: { email: @admin.email, password: "correct-password" }
  end
end
