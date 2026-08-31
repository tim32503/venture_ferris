# One monster. Not one per question: Q10 and Q11 are the two phases of a
# single 摩天輪魔王 fight, so 10 Boss rows cover 11 questions
# (docs/SCHEMA_REDESIGN.md §2-3). That is the whole reason this table exists
# — a thing that spans two questions has an identity of its own, and before
# this table the fact lived as `number == 10 ? 11 : number` repeated across
# three view helpers.
#
# `sprite` is the bare asset stem (`mon01`..`mon09`, `mon11`); the view adds
# the extension. Deliberately no `name` column: the recovered 2018 dump has
# no boss names (docs/SCHEMA_REDESIGN.md §0-E1), so adding one would mean
# inventing content — the boss page shows `question.title` instead.
class Boss < ApplicationRecord
  has_many :questions, dependent: :restrict_with_error

  validates :sprite, presence: true, uniqueness: true
end
