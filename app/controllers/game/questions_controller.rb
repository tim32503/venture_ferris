module Game
  # A single question station (legacy `wheel/question/{qno}` + `timer` +
  # `setHintCount`/`getHint` + `questionIsStart` — docs/REFACTOR_PLAN.md
  # §2/P3). `#show` never renders the answer or its digest; correctness is
  # only ever decided server-side in `#answer` (REFACTOR_PLAN.md §0 — the
  # legacy `wheel_question.php:241` front-end comparison is the exact bug
  # this batch replaces).
  #
  # `timer`/`hints`/`answer` are classic redirect-driven mutations (same
  # style as Game::TeamsController/JobsController), not JSON endpoints —
  # only `#status` is JSON, since it is the one polled without a full page
  # load.
  class QuestionsController < BaseController
    before_action :set_question

    def show
      @attempt = existing_or_unsaved_attempt
      auto_start_if_needed!

      if @attempt.completed?
        render :solved
        return
      end

      case @question.kind
      when "puzzle" then render :puzzle
      when "bear" then render :bear
      else render :quiz
      end
    end

    # POST /game/questions/:number/timer — idempotent start (legacy
    # `timer/Question/:no/Begin`). No-op if a timer is already running or
    # the question is already solved.
    def timer
      attempt = attempt_record
      attempt.update!(started_at: Time.current) if attempt.started_at.blank?

      redirect_to game_question_path(@question.number)
    end

    # POST /game/questions/:number/answer — the server-side answer check
    # this whole batch exists to add (REFACTOR_PLAN.md §0).
    def answer
      attempt = attempt_record

      return redirect_to game_question_path(@question.number) if attempt.completed?

      if @question.answer?(params[:answer])
        attempt.update!(started_at: attempt.started_at || Time.current, ended_at: Time.current)
        # REFACTOR_PLAN.md P4 req #7: a correct answer now sends the team
        # straight into that question's boss fight (legacy redirected to
        # `wheel/boss/:qno` here too), not back to the map.
        redirect_to game_boss_path(@question.number), notice: "恭喜答對！#{@question.explanation}"
      else
        redirect_to game_question_path(@question.number), alert: "不對喔！再想想看！"
      end
    end

    # POST /game/questions/:number/hints — legacy `setHintCount`. Question 6
    # has no hint rows at all and must refuse outright; every other question
    # caps out at its own number of hints. The no-hints path is a bare 403
    # (not a redirect+flash like the guard below) because the hint button is
    # never rendered for a question without hints — this only fires against a
    # direct POST that bypassed the UI. **The two branches must stay in this
    # order**: folding them together would turn question 6's 403 into a
    # 302 + "已達提示使用上限" (docs/SCHEMA_REDESIGN.md §2-4).
    def hints
      return head :forbidden if @question.hints.none?

      attempt = attempt_record

      if attempt.hint_count >= @question.hints.size
        return redirect_to game_question_path(@question.number), alert: "已達提示使用上限"
      end

      attempt.increment!(:hint_count)
      redirect_to game_question_path(@question.number), notice: "提示已解鎖，請於下方查看"
    end

    # GET /game/questions/:number/status.json — polled by
    # active_question_poll_controller.js from the home/map pages (question
    # show pages render their own started/solved/hint_count state directly
    # from `@attempt`, so they don't poll this). Never blocks (legacy
    # `checkQuestionIsStart`/`getHintCount` used `while(true) { usleep }`).
    #
    # `active_boss_number` (REFACTOR_PLAN.md P4: connecting the P3-reserved
    # "extend onData to also check a boss-in-progress field" comment in
    # active_question_poll_controller.js) reports a team-wide in-progress
    # boss fight the same way `active_question_number` reports an
    # in-progress question timer, so a teammate who didn't start the fight
    # themselves still gets redirected there.
    def status
      attempt = current_team.question_attempts.find_by(question: @question)
      active_attempt = current_team.active_question_attempt
      active_boss = current_team.active_boss_battle

      render json: {
        started: attempt&.started_at.present? || false,
        solved: attempt&.completed? || false,
        hint_count: attempt&.hint_count || 0,
        active_question_number: active_attempt&.question&.number,
        active_boss_number: active_boss&.question&.number
      }
    end

    private

    def set_question
      @question = Question.find_by!(number: params[:number])
    end

    def attempt_record
      current_team.question_attempts.find_or_create_by!(question: @question)
    end

    def existing_or_unsaved_attempt
      current_team.question_attempts.find_by(question: @question) ||
        current_team.question_attempts.new(question: @question)
    end

    # Question 11 auto-starts its own timer as soon as it's shown (legacy
    # `wheel_question.php:173-187`), instead of waiting for the player to
    # confirm through the usual start dialog.
    def auto_start_if_needed!
      return unless @question.auto_start?
      return if @attempt.completed?

      @attempt = attempt_record
      @attempt.update!(started_at: Time.current) if @attempt.started_at.blank?
    end
  end
end
