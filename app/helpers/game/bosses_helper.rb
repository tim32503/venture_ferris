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
    # as F1/F2 of one boss).
    #
    # That used to be expressed here, as `number == 10 ? 11 : number`
    # restated by three separate methods. It is now a foreign key: both
    # questions point at the same `Boss` row, and `questions.boss_phase`
    # says which form is being fought (docs/SCHEMA_REDESIGN.md §2-3). These
    # helpers only format what the association already says.
    FIRST_PHASE = 1
    FINAL_PHASE = 2

    def boss_image_filename(question)
      "#{question.boss.sprite}.gif"
    end

    # CSS classes for the monster's hit button: the positioning class
    # (`.mon0N`, see boss.scss) always matches the sprite actually being
    # rendered, plus a `.boss-phase-1` modifier that dims/shrinks a shared
    # sprite so an earlier phase reads as a weaker form.
    def boss_sprite_css_classes(question)
      classes = [ question.boss.sprite ]
      classes << "boss-phase-1" if question.boss_phase == FIRST_PHASE
      classes.join(" ")
    end

    # Phase badge text shown on the boss page for a multi-phase fight (only
    # the 摩天輪魔王 has one); nil for every single-phase boss so the view
    # renders nothing extra for them.
    def boss_phase_label(question)
      case question.boss_phase
      when FIRST_PHASE then "魔王・第一型態"
      when FINAL_PHASE then "魔王・最終型態"
      end
    end

    # Kept as a general defense even though `bosses.sprite` is NOT NULL: a
    # non-null sprite name says nothing about whether the asset pipeline can
    # actually resolve `mon0N.gif`. If one ever goes missing the view still
    # falls back to a text notice instead of a broken `image_tag`.
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
