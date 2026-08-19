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
    AREAS = {
      1 => [
        { title: "台北生活祭活動會場", shape: "rect", coords: "581,33,857,116", to_map: 2 },
        { title: "一鷺炭火燒鳥工房", shape: "rect", coords: "922,67,1165,185", number: 2 },
        { title: "美麗華A", shape: "rect", coords: "536,455,640,556", number: 3 },
        { title: "美麗華B", shape: "rect", coords: "650,455,748,557", number: 4 },
        { title: "美福大飯店", shape: "rect", coords: "142,680,366,821", number: 1 }
      ],
      2 => [
        { title: "熊讚", shape: "poly",
          coords: "225,398,167,423,160,461,155,506,158,549,192,575,252,574,307,567,336,548,320,496,284,450,264,408",
          number: 9 },
        { title: "北投溫泉", shape: "poly", coords: "312,341,390,342,403,462,362,470,316,469,299,449", number: 5 },
        { title: "朝陽", shape: "poly",
          coords: "479,371,553,370,577,314,580,282,560,260,523,262,506,290,483,347", number: 7 },
        { title: "龍山寺", shape: "poly",
          coords: "480,377,552,380,552,423,526,446,501,462,469,453,465,425", number: 6 },
        { title: "公館", shape: "poly",
          coords: "897,415,995,417,1003,379,1074,340,1085,318,1078,290,1072,270,1037,267,921,381,904,379,897,390",
          number: 8 }
      ],
      3 => [
        { title: "摩天輪", shape: "circle", coords: "660,352,212", number: 10 }
      ]
    }.freeze

    IMAGE_FOR = { 1 => "map1.jpg", 2 => "map2.jpg", 3 => "map3.jpg" }.freeze

    # GET /game/map — legacy `Wheel#map(null)`'s solved-count branch
    # (`Team#current_map`: >=9 completed -> map3, else map1).
    def index
      redirect_to game_map_path(current_team.current_map)
    end

    # GET /game/maps/:id
    def show
      @map_id = params[:id].to_i
      @image = IMAGE_FOR.fetch(@map_id)
      @areas = AREAS.fetch(@map_id)
      @completed_numbers = current_team.completed_question_numbers
    end
  end
end
