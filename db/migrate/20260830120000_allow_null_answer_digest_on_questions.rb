class AllowNullAnswerDigestOnQuestions < ActiveRecord::Migration[7.2]
  # Puzzle/bear questions (numbers 1, 2, 9) are "interactive" — their
  # completion is judged client-side, so they have no answer text to hash
  # (see Question#interactive?). Only `quiz` questions still require one,
  # enforced at the model level (`validates :answer_digest, presence: true,
  # if: :quiz?`) rather than at the schema level.
  def change
    change_column_null :questions, :answer_digest, true
  end
end
