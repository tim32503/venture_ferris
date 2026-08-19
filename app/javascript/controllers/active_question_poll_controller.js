import PollController from "controllers/poll_controller"

// Polls a `GET /game/questions/:number/status.json` endpoint and, whenever
// the payload's `active_question_number` names a question, follows there —
// this is the P3 replacement for the legacy `questionIsStart()` poll used
// on `wheel_home.php` / `wheel_map1.php` / `wheel_map2.php` / `wheel_map3.php`
// (a teammate starting a question's timer elsewhere redirects everyone
// still on the home/map pages to that question).
//
// The `:number` segment of the polled `url` value is arbitrary (question
// #1 is used as a fixed anchor) — `questions#status` answers with
// team-wide `active_question_number` info regardless of which number you
// ask about. The redirect target is built from `questionBasePathValue`
// (GameHelper#question_redirect_base_path) + the number in the payload.
// Question show pages don't use this controller: once you're already
// looking at a question there is nothing else to redirect to.
//
// Boss redirects (`bossIsStart()` in the legacy views — REFACTOR_PLAN.md
// P4): `questions#status` now also reports a team-wide in-progress boss
// battle as `active_boss_number`, the same way it reports an in-progress
// question timer as `active_question_number`. `bossBasePathValue` is only
// wired up on pages that opted into this (currently the home page —
// `data-active-question-poll-boss-base-path-value`); `hasBossBasePathValue`
// guards the check off on any page that hasn't, so this stays backward
// compatible with pages using this controller only for question redirects.
export default class extends PollController {
  static values = {
    questionBasePath: String,
    bossBasePath: String
  }

  onData(data) {
    if (data.active_boss_number && this.hasBossBasePathValue) {
      window.location.href = `${this.bossBasePathValue}${data.active_boss_number}`
      return
    }

    if (data.active_question_number) {
      window.location.href = `${this.questionBasePathValue}${data.active_question_number}`
    }
  }
}
