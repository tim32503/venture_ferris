require "test_helper"

module Game
  # Boss #10/#11 sprite + phase-label mapping (see bosses_helper.rb's
  # comment on `boss_sprite_source_number` for the "same 摩天輪魔王, two
  # phases" background). Boss #10 has no sprite of its own and must resolve
  # to mon11's asset/positioning with a "phase 1" modifier; boss #11 stays
  # exactly as before; every other boss number must be untouched by this
  # change.
  class BossesHelperTest < ActionView::TestCase
    include Game::BossesHelper

    test "boss 10 resolves to mon11's sprite" do
      assert_equal 11, boss_sprite_source_number(10)
      assert_equal "mon11.gif", boss_image_filename(10)
    end

    test "boss 10 gets mon11's positioning class plus the phase-1 modifier" do
      assert_equal "mon11 boss-phase-1", boss_sprite_css_classes(10)
    end

    test "boss 10's phase label is 第一型態" do
      assert_equal "魔王・第一型態", boss_phase_label(10)
    end

    test "boss 11 is unaffected: its own sprite, no phase-1 modifier, 最終型態 label" do
      assert_equal 11, boss_sprite_source_number(11)
      assert_equal "mon11.gif", boss_image_filename(11)
      assert_equal "mon11", boss_sprite_css_classes(11)
      assert_equal "魔王・最終型態", boss_phase_label(11)
    end

    test "other boss numbers keep their own sprite, plain class, and no phase label" do
      (1..9).each do |number|
        assert_equal number, boss_sprite_source_number(number)
        assert_equal format("mon%02d.gif", number), boss_image_filename(number)
        assert_equal format("mon%02d", number), boss_sprite_css_classes(number)
        assert_nil boss_phase_label(number)
      end
    end
  end
end
