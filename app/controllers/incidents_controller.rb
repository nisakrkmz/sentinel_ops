class IncidentsController < ApplicationController
  before_action :set_current_actor
  before_action :set_incident, only: [ :show, :start_progress, :investigate, :put_on_hold, :resolve, :check_sla, :suggest_resolution, :approve_kb_candidate, :reject_kb_candidate ]

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

    @triage_attempt = @incident.decisions.triage.order(created_at: :desc).first
    @policy_decision = @incident.decisions.route.order(created_at: :desc).first
    @handoff = @incident.handoffs.open.order(created_at: :desc).first
    @agent_trace = @incident.decisions.where(kind: %w[triage resolution route verify]).order(created_at: :asc)
    @resolution_decision = @incident.decisions.resolution.order(created_at: :desc).first
    @relevance_decision = @incident.decisions.verify.order(created_at: :desc).first
    @citation_chunks = KnowledgeChunk.includes(:knowledge_article).where(chunk_id: @resolution_decision&.sources || [])
    @kb_candidates = @incident.kb_candidates.order(created_at: :desc)
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
      result = AgentWorkflow::Runner.call(@incident)
      notice = "ITSM Bileti (#{@incident.number}) oluşturuldu. #{workflow_notice(result)}"
      redirect_to @incident, notice: notice
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
    notes = params[:resolution_notes].presence || params[:resolution_steps].presence
    rca = params[:root_cause_analysis].presence
    verification = params[:verification].presence
    unless notes && rca && verification
      return redirect_to @incident, alert: "Kök neden, çözüm notları ve doğrulama sonucu gereklidir."
    end

    Incident.transaction do
      @incident.resolve!(resolution_notes: notes, root_cause: rca)
      @incident.kb_candidates.create!(
        submitted_by: Current.actor,
        root_cause: rca,
        resolution_steps: notes.lines.map(&:strip).reject(&:blank?),
        verification: verification
      )
    end
    redirect_to @incident, notice: "ITSM Bileti (#{@incident.number}) çözüldü. Çözüm, Knowledge Base'e eklenmeden önce insan onay kuyruğuna alındı."
  rescue ActiveRecord::RecordInvalid
    redirect_to @incident, alert: "Bilet çözümü veya Knowledge Base adayı kaydedilemedi."
  end

  def suggest_resolution
    result = Rag::Workflow.call(@incident)
    if result.suggested?
      redirect_to @incident, notice: "Kaynaklı çözüm önerisi hazırlandı; aksiyonlar uygulanmadı."
    elsif result.status == "insufficient_evidence"
      redirect_to @incident, alert: "Knowledge Base'te yeterli kanıt yok. İnsan incelemesi gerekli."
    else
      redirect_to @incident, alert: "Incident Memory kullanılamıyor (#{result.error_code}). Otomatik çözüm üretilmedi."
    end
  end

  def approve_kb_candidate
    candidate = @incident.kb_candidates.pending_review.find(params[:candidate_id])
    candidate.approve!(Current.actor)
    indexed = Rag::Indexer.call(article: candidate.knowledge_article)
    redirect_to @incident, notice: "Knowledge Base adayı onaylandı ve #{indexed.indexed} parça indekslendi."
  rescue Rag::ProviderError => error
    redirect_to @incident, alert: "Aday onaylandı, ancak embedding indeksi güncellenemedi (#{error.code}). Sağlayıcıyı yapılandırıp indeksleme komutunu çalıştırın."
  rescue ActiveRecord::RecordInvalid
    redirect_to @incident, alert: "Knowledge Base adayı onaylanamadı."
  end

  def reject_kb_candidate
    candidate = @incident.kb_candidates.pending_review.find(params[:candidate_id])
    candidate.reject!(Current.actor)
    redirect_to @incident, notice: "Knowledge Base adayı reddedildi ve Incident Memory'ye eklenmedi."
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
    Current.actor = Actor.find_or_create_by!(kind: :agent, name: "SentinelOps Monitoring Agent") do |actor|
      actor.owner = "SentinelOps"
      actor.scopes = []
    end

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

    incident.update!(origin: :simulation, opened_by_actor: Current.actor)
    result = AgentWorkflow::Runner.call(incident)
    notice = "Kurumsal senaryo (#{incident.number}) oluşturuldu. #{workflow_notice(result)}"
    redirect_to incident, notice: notice
  end

  private

  def set_incident
    @incident = Incident.find(params[:id])
  end

  def set_current_actor
    Current.actor = current_actor
  end

  def workflow_notice(result)
    case result.status
    when "auto_resolve"
      "Agent kaynaklı çözüm önerisini politika kapsamında uyguladı."
    when "approval_required"
      "Agent önerisi insan onay kuyruğunda; olay kapatılmadı."
    when "handoff"
      "Triage/kanıt beklemede — olay insan kuyruğuna devredildi."
    when "already_resolved"
      "Olay daha önce çözülmüş."
    else
      "Agent iş akışı tamamlandı: #{result.status}."
    end
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
