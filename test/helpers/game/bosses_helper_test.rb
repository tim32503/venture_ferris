require "test_helper"

module Game
  # Boss sprite + phase-label mapping. The facts under test are unchanged from
  # when this lived in three pure helper methods (boss #10 has no sprite of
  # its own and must resolve to mon11's asset/positioning with a "phase 1"
  # modifier; boss #11 stays as it was; every other boss is untouched) — what
  # changed is where they come from: `questions.boss_id` + `questions.boss_phase`
  # instead of `number == 10 ? 11 : number` restated three times
  # (docs/SCHEMA_REDESIGN.md §2-3). The expectations below are deliberately
  # identical to the pre-refactor ones.
  class BossesHelperTest < ActionView::TestCase
    include Game::BossesHelper

    def build_question(number, sprite:, phase: nil)
      Question.create!(
        number: number, kind: :quiz, title: "第 #{number} 題",
        boss: Boss.find_or_create_by!(sprite: sprite),
        boss_phase: phase,
        answer_digest: Question.digest_for("a#{number}")
      )
    end

    test "boss 10 resolves to mon11's sprite" do
      question = build_question(10, sprite: "mon11", phase: 1)

      assert_equal "mon11", question.boss.sprite
      assert_equal "mon11.gif", boss_image_filename(question)
    end

    test "boss 10 gets mon11's positioning class plus the phase-1 modifier" do
      question = build_question(10, sprite: "mon11", phase: 1)

      assert_equal "mon11 boss-phase-1", boss_sprite_css_classes(question)
    end

    test "boss 10's phase label is 第一型態" do
      question = build_question(10, sprite: "mon11", phase: 1)

      assert_equal "魔王・第一型態", boss_phase_label(question)
    end

    test "boss 11 is unaffected: its own sprite, no phase-1 modifier, 最終型態 label" do
      question = build_question(11, sprite: "mon11", phase: 2)

      assert_equal "mon11", question.boss.sprite
      assert_equal "mon11.gif", boss_image_filename(question)
      assert_equal "mon11", boss_sprite_css_classes(question)
      assert_equal "魔王・最終型態", boss_phase_label(question)
    end

    test "other boss numbers keep their own sprite, plain class, and no phase label" do
      (1..9).each do |number|
        question = build_question(number, sprite: format("mon%02d", number))

        assert_equal format("mon%02d.gif", number), boss_image_filename(question)
        assert_equal format("mon%02d", number), boss_sprite_css_classes(question)
        assert_nil boss_phase_label(question)
      end
    end

    test "questions 10 and 11 point at the same boss row" do
      first_phase = build_question(10, sprite: "mon11", phase: 1)
      final_phase = build_question(11, sprite: "mon11", phase: 2)

      assert_equal first_phase.boss_id, final_phase.boss_id
      assert_equal [ 10, 11 ], first_phase.boss.questions.order(:number).pluck(:number)
    end
  end
end
