require "test_helper"

# Covers the read-only "viewer" admin role (portfolio showcase account):
# server-side write blocking in Admin::BaseController#block_viewer_writes,
# the read-only banner, per-view hidden write controls, and that the
# regular "operator" role is completely unaffected.
class AdminViewerRoleTest < ActionDispatch::IntegrationTest
  setup do
    @operator = Admin.create!(email: "operator-role-test@example.com", password: "correct-password", role: :operator)
    @viewer = Admin.create!(email: "viewer-role-test@example.com", password: "correct-password", role: :viewer)
  end

  # ---------------------------------------------------------------------
  # Viewer: every back-office page is readable, and the read-only banner
  # renders on all of them.
  # ---------------------------------------------------------------------

  test "viewer can GET every back-office page and sees the read-only banner" do
    sign_in_as(@viewer)

    question = Question.create!(number: 5, kind: :quiz, title: "第 5 題", boss: seed_boss_for(5),
                                 answer_digest: Question.digest_for("answer"))
    team = Team.create!(serial_no: "VIEWERPAGETEST01")

    [
      admin_root_path,
      admin_teams_path,
      admin_team_path(team),
      admin_questions_path,
      edit_admin_question_path(question),
      admin_reward_codes_path,
      admin_serial_codes_path
    ].each do |path|
      get path
      assert_response :success, "expected #{path} to return 200 for a viewer"
      assert_match "展示模式（唯讀）", response.body, "expected read-only banner on #{path}"
    end
  end

  test "operator does not see the read-only banner" do
    sign_in_as(@operator)

    get admin_root_path

    assert_response :success
    assert_no_match "展示模式（唯讀）", response.body
  end

  # ---------------------------------------------------------------------
  # Viewer: write controls are hidden in the view, replaced by a static
  # read-only notice.
  # ---------------------------------------------------------------------

  test "viewer sees the read-only notice instead of the serial code generator form" do
    sign_in_as(@viewer)

    get admin_serial_codes_path

    assert_response :success
    assert_match "唯讀模式不可操作", response.body
    assert_no_match "產生序號", response.body
  end

  test "viewer sees the read-only notice instead of the reward code generator form" do
    sign_in_as(@viewer)

    get admin_reward_codes_path

    assert_response :success
    assert_match "唯讀模式不可操作", response.body
  end

  test "viewer sees the read-only notice instead of the question edit form" do
    sign_in_as(@viewer)
    question = Question.create!(number: 6, kind: :quiz, title: "第 6 題", boss: seed_boss_for(6),
                                 answer_digest: Question.digest_for("answer"))

    get edit_admin_question_path(question)

    assert_response :success
    assert_match "唯讀模式不可操作", response.body
    assert_no_match "儲存變更", response.body
  end

  test "viewer sees the read-only notice instead of the team delete button" do
    sign_in_as(@viewer)
    team = Team.create!(serial_no: "VIEWERNOBUTTON01", test_mode: true)

    get admin_team_path(team)

    assert_response :success
    assert_match "唯讀模式不可操作", response.body
    assert_no_match "刪除此測試隊伍", response.body
  end

  # ---------------------------------------------------------------------
  # Viewer: writes are refused server-side, with zero data changes, even
  # when sent as a direct request (bypassing the UI entirely — CSRF is
  # disabled in the test environment, so this exercises the exact same
  # request a curl-level bypass attempt would make).
  # ---------------------------------------------------------------------

  test "viewer cannot generate serial codes" do
    sign_in_as(@viewer)

    assert_no_difference "Team.count" do
      post admin_serial_codes_path, params: { count: 5 }
    end

    assert_redirected_to admin_root_path
    assert_equal "展示帳號為唯讀模式", flash[:alert]
  end

  test "viewer cannot update a question" do
    sign_in_as(@viewer)
    question = Question.create!(number: 7, kind: :quiz, title: "原標題", boss: seed_boss_for(7),
                                 answer_digest: Question.digest_for("answer"))

    patch admin_question_path(question), params: { question: { title: "被竄改的標題" } }

    assert_redirected_to admin_root_path
    assert_equal "展示帳號為唯讀模式", flash[:alert]
    assert_equal "原標題", question.reload.title
  end

  test "viewer cannot delete a team" do
    sign_in_as(@viewer)
    team = Team.create!(serial_no: "VIEWERDELETEDEN1", test_mode: true)

    assert_no_difference "Team.count" do
      delete admin_team_path(team)
    end

    assert_redirected_to admin_root_path
    assert_equal "展示帳號為唯讀模式", flash[:alert]
    assert Team.exists?(team.id)
  end

  test "viewer cannot generate reward codes" do
    sign_in_as(@viewer)

    assert_no_difference "RewardCode.count" do
      post admin_reward_codes_path, params: { count: 5 }
    end

    assert_redirected_to admin_root_path
    assert_equal "展示帳號為唯讀模式", flash[:alert]
  end

  # ---------------------------------------------------------------------
  # Viewer: login/logout is exempt from the write guard.
  # ---------------------------------------------------------------------

  test "viewer can log in and log out normally" do
    post admin_session_path, params: { email: @viewer.email, password: "correct-password" }
    assert_redirected_to admin_root_path

    get admin_root_path
    assert_response :success

    delete admin_session_path
    assert_redirected_to admin_login_path

    get admin_root_path
    assert_redirected_to admin_login_path
  end

  # ---------------------------------------------------------------------
  # Operator: fully unaffected regression check across all four write
  # endpoints.
  # ---------------------------------------------------------------------

  test "operator writes are unaffected by the viewer guard" do
    sign_in_as(@operator)
    question = Question.create!(number: 8, kind: :quiz, title: "原標題", boss: seed_boss_for(8),
                                 answer_digest: Question.digest_for("answer"))
    team = Team.create!(serial_no: "OPERATORDELETE01", test_mode: true)

    assert_difference "Team.count", 5 do
      post admin_serial_codes_path, params: { count: 5 }
    end
    assert_redirected_to admin_serial_codes_path

    patch admin_question_path(question), params: { question: { title: "已更新標題" } }
    assert_equal "已更新標題", question.reload.title

    assert_difference "RewardCode.count", 5 do
      post admin_reward_codes_path, params: { count: 5 }
    end

    assert_difference "Team.count", -1 do
      delete admin_team_path(team)
    end
  end

  private

  def sign_in_as(admin)
    post admin_session_path, params: { email: admin.email, password: "correct-password" }
  end
end
