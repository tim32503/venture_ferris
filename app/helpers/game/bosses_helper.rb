module Game
  # View/controller helpers for the per-question boss fight (legacy
  # `wheel_boss.php` — REFACTOR_PLAN.md §2/P4). Kept out of the shared
  # `GameHelper` (a P3 file) so this batch doesn't have to touch it.
  module BossesHelper
    # Boss time limit + uncle bonus (REFACTOR_PLAN.md §1.2 — the legacy
    # uncle effect was broken by a "false" JSON string always being truthy,
    # so it *always* added the bonus; this ports the intended 30->40s
    # design instead, computed server-side and handed to the view/JS).
    UNCLE_BONUS_SECONDS = 10

    def boss_time_limit_seconds(question, team)
      question.boss_time_limit + (team.players.uncle.any? ? UNCLE_BONUS_SECONDS : 0)
    end

    # Legacy boss sprites are named `mon{01..11}.gif`, zero-padded
    # (REFACTOR_PLAN.md P4 acceptance). `mon10.gif` was never part of the
    # recovered asset set — cross-referencing the restored original quest
    # text (db/seeds.rb) shows Q10 ("魔王佔據的摩天輪") and Q11 are a single
    # continuous fight against the same "摩天輪魔王" (Q11 is `auto_start`,
    # i.e. no separate ready-lobby, and the legacy asset naming treats them
    # as F1/F2 of one boss), so boss #10 is presumed to have never had a
    # standalone sprite of its own. Boss #10 therefore reuses mon11.gif as
    # its "第一型態" (phase 1) — see `boss_sprite_source_number` /
    # `boss_phase_label` — while boss #11 keeps showing mon11.gif at full
    # color as the "最終型態" (final phase).
    #
    # `boss_asset_available?` below is kept as a general defense: if any
    # *other* boss number's sprite ever goes missing (new numbering, asset
    # regression, etc.), the view still falls back to a text notice instead
    # of a broken `image_tag`, exactly as before this change.
    WHEEL_BOSS_FIRST_PHASE_NUMBER = 10
    WHEEL_BOSS_FINAL_PHASE_NUMBER = 11

    def boss_sprite_source_number(number)
      number == WHEEL_BOSS_FIRST_PHASE_NUMBER ? WHEEL_BOSS_FINAL_PHASE_NUMBER : number
    end

    def boss_image_filename(number)
      format("mon%02d.gif", boss_sprite_source_number(number))
    end

    # CSS classes for the monster's hit button: the positioning class
    # (`.mon0N`, see boss.scss) always matches the sprite actually being
    # rendered (`boss_sprite_source_number`), plus a `.boss-phase-1` modifier
    # for boss #10 that dims/shrinks the shared mon11 sprite so it reads as
    # an earlier, weaker form.
    def boss_sprite_css_classes(number)
      classes = [ "mon#{format('%02d', boss_sprite_source_number(number))}" ]
      classes << "boss-phase-1" if number == WHEEL_BOSS_FIRST_PHASE_NUMBER
      classes.join(" ")
    end

    # Phase badge text shown on the boss page for the two-stage "摩天輪魔王"
    # fight (boss #10/#11 only); nil for every other boss number so the view
    # renders nothing extra for them.
    def boss_phase_label(number)
      case number
      when WHEEL_BOSS_FIRST_PHASE_NUMBER then "魔王・第一型態"
      when WHEEL_BOSS_FINAL_PHASE_NUMBER then "魔王・最終型態"
      end
    end

    def boss_asset_available?(logical_path)
      manifest = Rails.application.assets_manifest
      return true if manifest && manifest.assets[logical_path]

      environment = Rails.application.assets
      environment.present? && environment.find_asset(logical_path).present?
    rescue StandardError
      false
    end

    # Base path `active_question_poll_controller.js` appends a boss number
    # onto when it redirects a teammate whose boss fight has started
    # elsewhere — mirrors `GameHelper#question_redirect_base_path`.
    def boss_redirect_base_path
      game_boss_path(Question::FIRST_NUMBER).delete_suffix(Question::FIRST_NUMBER.to_s)
    end
  end
end
