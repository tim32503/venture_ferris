import { Controller } from "@hotwired/stimulus"

// Replaces Bootstrap 4's jQuery-backed Carousel (data-ride="carousel",
// data-slide="prev"/"next") on the job-selection page. The track is a plain
// horizontally-scrolling flex container with CSS scroll-snap (see
// .carousel-track in site.scss); this controller only drives the arrow
// buttons (scrollBy one card width) and keeps the indicator dots in sync
// with whichever card is currently snapped into view. Touch/trackpad swipe
// is native browser scrolling — no JS needed for that.
export default class extends Controller {
  static targets = [ "track", "slide", "indicator" ]

  connect() {
    this.updateActive = this.updateActive.bind(this)
    this.trackTarget.addEventListener("scroll", this.updateActive, { passive: true })
    this.updateActive()
  }

  disconnect() {
    this.trackTarget.removeEventListener("scroll", this.updateActive)
  }

  next() {
    this.scrollByCards(1)
  }

  previous() {
    this.scrollByCards(-1)
  }

  scrollByCards(direction) {
    const card = this.slideTargets[0]
    if (!card) return

    this.trackTarget.scrollBy({ left: direction * card.offsetWidth, behavior: "smooth" })
  }

  goTo(event) {
    const index = this.indicatorTargets.indexOf(event.currentTarget)
    const card = this.slideTargets[index]
    if (!card) return

    this.trackTarget.scrollTo({ left: card.offsetLeft, behavior: "smooth" })
  }

  // Finds whichever slide's center is closest to the track's own center and
  // marks the matching indicator dot active. Runs on every scroll event
  // (rAF-throttled would be nicer, but this page has 4 cards — negligible).
  updateActive() {
    const trackRect = this.trackTarget.getBoundingClientRect()
    const trackCenter = trackRect.left + trackRect.width / 2

    let closestIndex = 0
    let closestDistance = Infinity

    this.slideTargets.forEach((slide, index) => {
      const slideRect = slide.getBoundingClientRect()
      const slideCenter = slideRect.left + slideRect.width / 2
      const distance = Math.abs(slideCenter - trackCenter)

      if (distance < closestDistance) {
        closestDistance = distance
        closestIndex = index
      }
    })

    this.indicatorTargets.forEach((indicator, index) => {
      indicator.classList.toggle("active", index === closestIndex)
    })
  }
}
