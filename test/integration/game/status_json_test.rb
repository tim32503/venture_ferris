require "test_helper"

module Game
  # JSON contracts polled by the Stimulus controllers (REFACTOR_PLAN.md §2):
  # GET /game/team/status.json => {name, ready, total}
  # GET /game/job/status.json  => {players: [{email, job}], all_selected}
  class StatusJsonTest < ActionDispatch::IntegrationTest
    def create_team(**attrs)
      Team.create!({ serial_no: SecureRandom.alphanumeric(16), test_mode: true }.merge(attrs))
    end

    def sign_in(team, role:, email:)
      post game_session_path, params: { serial_no: team.serial_no, role: role, email: email, gender: "male" }
    end

    test "team status reports name/ready/total and updates once the team is named" do
      team = create_team
      sign_in(team, role: "leader", email: "leader@example.com")

      get game_team_status_path
      body = JSON.parse(response.body)
      assert_equal({ "name" => nil, "ready" => false, "total" => 1 }, body)

      patch game_team_path, params: { name: "先鋒隊" }

      get game_team_status_path
      body = JSON.parse(response.body)
      assert_equal({ "name" => "先鋒隊", "ready" => true, "total" => 1 }, body)
    end

    test "job status lists every teammate's job and flips all_selected once everyone has chosen" do
      team = create_team
      team.update!(name: "先鋒隊")
      sign_in(team, role: "leader", email: "leader@example.com")
      post game_session_path, params: { serial_no: team.serial_no, role: "member", email: "member1@example.com", gender: "female" }

      get game_job_status_path
      body = JSON.parse(response.body)
      assert_equal false, body["all_selected"]
      emails = body["players"].map { |p| p["email"] }
      assert_includes emails, "leader@example.com"
      assert_includes emails, "member1@example.com"
      assert body["players"].all? { |p| p["job"].nil? }

      # Distinct jobs: two teammates may not hold the same one
      # (docs/SCHEMA_REDESIGN.md §2-7b's `[team_id, job]` unique index). What
      # this test is about is `all_selected` flipping once nobody's job is
      # nil, which is unaffected by *which* jobs they picked.
      team.players.order(:id).zip(%w[uncle senior]).each { |player, job| player.update!(job: job) }

      get game_job_status_path
      body = JSON.parse(response.body)
      assert_equal true, body["all_selected"]
    end

    test "job status does not require the request itself to select a job" do
      team = create_team
      sign_in(team, role: "leader", email: "leader@example.com")

      get game_job_status_path, as: :json

      assert_response :success
      body = JSON.parse(response.body)
      assert body.key?("players")
      assert body.key?("all_selected")
    end
  end
end
