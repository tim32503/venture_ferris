require "test_helper"

module Game
  # Full happy-path player entry flow: serial-number login → team naming →
  # job selection (REFACTOR_PLAN.md P2 batch). Error paths and the JSON
  # status contracts live in the sibling test files in this directory.
  class EntryFlowTest < ActionDispatch::IntegrationTest
    def create_team(**attrs)
      Team.create!({ serial_no: SecureRandom.alphanumeric(16), test_mode: true }.merge(attrs))
    end

    def sign_in(team, role:, email:, gender: "male")
      post game_session_path, params: { serial_no: team.serial_no, role: role, email: email, gender: gender }
    end

    test "login page renders with the serial number and role pre-filled" do
      team = create_team

      get game_login_path(sno: team.serial_no, role: "leader")

      assert_response :success
      assert_select "input#serial_no[value=?]", team.serial_no
    end

    test "leader signs in, names the team, then picks a job" do
      team = create_team

      sign_in(team, role: "leader", email: "leader@example.com")
      assert_redirected_to game_team_path
      follow_redirect!
      assert_response :success
      assert_select "form"

      patch game_team_path, params: { name: "勇者隊" }
      assert_redirected_to game_job_path
      follow_redirect!
      assert_response :success

      team.reload
      assert_equal "勇者隊", team.name

      patch game_job_path, params: { job: "uncle" }
      assert_redirected_to game_job_path
      follow_redirect!
      assert_response :success
      assert_match "阿北", response.body

      assert_equal "uncle", team.players.find_by(email: "leader@example.com").job
    end

    test "member cannot name the team even if they try to" do
      team = create_team
      team.players.create!(role: :leader, email: "leader@example.com")

      sign_in(team, role: "member", email: "member1@example.com")
      assert_redirected_to game_team_path

      patch game_team_path, params: { name: "偷偷改名" }
      assert_redirected_to game_team_path
      follow_redirect!
      assert_match "只有隊長", response.body

      assert_nil team.reload.name
    end

    test "teammates cannot both pick the same job" do
      team = create_team
      team.name = "先鋒隊"
      team.save!
      leader = team.players.create!(role: :leader, email: "leader@example.com", job: :uncle)

      sign_in(team, role: "member", email: "member1@example.com")

      patch game_job_path, params: { job: "uncle" }
      assert_redirected_to game_job_path
      follow_redirect!
      assert_match "已經被隊友選走", response.body

      assert_nil team.players.find_by(email: "member1@example.com").job
      assert_equal "uncle", leader.reload.job
    end

    test "re-signing in with the same serial/role/email is idempotent" do
      team = create_team

      sign_in(team, role: "leader", email: "leader@example.com")
      assert_equal 1, team.players.count

      sign_in(team, role: "leader", email: "leader@example.com")
      assert_equal 1, team.players.count
    end

    test "account transfer (sessions#update) moves the signed-in player to a new team/role" do
      old_team = create_team
      new_team = create_team

      sign_in(old_team, role: "leader", email: "leader@example.com")
      assert_equal 1, old_team.players.count

      patch game_session_path, params: { serial_no: new_team.serial_no, role: "member" }
      assert_redirected_to game_team_path

      assert_equal 0, old_team.reload.players.count
      player = new_team.reload.players.find_by(email: "leader@example.com")
      assert player.present?
      assert player.member?
    end
  end
end
