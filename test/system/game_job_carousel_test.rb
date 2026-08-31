require "application_system_test_case"

# Verifies the job-selection carousel, now CSS scroll-snap driven by
# carousel_controller.js, actually shows all four job cards and that the
# next arrow advances the active indicator dot (U2 batch: replaces
# Bootstrap 4's jQuery-backed Carousel — see
# docs/UI_MODERNIZATION_PLAN.md decision 2's carousel row).
class GameJobCarouselTest < ApplicationSystemTestCase
  test "all job cards are present, and the next arrow advances the active dot" do
    team = Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: true, name: "測試隊")

    visit game_login_path(sno: team.serial_no, role: "leader")
    fill_in "email", with: "leader@example.com"
    click_on "進入遊戲"
    assert_current_path game_team_path

    visit game_job_path

    assert_selector "[data-carousel-target='slide']", count: Player.jobs.keys.size
    assert_selector "[data-carousel-target='indicator']", count: Player.jobs.keys.size

    dots = all("[data-carousel-target='indicator']")
    assert dots[0][:class].include?("active")
    assert_not dots[1][:class].include?("active")

    find(".job-carousel-control.next").click

    assert dots[1].matches_css?(".active", wait: 5)

    # The active dot flips mid-animation (scroll-behavior: smooth), right as
    # the second slide's center crosses the track's center — so a screenshot
    # taken the instant the assertion above passes would still show both
    # slides half-scrolled. Wait for the track's scrollLeft to stop moving
    # before capturing the "settled on slide 2" reference screenshot asked
    # for in the acceptance checklist.
    previous_scroll_left = nil
    Timeout.timeout(3) do
      loop do
        current_scroll_left = evaluate_script("document.querySelector('.job-carousel-track').scrollLeft")
        break if current_scroll_left == previous_scroll_left

        previous_scroll_left = current_scroll_left
        sleep 0.1
      end
    end
    save_screenshot(Rails.root.join("tmp", "u2_job_carousel_second_slide.png").to_s)

    assert dots[1][:class].include?("active")
    assert_not dots[0][:class].include?("active")
  end
end
