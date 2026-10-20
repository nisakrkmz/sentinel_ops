# SentinelOps - ServiceNow ITSM Kurumsal Tohum Verileri (Knowledge Base / Incident Memory)
require "yaml"

TimelineEvent.delete_all
Handoff.delete_all
Decision.delete_all
Incident.delete_all

puts "Kurumsal ServiceNow ITSM Geçmiş Çözülmüş Biletleri (Knowledge Base) Ekleniyor..."

# 1. Çözülmüş Geçmiş Bilet: SAP ERP
inc1 = Incident.create!(
  number: "INC000840",
  short_description: "SAP ERP S/4HANA Background Batch Pool Exhaustion (RFC 500 Timeout)",
  service_affected: "SAP ERP",
  priority: :p1_critical,
  category: "Enterprise Software",
  requested_by: "Sarah Jenkins (Finance VP)",
  assignment_group: "Enterprise ERP Operations",
  assigned_to: "Alexander Wright (SAP Lead Architect)",
  state: :resolved,
  status: :resolved,
  sla_status: :within_sla,
  description: "SAP S/4HANA Finans dönem kapanışı sırasında RFC work process havuzu tükendi. 42 muhasebe kullanıcısı işlem yapamıyor.",
  created_at: 5.days.ago,
  investigating_at: 5.days.ago + 4.minutes,
  resolved_at: 5.days.ago + 13.minutes,
  sla_deadline: 5.days.ago + 15.minutes,
  root_cause_analysis: "SAP rdisp/wp_no_dia parametresi 12 ile sınırlıydı. Ay sonu toplu mutabakat job'ları eşzamanlı tetiklendiğinde work process havuzu tükendi.",
  resolution_notes: "1. SAP SM50 üzerinden batch work process havuzu dinamik olarak 12'den 36'ya çıkarıldı.\n2. Arka plan mutabakat job'ları için staggered cron kuyruğu devreye alındı.\n3. rdisp/max_wprun_time 600 saniyeye revize edilerek kilitlenen oturumlar temizlendi."
)

# 2. Çözülmüş Geçmiş Bilet: Global VPN Gateway
inc2 = Incident.create!(
  number: "INC000875",
  short_description: "Global VPN Gateway IP Pool Exhaustion (AnyConnect Subnet Depleted)",
  service_affected: "Global VPN Gateway",
  priority: :p2_high,
  category: "Network Infrastructure",
  requested_by: "David Miller (Remote Workforce Director)",
  assignment_group: "Global Network Operations",
  assigned_to: "Can Korkmaz (Network Lead)",
  state: :resolved,
  status: :resolved,
  sla_status: :within_sla,
  description: "AnyConnect VPN tüneli kurmak isteyen çalışanlar 'No address available in pool' hatası ile bağlantı kuramıyor.",
  created_at: 4.days.ago,
  investigating_at: 4.days.ago + 10.minutes,
  resolved_at: 4.days.ago + 45.minutes,
  sla_deadline: 4.days.ago + 2.hours,
  root_cause_analysis: "Cisco ASA / AnyConnect DHCP IP havuzu tek bir /24 subnet (254 host) ile sınırlı kalmıştı. Pazartesi sabahı eşzamanlı 320 talepte havuz tükendi.",
  resolution_notes: "1. AnyConnect gateway IP havuzuna ikincil /23 subnet (510 kullanılabilir host) tanımlandı.\n2. 8 saatten uzun süre boşta (idle) duran oturumlar için 45 dakikalık timeout kuralı uygulandı."
)

# 3. Çözülmüş Geçmiş Bilet: Active Directory Kerberos
inc3 = Incident.create!(
  number: "INC000912",
  short_description: "Active Directory SSO Kerberos Clock Skew 401 Authentication Failure",
  service_affected: "Active Directory SSO",
  priority: :p2_high,
  category: "Identity & Security",
  requested_by: "Elena Rostova (Security Operations)",
  assignment_group: "Identity & Access Management",
  assigned_to: "Robert Vance (Principal Security Eng)",
  state: :resolved,
  status: :resolved,
  sla_status: :within_sla,
  description: "Kurumsal çalışanlar VPN ve intranet portallarına giriş yaparken 'Kerberos ticket expired or clock skew too great' uyarısı alıyor.",
  created_at: 3.days.ago,
  investigating_at: 3.days.ago + 8.minutes,
  resolved_at: 3.days.ago + 52.minutes,
  sla_deadline: 3.days.ago + 2.hours,
  root_cause_analysis: "DC-02 Domain Controller üzerindeki sanallaştırma time sync modülü ile harici Stratum NTP sunucusu arasında 190 saniyelik saat kayması oluştu.",
  resolution_notes: "1. DC-02 üzerinde w32tm /resync komutuyla saat PDC Emulator ile senkronize edildi.\n2. VM Time Synchronization servisi kapatılıp donanımsal NTP sunucuları birincil yapıldı.\n3. Zabbix saat sapma alarmı kuruldu."
)

