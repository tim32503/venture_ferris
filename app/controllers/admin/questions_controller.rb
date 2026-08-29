# Question content management (A4 — docs/ADMIN_CONSOLE_PLAN.md). There is
# no #create/#destroy: the 11 questions are fixed game structure, not
# admin-managed records.
#
# The answer reset field is intentionally NOT a Question attribute — it is
# read directly off `params[:question][:new_answer]` (see `#update`) and
# never included in `question_params`, so it can never be mass-assigned
# onto the model, and `answer_digest` itself is never permitted either.
# `#edit`/`#show` must never render `answer_digest` or any plaintext
# answer — the digest is one-way (Question.digest_for) and this batch's
# only way to change it is to overwrite it, never to read it back.
class Admin::QuestionsController < Admin::BaseController
  def index
    @questions = Question.includes(:boss, :hints).order(:number)
  end

  def edit
    @question = Question.find(params[:id])
    @question.hints.build
  end

  def update
    @question = Question.find(params[:id])

    Question.transaction do
      @question.assign_attributes(question_params)
      apply_answer_reset!
      @question.save!
    end

    redirect_to edit_admin_question_path(@question), notice: "已更新第 #{@question.number} 題"
  rescue ActiveRecord::RecordInvalid
    @question.hints.build if @question.hints.none? { |hint| hint.new_record? }
    flash.now[:alert] = @question.errors.full_messages.to_sentence
    render :edit, status: :unprocessable_entity
  end

  private

  def question_params
    params.require(:question).permit(
      :title, :content, :level, :explanation, :boss_hp, :boss_time_limit,
      hints_attributes: [ :id, :position, :content, :_destroy ]
    )
  end

  # Leaves `answer_digest` untouched when the field is left blank — a blank
  # submission must never wipe out the existing correct answer.
  def apply_answer_reset!
    new_answer = params.dig(:question, :new_answer)
    return if new_answer.blank?

    @question.answer_digest = Question.digest_for(new_answer)
  end
end
