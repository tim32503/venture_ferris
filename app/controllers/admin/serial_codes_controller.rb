# Batch serial-code generator. The legacy admin_generate.php view produced
# 5,000/20,000 rows purely on the client side (nothing was written to the
# database — see REFACTOR_PLAN.md P5). This replaces that with a real
# `insert_all` write, a sane default/cap, and QR codes rendered locally
# with rqrcode instead of the deprecated Google Image Charts API.
class Admin::SerialCodesController < Admin::BaseController
  DEFAULT_COUNT = 50
  MAX_COUNT = 500
  MAX_GENERATION_ATTEMPTS = 5
  SERIAL_CHARSET = ("A".."Z").to_a + ("0".."9").to_a
  INDEX_LIMIT = 100

  def index
    @teams = Team.order(created_at: :desc).limit(INDEX_LIMIT)
  end

  def create
    count = requested_count
    test_mode = requested_test_mode

    insert_serial_codes(count, test_mode)

    redirect_to admin_serial_codes_path, notice: "已產生 #{count} 筆序號"
  end

  private

  def requested_count
    value = params[:count].presence&.to_i || DEFAULT_COUNT
    value = DEFAULT_COUNT if value <= 0
    value.clamp(1, MAX_COUNT)
  end

  def requested_test_mode
    ActiveModel::Type::Boolean.new.cast(params[:test_mode]) || false
  end

  # Generates `count` fresh, unique 16-char serial numbers and writes them
  # in one batch. On the rare chance a generated serial collides with a
  # concurrently-inserted row (unique index race), the whole batch is
  # regenerated and retried rather than silently dropping rows.
  def insert_serial_codes(count, test_mode)
    attempts = 0

    begin
      Team.insert_all!(build_rows(count, test_mode))
    rescue ActiveRecord::RecordNotUnique
      attempts += 1
      raise if attempts >= MAX_GENERATION_ATTEMPTS

      retry
    end
  end

  def build_rows(count, test_mode)
    now = Time.current

    generate_unique_serial_nos(count).map do |serial_no|
      { serial_no: serial_no, test_mode: test_mode, created_at: now, updated_at: now }
    end
  end

  def generate_unique_serial_nos(count)
    existing = Team.pluck(:serial_no).to_set
    generated = Set.new

    while generated.size < count
      candidate = random_serial_no
      next if existing.include?(candidate) || generated.include?(candidate)

      generated << candidate
    end

    generated.to_a
  end

  def random_serial_no
    Array.new(Team::SERIAL_NO_LENGTH) { SERIAL_CHARSET.sample }.join
  end
end
