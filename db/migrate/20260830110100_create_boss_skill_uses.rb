# One row per player per boss battle who has activated their job's active
# skill (docs/JOB_SKILLS_DESIGN.md — "每場王戰每人限用一次"). The unique
# index on [boss_battle_id, player_id] is the actual enforcement: a second
# activation attempt from the same player in the same battle hits
# `ActiveRecord::RecordNotUnique`/`RecordInvalid`, not a Ruby-level
# read-then-write race (same pattern as `boss_readies`, docs/SCHEMA_REDESIGN.md
# §2-7b's [team_id, job] index, and BossReady's own [boss_battle_id,
# player_id] index).
#
# `skill` mirrors the player's job at the moment of use (uncle/senior/
# netizen/celebrity) rather than being a free-form skill key — every job has
# exactly one active skill, so job and skill are the same value; storing it
# here (rather than joining back through `players.job`, which can change
# after the fact... though in practice a player's job never changes once
# set) keeps the historical record self-contained.
#
# `consumed_at` is only meaningful for 鞋姊 (senior)'s 醍醐灌頂: the skill
# arms a "pending forced critical" on activation (`consumed_at` NULL) that
# the player's *next* attack consumes (`consumed_at` set). For the other
# three jobs the effect is applied immediately on activation, so their rows
# are created with `consumed_at` already set.
class CreateBossSkillUses < ActiveRecord::Migration[7.2]
  def change
    create_table :boss_skill_uses do |t|
      t.references :boss_battle, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.string :skill, null: false
      t.datetime :consumed_at

      t.timestamps
    end

    add_index :boss_skill_uses, [ :boss_battle_id, :player_id ], unique: true, name: "index_boss_skill_uses_on_battle_and_player"
  end
end
