require "application_system_test_case"

# Verifies clicking the monster on the boss page actually updates the DOM
# (REFACTOR_PLAN.md P4 acceptance: "boss 頁點擊攻擊 DOM 更新", extended by the
# hit-feedback batch to attack the monster's own sprite instead of a
# separate "攻擊！" button). Attacks are sent via `fetch()` from
# boss_poll_controller.js#attack (not a Turbo-intercepted form submit — see
# that controller's file comment for why), and the attack_count/HP shown on
# the page come back from the same 500ms status poll used everywhere else in
# this app, so this also exercises that round trip.
class GameBossPageTest < ApplicationSystemTestCase
  test "clicking the monster updates the attack count and plays hit feedback" do
    team = Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: true)
    question = Question.create!(
      number: 1, kind: :quiz, title: "示範魔王戰", content: "示範內容", level: "1",
      explanation: "示範解說", boss_hp: 3, boss_time_limit: 60,
      boss: seed_boss_for(1),
      answer_digest: Question.digest_for("answer1")
    )

    visit game_login_path(sno: team.serial_no, role: "leader")
    fill_in "email", with: "leader@example.com"
    click_on "進入遊戲"
    assert_current_path game_team_path

    visit game_boss_path(question.number)
    click_on "宣戰！準備攻擊"

    # Solo team of 1: readying alone already meets "everyone ready", so the
    # fight starts immediately and this is now the battle screen.
    assert_selector "[data-boss-poll-target='attackCount']", text: "0"

    find("[data-boss-poll-target='monster']").click
    assert_selector "[data-boss-poll-target='attackCount']", text: "1"
    assert_selector ".dmg-number", text: "+1"

    find("[data-boss-poll-target='monster']").click
    assert_selector "[data-boss-poll-target='attackCount']", text: "2"
  end

  test "hitting a forced weak point scores a critical and shows a doubled damage number" do
    team = Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: true)
    question = Question.create!(
      number: 2, kind: :quiz, title: "示範魔王戰二", content: "示範內容", level: "1",
      explanation: "示範解說", boss_hp: 10, boss_time_limit: 60,
      boss: seed_boss_for(2),
      answer_digest: Question.digest_for("answer2")
    )

    visit game_login_path(sno: team.serial_no, role: "leader")
    fill_in "email", with: "leader@example.com"
    click_on "進入遊戲"
    assert_current_path game_team_path

    visit game_boss_path(question.number)
    click_on "宣戰！準備攻擊"
    assert_selector "[data-boss-poll-target='attackCount']", text: "0"

    # The weak point's own spawn schedule is randomized (boss_poll_controller.js
    # scheduleWeakPoint), which a system test can't reliably wait on. Reach
    # the live Stimulus controller instance (exposed globally as
    # `window.Stimulus` by controllers/application.js) and call the
    # dedicated test hook to force one to appear immediately at a known,
    # clickable position instead.
    page.execute_script(<<~JS)
      const el = document.querySelector('[data-controller~="boss-poll"]')
      const controller = window.Stimulus.getControllerForElementAndIdentifier(el, "boss-poll")
      controller.forceWeakPointForTest()
    JS

    assert_selector ".weak-point"
    find(".weak-point").click

    assert_selector "[data-boss-poll-target='attackCount']", text: "2"
    assert_selector ".dmg-number.crit", text: "+2"
  end

  test "the monster button is keyboard-activatable" do
    team = Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: true)
    question = Question.create!(
      number: 3, kind: :quiz, title: "示範魔王戰三", content: "示範內容", level: "1",
      explanation: "示範解說", boss_hp: 5, boss_time_limit: 60,
      boss: seed_boss_for(3),
      answer_digest: Question.digest_for("answer3")
    )

    visit game_login_path(sno: team.serial_no, role: "leader")
    fill_in "email", with: "leader@example.com"
    click_on "進入遊戲"
    assert_current_path game_team_path

    visit game_boss_path(question.number)
    click_on "宣戰！準備攻擊"
    assert_selector "[data-boss-poll-target='attackCount']", text: "0"

    # The monster is a real <button> (see show.html.erb), so Enter/Space
    # activation comes from the browser for free — no custom keydown
    # handler needed in boss_poll_controller.js. `.native.send_keys` goes
    # through the browser driver's real key-event path (unlike a raw
    # `execute_script`-dispatched KeyboardEvent, which wouldn't exercise the
    # browser's own button-activation behavior).
    find("[data-boss-poll-target='monster']").native.send_keys(:enter)
    assert_selector "[data-boss-poll-target='attackCount']", text: "1"
  end

  test "the skill card shows the player's job skill and disables after one use" do
    team = Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: true)
    question = Question.create!(
      number: 4, kind: :quiz, title: "示範魔王戰四", content: "示範內容", level: "1",
      explanation: "示範解說", boss_hp: 100, boss_time_limit: 60,
      boss: seed_boss_for(4),
      answer_digest: Question.digest_for("answer4")
    )

    visit game_login_path(sno: team.serial_no, role: "leader")
    fill_in "email", with: "leader@example.com"
    click_on "進入遊戲"
    assert_current_path game_team_path

    team.players.find_by!(email: "leader@example.com").update!(job: :uncle)

    visit game_boss_path(question.number)
    click_on "宣戰！準備攻擊"
    assert_selector "[data-boss-poll-target='attackCount']", text: "0"

    assert_selector "[data-boss-poll-target='skillCard']", text: "倚老賣老"
    skill_button = find("[data-boss-poll-target='skillButton']")
    assert_not skill_button.disabled?
    assert_selector "[data-boss-poll-target='skillButtonLabel']", text: "發動技能"

    skill_button.click

    assert_selector "[data-boss-poll-target='skillButtonLabel']", text: "已使用"
    assert find("[data-boss-poll-target='skillButton']").disabled?
  end
end
