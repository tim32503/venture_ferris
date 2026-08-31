module Game
  # Map navigation (legacy `wheel/map/{no}` — docs/REFACTOR_PLAN.md §2/§8-3).
  # map2 is a spatial drill-down of map1 (its hotspots cover questions
  # 5-9), reached only via a hotspot on map1 — it is not a progress stage,
  # unlike map1 -> map3 which is gated by `Team#current_map`.
  class MapsController < BaseController
    # Hotspot data transcribed from the legacy image maps
    # (`wheel_map1.php:5-9`, `wheel_map2.php:6-10`, `wheel_map3.php:6`).
    # `to_map:` hotspots navigate to another map; everything else links to
    # a question by `number:`.
    #
    # Coordinates are `left`/`top`/`width`/`height` as a **percentage of the
    # source image's own pixel dimensions** (map1.jpg/map3.jpg: 1191x842,
    # map2.jpg: 1559x680 — via `sips -g pixelWidth -g pixelHeight`), not
    # absolute pixels. The view renders each area as an `<a>` positioned
    # with those percentages inside a `position: relative` container sized
    # to the rendered (responsive) `<img>`, so the hotspot tracks the image
    # at any width — the old `<map>`/`<area>` pixel `coords` did not (they
    # never scaled down when `img-fluid` shrank the image), which was the
    # one confirmed structural RWD bug in the app (docs/UI_AUDIT.md).
    #
    # The original shapes were `rect` for map1, `poly` for map2, and
    # `circle` for map3; poly/circle are approximated here by their
    # bounding box, since a finger-sized tap target doesn't need
    # pixel-perfect hit-testing against the original polygon.
    AREAS = {
      1 => [
        { title: "台北生活祭活動會場", left: 48.78, top: 3.92, width: 23.17, height: 9.86, to_map: 2 },
        { title: "一鷺炭火燒鳥工房", left: 77.41, top: 7.96, width: 20.40, height: 14.01, number: 2 },
        { title: "美麗華A", left: 45.00, top: 54.04, width: 8.73, height: 11.99, number: 3 },
        { title: "美麗華B", left: 54.58, top: 54.04, width: 8.23, height: 12.11, number: 4 },
        { title: "美福大飯店", left: 11.92, top: 80.76, width: 18.81, height: 16.75, number: 1 }
      ],
      2 => [
        { title: "熊讚", left: 9.94, top: 58.53, width: 11.61, height: 26.03, number: 9 },
        { title: "北投溫泉", left: 19.18, top: 50.15, width: 6.67, height: 18.97, number: 5 },
        { title: "朝陽", left: 30.72, top: 38.24, width: 6.48, height: 16.32, number: 7 },
        { title: "龍山寺", left: 29.83, top: 55.44, width: 5.58, height: 12.50, number: 6 },
        { title: "公館", left: 57.54, top: 39.26, width: 12.06, height: 22.06, number: 8 }
      ],
      3 => [
        { title: "摩天輪", left: 37.62, top: 16.63, width: 35.60, height: 50.36, number: 10 },
        # Fallback route to Q11 for the web port: the legacy game had no
        # hotspot here at all — entry to Q11 happened through the venue
        # itself at the ride's red gondola car (Q10's explanation sends
        # players there and Q11 uniquely auto-starts on page load; whether
        # the on-site trigger was a QR code, a booklet page, or staff is
        # unrecorded).
        # This hotspot is the web equivalent, placed on the bottom-front
        # gondola drawn on map3.jpg (located by crop/level-brightening the
        # source image with ImageMagick — the wheel's own art has no other
        # single car singled out as "the red one", so the boarding position
        # at the bottom of the wheel is the natural stand-in). Only ever
        # rendered once Q10 is completed (`requires_number:`, filtered in
        # `#show` below) — before that, Q11 doesn't exist for this team yet.
        { title: "紅色車廂（最終考驗）", left: 52.48, top: 43.35, width: 6.72, height: 7.72,
          number: 11, requires_number: 10 }
      ]
    }.freeze

    IMAGE_FOR = { 1 => "map1.jpg", 2 => "map2.jpg", 3 => "map3.jpg" }.freeze

    # Natural pixel width of each map image (`sips -g pixelWidth`). The view
    # caps the hotspot container at this width via `max-width` so the `<img>`
    # can be told to always render at exactly 100% of its container (instead
    # of Bootstrap's `img-fluid`, which only ever shrinks and never grows) —
    # that keeps the container's box, and therefore the percentage-positioned
    # hotspots, pixel-identical to the image at any viewport width, without
    # the upscale-blur an unconstrained 100%-width image would get on very
    # wide screens.
    NATURAL_WIDTH = { 1 => 1191, 2 => 1559, 3 => 1191 }.freeze

    # GET /game/map — legacy `Wheel#map(null)`'s solved-count branch
    # (`Team#current_map`: >=9 completed -> map3, else map1).
    def index
      redirect_to game_map_path(current_team.current_map)
    end

    # GET /game/maps/:id
    def show
      @map_id = params[:id].to_i
      @image = IMAGE_FOR.fetch(@map_id)
      @natural_width = NATURAL_WIDTH.fetch(@map_id)
      @completed_numbers = current_team.completed_question_numbers
      # A `requires_number:` hotspot (the map3 Q11 fallback above) only
      # renders once this team has actually *defeated that number's boss*
      # (Team#defeated_boss_numbers, not the weaker completed_question_numbers
      # above) — gating on the question's own answer instead would surface
      # the Q11 shortcut while the team is still mid-fight against boss 10,
      # letting them skip it outright.
      defeated_boss_numbers = current_team.defeated_boss_numbers
      @areas = AREAS.fetch(@map_id).select do |area|
        area[:requires_number].blank? || defeated_boss_numbers.include?(area[:requires_number])
      end
    end
  end
end
