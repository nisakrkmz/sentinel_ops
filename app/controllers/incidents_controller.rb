class IncidentsController < ApplicationController
  before_action :set_incident, only: [ :show, :start_progress, :investigate, :put_on_hold, :resolve, :check_sla, :apply_knowledge ]

  def index
    # Aktif biletlerin SLA sürelerini dinamik kontrol et
    Incident.open_tickets.find_each(&:check_sla!)

    # Arama ve Filtreleme
    @query = params[:q].to_s.strip
    @filter = params[:filter].presence || "all"

    scope = Incident.all

    if @query.present?
      scope = scope.where(
        "number LIKE :q OR short_description LIKE :q OR service_affected LIKE :q OR requested_by LIKE :q",
        q: "%#{@query}%"
      )
    end

    case @filter
    when "open"
      scope = scope.open_tickets
    when "in_progress"
      scope = scope.where(state: :in_progress)
    when "on_hold"
      scope = scope.where(state: :on_hold)
    when "resolved"
      scope = scope.resolved_tickets
    when "breached"
      scope = scope.sla_breached_tickets
    when "p1"
      scope = scope.open_tickets.where(priority: :p1_critical)
    else
      # "all" - varsayılan olarak açık olanları öne al
      scope = scope.order(
        Arel.sql("CASE WHEN state IN (0, 1, 2) THEN 0 ELSE 1 END ASC"),
        priority: :asc,
        created_at: :desc
      )
    end

    @incidents = scope.order(created_at: :desc)
    @open_incidents = Incident.open_tickets.order(priority: :asc, created_at: :desc)
    @resolved_incidents = Incident.resolved_tickets.order(resolved_at: :desc).limit(10)
    @breached_incidents = Incident.sla_breached_tickets.order(sla_breached_at: :desc).limit(10)

    # Kurumsal metrikler
    @total_count = Incident.count
    @open_count = Incident.open_tickets.count
    @in_progress_count = Incident.where(state: :in_progress).count
    @on_hold_count = Incident.where(state: :on_hold).count
    @resolved_count = Incident.resolved_tickets.count
    @breached_count = Incident.sla_breached_tickets.count
    @p1_count = Incident.open_tickets.where(priority: :p1_critical).count
  end

  def show
    @incident.check_sla!
    @timeline_events = @incident.timeline_events.order(created_at: :desc)

    # 100 Puanlık Acı Noktası Çözümü: Smart Incident Knowledge Matcher (Geçmiş Olay Hafızası)
    @similar_incidents = @incident.find_similar_incidents(limit: 3)
  end

  def new
    @incident = Incident.new(
      priority: :p2_high,
      category: "Enterprise Software",
      service_affected: "SAP ERP Production",
      requested_by: "Sarah Jenkins (Finance VP)"
    )
  end

  def create
    @incident = Incident.new(incident_params)

    if @incident.save
      redirect_to @incident, notice: "ITSM Bileti (#{@incident.number}) başarıyla oluşturuldu ve #{priority_label_for(@incident)} SLA süresi başlatıldı."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Durum Geçişi 1: İşleme Al (New / On Hold -> In Progress)
  def start_progress
    assignee = params[:assignee].presence || "Can Korkmaz (Senior ITSM Lead)"
    if @incident.start_progress!(assignee)
      redirect_to @incident, notice: "Bilet işleme alındı. Atanan Uzman: #{assignee}"
    else
      redirect_to @incident, alert: "Bilet işleme alınamadı."
    end
  end
  alias_method :investigate, :start_progress

  # Durum Geçişi 2: Beklemeye Al (In Progress -> On Hold)
  def put_on_hold
    reason = params[:on_hold_reason].presence || "3. Parti Tedarikçi / Kullanıcı Onayı Bekleniyor"
    if @incident.put_on_hold!(reason)
      redirect_to @incident, notice: "Bilet beklemeye (On Hold) alındı. Neden: #{reason}"
    else
      redirect_to @incident, alert: "Bilet beklemeye alınamadı."
    end
  end

  # Durum Geçişi 3: Çözümle ve Kapat (-> Resolved)
  def resolve
    notes = params[:resolution_notes].presence || params[:resolution_steps].presence || "Servis yapılandırması düzeltilerek erişim sağlandı."
    rca = params[:root_cause_analysis].presence || "Sistem kaynak sınırı aşıldı ve otomatik kurtarma mekanizması devreye alındı."

    if @incident.resolve!(resolution_notes: notes, root_cause: rca)
      redirect_to @incident, notice: "ITSM Bileti (#{@incident.number}) başarıyla çözüldü (Resolved) ve kurumsal hafızaya (Knowledge Base) eklendi."
    else
      redirect_to @incident, alert: "Bilet çözümlenirken bir hata oluştu."
    end
  end

  # 100 Puan Acı Noktası Aksiyonu: Tek Tıkla Geçmiş Bilgiyi Uygulama
  def apply_knowledge
    past_incident = Incident.find(params[:past_incident_id])
    if @incident.apply_knowledge_from!(past_incident)
      redirect_to @incident, notice: "⚡ Knowledge Base Çözümü Uygulandı! Bilet (#{past_incident.number}) referans alınarak anında çözüldü."
    else
      redirect_to @incident, alert: "Geçmiş bilgi uygulanamadı."
    end
  end

  # Zaman Kuralı: SLA Kontrolü Manuel Tetikleme (Test ve Canlı Sunum)
  def check_sla
    if @incident.check_sla!
      redirect_to @incident, alert: "⚠️ Kurumsal Kural İhlali: SLA süresi doldu! Bilet 'SLA Breached' statüsüne geçirildi."
    else
      remaining = @incident.sla_time_remaining_seconds
      redirect_to @incident, notice: "Bilet SLA süresi kural dahilinde. Kalan süre: #{remaining / 60} dakika #{remaining % 60} saniye."
    end
  end

  # Canlı gösterim simülasyon senaryoları
  def simulate
    scenario = params[:scenario] || "sap_erp"

    case scenario
    when "sap_erp"
      incident = Incident.create!(
        short_description: "SAP ERP S/4HANA Background Batch Pool Exhaustion (RFC 500 Connection Timeout)",
        service_affected: "SAP ERP",
        priority: :p1_critical,
        category: "Enterprise Software",
        requested_by: "Sarah Jenkins (Finance VP)",
        assignment_group: "Enterprise ERP Operations",
        description: "SAP S/4HANA Finans dönem kapanışı sırasında RFC work process havuzu tükendi. 42 muhasebe kullanıcısı işlem yapamıyor."
      )
    when "vpn_gateway"
      incident = Incident.create!(
        short_description: "Global VPN Gateway IP Pool Exhaustion (AnyConnect Pool Depleted)",
        service_affected: "Global VPN Gateway",
        priority: :p2_high,
        category: "Network Infrastructure",
        requested_by: "David Miller (Remote Workforce Director)",
        assignment_group: "Global Network Team",
        description: "GlobalAnyConnect gateway subnetinde boş IP kalmadı. 240+ uzaktan çalışan VPN tüneli kuramıyor."
      )
    when "active_directory"
      incident = Incident.create!(
        short_description: "Active Directory SSO Kerberos Clock Skew 401 Authentication Failure",
        service_affected: "Active Directory SSO",
        priority: :p2_high,
        category: "Identity & Security",
        requested_by: "Elena Rostova (Security Operations)",
        assignment_group: "Identity & Access Management",
        description: "Domain Controller'lar arasındaki NTP senkronizasyon sapması nedeniyle Kerberos biletleri reddediliyor."
      )
    else
      incident = Incident.create!(
        short_description: "Corporate Payment Gateway Timeout 504 (Database Connection Spike)",
        service_affected: "Payment Gateway",
        priority: :p1_critical,
        category: "Cloud Infrastructure",
        requested_by: "Michael Chang (E-Commerce Operations)",
        assignment_group: "Payment Infrastructure",
        description: "Ödeme altyapısında veritabanı bağlantı havuzu 15/15 sınıra ulaştı ve yeni checkout istekleri zaman aşımına düşüyor."
      )
    end

    redirect_to incident, notice: "⚡ Kurumsal ITSM Simülasyonu Başlatıldı! (#{incident.number}) - Smart Incident Knowledge Matcher geçmiş çözümleri arıyor..."
  end

  private

  def set_incident
    @incident = Incident.find(params[:id])
  end

  def incident_params
    params.require(:incident).permit(
      :short_description, :title, :description, :error_message, :service_affected, :service_name,
      :priority, :severity, :category, :requested_by, :caller_id, :assignment_group,
      :assigned_to, :resolution_notes, :root_cause_analysis
    )
  end

  def priority_label_for(inc)
    inc.priority_short_label
  end
end
