import PollController from "controllers/poll_controller"

// Polls GET /game/team/status.json and keeps the team name / member count
// on the team page live. If the page was rendered before the team had a
// name (member waiting on the leader), it auto-navigates to the job page
// as soon as the leader finishes naming the team — mirroring the legacy
// `checkTeamNM()` polling redirect in `wheel_team.php`.
export default class extends PollController {
  static targets = [ "name", "count" ]
  static values = {
    redirectOnReady: Boolean,
    redirectUrl: String
  }

  onData(data) {
    if (this.hasNameTarget && data.name) {
      this.nameTarget.textContent = data.name
    }

    if (this.hasCountTarget && typeof data.total === "number") {
      this.countTarget.textContent = data.total
    }

    if (this.redirectOnReadyValue && data.ready && this.redirectUrlValue) {
      window.location.href = this.redirectUrlValue
    }
  }
}