# 4. Çözülmüş Geçmiş Bilet: Payment Gateway
inc4 = Incident.create!(
  number: "INC000950",
  short_description: "Corporate Payment Gateway Timeout 504 (Database Connection Pool Spike)",
  service_affected: "Payment Gateway",
  priority: :p1_critical,
  category: "Cloud Infrastructure",
  requested_by: "Michael Chang (E-Commerce Operations)",
  assignment_group: "Platform Operations",
  assigned_to: "Sarah Jenkins (Lead SRE)",
  state: :resolved,
  status: :resolved,
  sla_status: :within_sla,
  description: "Ödeme altyapısında veritabanı bağlantı havuzu 15/15 sınıra ulaştı ve yeni checkout istekleri zaman aşımına düşüyor.",
  created_at: 2.days.ago,
  investigating_at: 2.days.ago + 2.minutes,
  resolved_at: 2.days.ago + 14.minutes,
  sla_deadline: 2.days.ago + 15.minutes,
  root_cause_analysis: "Pgbouncer üzerinde max_client_conn sınırı 15 idi. Kampanya döneminde %300 trafik artışında havuz tükendi.",
  resolution_notes: "1. database.yml havuz boyutu 15'ten 50'ye çıkarıldı.\n2. Pgbouncer transaction pooling moduna alındı.\n3. Connection leak yapan arka plan servisi yamalandı."
)

# 5. Aktif Açık Bilet (Canlı Gösterim & Test İçin)
active_ticket = Incident.create!(
  number: "INC001024",
  short_description: "SAP ERP S/4HANA Background Batch Pool Exhaustion (RFC 500 Connection Timeout)",
  service_affected: "SAP ERP",
  priority: :p1_critical,
  category: "Enterprise Software",
  requested_by: "Sarah Jenkins (Finance VP)",
  assignment_group: "Enterprise ERP Operations",
  assigned_to: "ITSM Triage Queue",
  state: :new_ticket,
  status: :reported,
  sla_status: :within_sla,
  description: "Maliye dönemsel KDV beyannamesi çalıştırılırken SAP S/4HANA work process havuzu kilitlendi. Kullanıcılar 'RFC 500 Resource Exhaustion' hatası alıyor.",
  created_at: Time.current,
  sla_deadline: Time.current + 15.minutes
)

# 6. İşlemde Olan Bilet (In Progress)
in_prog_ticket = Incident.create!(
  number: "INC001025",
  short_description: "Global VPN Gateway IP Pool Exhaustion (AnyConnect Subnet Depleted)",
  service_affected: "Global VPN Gateway",
  priority: :p2_high,
  category: "Network Infrastructure",
  requested_by: "David Miller (Remote Workforce Director)",
  assignment_group: "Global Network Operations",
  assigned_to: "Can Korkmaz (Network Lead)",
  state: :in_progress,
  status: :investigating,
  sla_status: :within_sla,
  description: "Avrupa ofisindeki 60'tan fazla mühendis VPN havuzundan IP alamadığını bildiriyor.",
  created_at: 25.minutes.ago,
  investigating_at: 15.minutes.ago,
  sla_deadline: Time.current + 95.minutes
)

puts "Başarıyla tamamlandı! #{Incident.count} ITSM bileti ve #{TimelineEvent.count} zaman çizelgesi kaydı oluşturuldu."

Incident.resolved_tickets.find_each do |incident|
  article = KnowledgeArticle.find_or_initialize_by(slug: "resolved-#{incident.number.downcase}")
  article.update!(
    title: incident.short_description,
    affected_service: incident.service_affected,
    category: incident.category,
    source: "resolved_incident",
    configuration_item: incident.service_affected,
    symptoms: incident.description,
    root_cause: incident.root_cause_analysis,
    resolution_steps: (incident.resolution_notes || incident.resolution_steps).to_s.lines.map(&:strip).reject(&:blank?),
    verification: "Seeded resolved incident reached Resolved state; independent technical verification details were not recorded.",
    approved: true,
    source_incident: incident
  )
  article.rebuild_chunks!
end

YAML.safe_load_file(Rails.root.join("config/knowledge_base.yml")).each do |entry|
  article = KnowledgeArticle.find_or_initialize_by(slug: entry.fetch("slug"))
  article.update!(**entry.symbolize_keys, source: "synthetic_seed", approved: true)
  article.rebuild_chunks!
end

puts "Incident Memory: #{KnowledgeArticle.count} approved articles, #{KnowledgeChunk.count} structured chunks (synthetic seeds are labeled)."
