# One hint for one question (docs/SCHEMA_REDESIGN.md §2-4). Replaces the
# legacy `questions.hint1`/`hint2` repeating group *and* the derived
# `hints_enabled` flag: "hints are available for this question" is now
# expressed as "this question has hint rows", so the two can never disagree.
#
# `position` is 1-based and dense; it is what both the hint cap
# (Game::QuestionsController#hints) and the numbering shown in the hint panel
# read from, so blank legacy hint text was dropped rather than migrated.
class QuestionHint < ApplicationRecord
  belongs_to :question

  validates :position, presence: true,
                        numericality: { only_integer: true, greater_than: 0 },
                        uniqueness: { scope: :question_id }
  validates :content, presence: true
end
