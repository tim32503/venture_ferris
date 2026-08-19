import PollController from "controllers/poll_controller"

// Polls GET /game/job/status.json and disables the "select" button on any
// job carousel card already taken by a teammate — replacing the legacy
// `checkJob()` polling loop in `wheel_job.php` (and fixing the
// `countUserJobIsNull` SQL bug that always reported zero unresolved jobs;
// see REFACTOR_PLAN.md §8-5).
export default class extends PollController {
  static targets = [ "jobCard" ]
  static values = {
    selfEmail: String
  }

  onData(data) {
    const players = data.players || []
    const takenByOthers = new Set(
      players
        .filter((player) => player.job && player.email !== this.selfEmailValue)
        .map((player) => player.job)
    )

    this.jobCardTargets.forEach((card) => {
      const job = card.dataset.job
      const button = card.querySelector("[type=submit]")
      if (!button) return

      button.disabled = takenByOthers.has(job)
    })
  }
}
