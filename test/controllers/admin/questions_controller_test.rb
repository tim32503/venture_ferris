require "test_helper"

class Admin::QuestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = Admin.create!(email: "admin-questions-test@example.com", password: "correct-password")
  end

  def seed_question(number = 3, answer: "answer#{number}")
    question = Question.create!(
      number: number, kind: :quiz, title: "第 #{number} 題",
      content: "內容 #{number}", level: "★★☆", explanation: "解說 #{number}",
      boss: seed_boss_for(number), answer_digest: Question.digest_for(answer)
    )
    question.hints.create!(position: 1, content: "提示一")
    question.hints.create!(position: 2, content: "提示二")
    question
  end

  test "index redirects to login when not authenticated" do
    get admin_questions_path
    assert_redirected_to admin_login_path
  end

  test "edit redirects to login when not authenticated" do
    question = seed_question
    get edit_admin_question_path(question)
    assert_redirected_to admin_login_path
  end

  test "update redirects to login when not authenticated" do
    question = seed_question
    patch admin_question_path(question), params: { question: { title: "改標題" } }
    assert_redirected_to admin_login_path
    assert_not_equal "改標題", question.reload.title
  end

  test "index lists all questions when authenticated" do
    sign_in_as_admin
    question = seed_question(5)

    get admin_questions_path

    assert_response :success
    assert_match question.title, response.body
  end

  test "edit renders the form without leaking the answer digest or plaintext" do
    sign_in_as_admin
    question = seed_question(3, answer: "STARWARS")

    get edit_admin_question_path(question)

    assert_response :success
    assert_no_match(/STARWARS/i, response.body)
    assert_no_match(/#{question.answer_digest}/, response.body)
  end

  test "update changes title/content/level/explanation/boss params" do
    sign_in_as_admin
    question = seed_question(4)

    patch admin_question_path(question), params: {
      question: {
        title: "新標題", content: "新內容", level: "★★★★", explanation: "新解說",
        boss_hp: 200, boss_time_limit: 45
      }
    }

    assert_redirected_to edit_admin_question_path(question)
    question.reload
    assert_equal "新標題", question.title
    assert_equal "新內容", question.content
    assert_equal "★★★★", question.level
    assert_equal "新解說", question.explanation
    assert_equal 200, question.boss_hp
    assert_equal 45, question.boss_time_limit
  end

  test "update resets the answer digest when new_answer is present" do
    sign_in_as_admin
    question = seed_question(3, answer: "OLDANSWER")
    old_digest = question.answer_digest

    patch admin_question_path(question), params: { question: { new_answer: "NEWANSWER" } }

    assert_redirected_to edit_admin_question_path(question)
    question.reload
    assert_equal Question.digest_for("NEWANSWER"), question.answer_digest
    assert_not_equal old_digest, question.answer_digest
    assert question.answer?("NEWANSWER")
    assert_not question.answer?("OLDANSWER")
  end

  test "update leaves the answer digest unchanged when new_answer is blank" do
    sign_in_as_admin
    question = seed_question(3, answer: "KEEPME")
    old_digest = question.answer_digest

    patch admin_question_path(question), params: { question: { title: "只改標題", new_answer: "" } }

    question.reload
    assert_equal old_digest, question.answer_digest
    assert question.answer?("KEEPME")
  end

  test "update response never contains the new plaintext answer or any digest" do
    sign_in_as_admin
    question = seed_question(3, answer: "OLDANSWER")

    patch admin_question_path(question), params: { question: { new_answer: "BRANDNEWSECRET" } }
    follow_redirect!

    assert_response :success
    assert_no_match(/BRANDNEWSECRET/i, response.body)
    assert_no_match(/#{question.reload.answer_digest}/, response.body)
  end

  test "update cannot mass-assign answer_digest directly" do
    sign_in_as_admin
    question = seed_question(3, answer: "SAFEANSWER")
    old_digest = question.answer_digest

    patch admin_question_path(question), params: { question: { answer_digest: "hijacked-digest" } }

    question.reload
    assert_equal old_digest, question.answer_digest
  end

  test "update can add, edit, reorder, and delete hints" do
    sign_in_as_admin
    question = seed_question(6)
    first_hint = question.hints.find_by!(position: 1)
    second_hint = question.hints.find_by!(position: 2)

    patch admin_question_path(question), params: {
      question: {
        hints_attributes: {
          "0" => { id: first_hint.id, content: "更新後的提示一", position: 1 },
          "1" => { id: second_hint.id, _destroy: "1" },
          "2" => { content: "全新提示", position: 3 }
        }
      }
    }

    assert_redirected_to edit_admin_question_path(question)
    question.reload
    assert_equal 2, question.hints.count
    assert_equal "更新後的提示一", question.hints.find_by(position: 1).content
    assert_not QuestionHint.exists?(second_hint.id)
    assert_equal "全新提示", question.hints.find_by(position: 3).content
  end

  private

  def sign_in_as_admin
    post admin_session_path, params: { email: @admin.email, password: "correct-password" }
  end
end
