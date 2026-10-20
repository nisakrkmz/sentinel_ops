class Incident < ApplicationRecord
  # ServiceNow ITSM State Flow: New -> In Progress -> On Hold -> Resolved -> Closed
  enum :state, {
    new_ticket: 0,
    in_progress: 1,
    on_hold: 2,
    resolved: 3,
    closed: 4
  }, default: :new_ticket

  # SLA Durumu
  enum :sla_status, {
    within_sla: 0,
    sla_breached: 1
  }, default: :within_sla

  # ServiceNow Öncelik Matrisi (Priority)
  enum :priority, {
    p1_critical: 1,
    p2_high: 2,
    p3_moderate: 3,
    p4_low: 4
  }, default: :p3_moderate

  STATUS_MAPPINGS = {
    reported: 0,
    investigating: 1,
    resolved: 2,
    sla_breached: 3
  }.with_indifferent_access.freeze

  def self.statuses
    STATUS_MAPPINGS
  end

  def assign_default_actor
    self.opened_by_actor ||= Current.actor || Actor.demo_ui_operator
  end

  # Geriye dönük uyumluluk için severity enum
  enum :severity, { low: 0, medium: 1, high: 2, critical: 3 }, default: :medium, prefix: :legacy_sev

  # Geriye dönük uyumluluk metotları (reported?, investigating?, sla_breached?, status)
  before_save :sync_legacy_status_column

  def reported?
    new_ticket?
  end

  def investigating?
    in_progress?
  end

  def status
    if sla_breached?
      "sla_breached"
    elsif resolved?
      "resolved"
    elsif in_progress?
      "investigating"
    elsif on_hold?
      "on_hold"
    else
      "reported"
    end
  end

  def status=(val)
    case val.to_s
    when "reported", "new", "new_ticket"
      self.state = :new_ticket
    when "investigating", "in_progress"
      self.state = :in_progress
    when "on_hold"
      self.state = :on_hold
    when "resolved"
      self.state = :resolved
    when "sla_breached"
      self.sla_status = :sla_breached
    end
  end

  private

  def sync_legacy_status_column
    int_val = if sla_breached?
                3
    elsif resolved?
                2
    elsif in_progress?
                1
    else
                0
    end
    write_attribute(:status, int_val)
  end

  public

  has_many :timeline_events, -> { order(created_at: :asc) }, dependent: :destroy
  belongs_to :opened_by_actor, class_name: "Actor", optional: true
  has_many :decisions, dependent: :destroy
  has_many :handoffs, dependent: :destroy

  # Validasyonlar
  validates :short_description, presence: true
  validates :service_affected, presence: true
  validates :origin, inclusion: { in: %w[ui api mcp simulation] }
  validates :triage_status, inclusion: { in: %w[pending done failed needs_human] }
  validates :idempotency_key, uniqueness: true, allow_nil: true

  # Callback'ler
  before_validation :sync_service_now_fields, on: [ :create, :update ]
  before_validation :assign_default_actor, on: :create
  before_create :generate_ticket_number
  before_create :set_sla_and_defaults
  after_create :log_creation_event

  # SLA Süre Tablosu (Önceliğe Göre Dinamik SLA Hedefleri)
  SLA_DURATIONS = {
    "p1_critical" => 15.minutes,
    "p2_high" => 2.hours,
    "p3_moderate" => 4.hours,
    "p4_low" => 24.hours
  }.freeze

  DEFAULT_SLA_MINUTES = 15

  # Kapsamlar (Scopes)
  scope :active, -> { where(state: [ :new_ticket, :in_progress, :on_hold ]) }
  scope :open_tickets, -> { where.not(state: [ :resolved, :closed ]) }
  scope :resolved_tickets, -> { where(state: [ :resolved, :closed ]) }
  scope :sla_breached_tickets, -> { where(sla_status: :sla_breached) }
  scope :critical_p1, -> { where(priority: :p1_critical) }

  # ServiceNow Öncelik Başlıkları
  def priority_label
    case priority
    when "p1_critical" then "P1 - Critical (15m SLA)"
    when "p2_high" then "P2 - High (2h SLA)"
    when "p3_moderate" then "P3 - Moderate (4h SLA)"
    when "p4_low" then "P4 - Low (24h SLA)"
    else "P3 - Moderate"
    end
  end

  def priority_short_label
    case priority
    when "p1_critical" then "P1 - Critical"
    when "p2_high" then "P2 - High"
    when "p3_moderate" then "P3 - Moderate"
    when "p4_low" then "P4 - Low"
    else "P3"
    end
  end

  def state_label
    case state
    when "new_ticket" then "New (Yeni)"
    when "in_progress" then "In Progress (İşlemde)"
    when "on_hold" then "On Hold (Beklemede)"
    when "resolved" then "Resolved (Çözüldü)"
    when "closed" then "Closed (Kapatıldı)"
    else state.to_s.titleize
    end
  end

  # =========================================================================
  # SERVICENOW DURUM GEÇİŞLERİ (State Workflow)
  # =========================================================================

  # Durum 1: İncelemeye / İşleme Al (New / On Hold -> In Progress)
  def start_progress!(assignee = "Alex Hunter (Tier 3 Support)")
    check_sla!
    transaction do
      update!(
        state: :in_progress,
        investigating_at: Time.current,
        assigned_to: assignee
      )
      timeline_events.create!(
        event_type: "in_progress_started",
        message: "Bilet işleme alındı (In Progress). Atanan Uzman: #{assignee}"
      )
    end
    true
  end
  alias_method :start_investigating!, :start_progress!

  # Durum 2: Beklemeye Al (In Progress -> On Hold)
  def put_on_hold!(reason = "Kullanıcı veya 3. parti sağlayıcı yanıtı bekleniyor")
    transaction do
      update!(
        state: :on_hold,
        on_hold_reason: reason
      )
      timeline_events.create!(
        event_type: "on_hold",
        message: "Bilet beklemeye alındı (On Hold). Neden: #{reason}"
      )
    end
    true
  end

  # Durum 3: Çözümle (In Progress / On Hold / New -> Resolved)
  def resolve!(resolution_notes: nil, root_cause: nil, rca_text: nil, steps_text: nil)
    final_notes = resolution_notes.presence || steps_text.presence || "Knowledge Base eşleşmesi uygulanarak servis normale döndürüldü."
    final_rca = root_cause.presence || rca_text.presence || "Kök neden tespit edildi ve kalıcı çözüm uygulandı."

    transaction do
      update!(
        state: :resolved,
        resolved_at: Time.current,
        resolution_notes: final_notes,
        resolution_steps: final_notes,
        root_cause_analysis: final_rca
      )
      timeline_events.create!(
        event_type: "resolved",
        message: "Bilet çözüldü (Resolved) ve kapatıldı. Çözüm Notu: #{final_notes.truncate(120)}"
      )
    end
    true
  end

  # =========================================================================
  # ZAMAN KURALI: SLA Takibi & İhlal Kontrolü
  # =========================================================================

  def check_sla!
    return false if resolved? || closed?

    if sla_deadline.present? && Time.current > sla_deadline
      unless sla_breached?
        transaction do
          update_columns(
            sla_status: Incident.sla_statuses[:sla_breached],
            status: Incident.statuses[:sla_breached],
            sla_breached_at: Time.current
          )
          timeline_events.create!(
            event_type: "sla_breached",
            message: "⚠️ KURUMSAL SLA İHLALİ: Hedef çözüm süresi (#{priority_short_label}) aşıldı! Bilet 'SLA Breached' olarak işaretlendi."
          )
        end
      end
      true
    else
      false
    end
  end

  def sla_time_remaining_seconds
    return 0 if sla_deadline.blank? || resolved? || closed? || sla_breached?
    diff = (sla_deadline - Time.current).to_i
    diff.positive? ? diff : 0
  end

  def sla_expired?
    sla_deadline.present? && Time.current > sla_deadline
  end

  private

  def sync_service_now_fields
    # short_description <-> title senkronizasyonu
    self.short_description = short_description.presence || title.presence || "Kurumsal IT Servis Kesintisi"
    self.title = short_description

    # description <-> error_message senkronizasyonu
    self.description = description.presence || error_message.presence || "Detaylı vaka açıklaması girilmedi."
    self.error_message = description

    # service_affected <-> service_name senkronizasyonu
    self.service_affected = service_affected.presence || service_name.presence || "Kurumsal Servis"
    self.service_name = service_affected

    # caller_id / requested_by
    self.requested_by = requested_by.presence || caller_id.presence || "Sarah Jenkins (Finance VP)"
    self.caller_id = requested_by

    # category & assignment_group
    self.category = category.presence || "Enterprise Software"
    self.assignment_group = assignment_group.presence || "ITSM Platform Operations"
    self.assigned_to = assigned_to.presence || "Triage Team (Otomatik)"

    # priority <-> severity eşleme
    if severity_changed? && !priority_changed?
      case severity
      when "critical" then self.priority = :p1_critical
      when "high" then self.priority = :p2_high
      when "medium" then self.priority = :p3_moderate
      when "low" then self.priority = :p4_low
      end
    elsif priority_changed? && !severity_changed?
      case priority
      when "p1_critical" then self.severity = :critical
      when "p2_high" then self.severity = :high
      when "p3_moderate" then self.severity = :medium
      when "p4_low" then self.severity = :low
      end
    end

    generate_signature
  end

  def generate_ticket_number
    return if number.present?

    # ServiceNow INC001024 formatında kurumsal bilet numarası üretimi
    last_id = Incident.maximum(:id) || 0
    self.number = sprintf("INC%06d", last_id + 1001)
  end

  def set_sla_and_defaults
    # Önceliğe göre SLA süresini dinamik hesapla
    sla_duration = SLA_DURATIONS[priority.to_s] || 15.minutes
    self.sla_deadline ||= (created_at || Time.current) + sla_duration
    self.sla_status ||= :within_sla
    self.state ||= :new_ticket
  end

  def generate_signature
    text_to_hash = "#{service_affected}:#{clean_text(short_description)}:#{clean_text(description)}"
    self.error_signature = Digest::SHA256.hexdigest(text_to_hash.downcase.strip)[0..15]
  end

  def clean_text(str)
    str.to_s.gsub(/\b0x[0-9a-fA-F]+\b/, "").gsub(/\d+/, "").strip
  end

  def log_creation_event
    timeline_events.create!(
      event_type: "created",
      message: "Yeni ITSM Bileti (#{number}) açıldı. Talep Eden: #{requested_by}, Servis: #{service_affected}, Öncelik: #{priority_short_label}. Hedef SLA: #{sla_deadline.strftime('%H:%M:%S')}."
    )
  end
end
