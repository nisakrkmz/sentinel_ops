require "test_helper"

class IncidentTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    TimelineEvent.delete_all
    Incident.delete_all
  end

  # =========================================================================
  # 1. SERVICENOW MODEL ALANLARI VE NUMARALANDIRMA (INC001024 Formatı)
  # =========================================================================

  test "yeni incident ServiceNow bilet numarası (INC00xxxx formatı) ile oluşturulur" do
    incident = Incident.create!(
      short_description: "SAP ERP Production User Session Lockout",
      service_affected: "SAP ERP",
      priority: :p1_critical,
      requested_by: "Sarah Jenkins (Finance VP)"
    )

    assert_match(/\AINC\d{6}\z/, incident.number)
    assert_equal "SAP ERP", incident.service_affected
    assert_equal "Sarah Jenkins (Finance VP)", incident.requested_by
    assert_equal "p1_critical", incident.priority
    assert_equal "new_ticket", incident.state
    assert_equal "within_sla", incident.sla_status
    assert_not_nil incident.sla_deadline
  end

  test "incident receives a demo actor and triage defaults while preserving idempotency uniqueness" do
    first = Incident.create!(
      short_description: "Database connection saturation",
      service_affected: "Payment Gateway",
      idempotency_key: "agent-event-001"
    )

    duplicate = Incident.new(
      short_description: "Repeated database connection saturation",
      service_affected: "Payment Gateway",
      idempotency_key: "agent-event-001"
    )

    assert_equal "ui", first.origin
    assert_equal "pending", first.triage_status
    assert first.opened_by_actor.human?
    assert_equal first.opened_by_actor_id, first.timeline_events.first.actor_id
    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :idempotency_key
  end

  test "önceliğe göre dinamik SLA süreleri doğru atanır (P1: 15m, P2: 2h, P3: 4h, P4: 24h)" do
    freeze_time do
      p1 = Incident.create!(short_description: "P1 Olay", service_affected: "Payment", priority: :p1_critical)
      p2 = Incident.create!(short_description: "P2 Olay", service_affected: "VPN", priority: :p2_high)
      p3 = Incident.create!(short_description: "P3 Olay", service_affected: "Email", priority: :p3_moderate)
      p4 = Incident.create!(short_description: "P4 Olay", service_affected: "Printer", priority: :p4_low)

      assert_equal Time.current + 15.minutes, p1.sla_deadline
      assert_equal Time.current + 2.hours, p2.sla_deadline
      assert_equal Time.current + 4.hours, p3.sla_deadline
      assert_equal Time.current + 24.hours, p4.sla_deadline
    end
  end

  # =========================================================================
  # 2. SERVICENOW ITSM DURUM AKIŞI (State Workflow: New -> In Progress -> On Hold -> Resolved)
  # =========================================================================

  test "durum akışı: New -> In Progress (start_progress!)" do
    incident = Incident.create!(
      short_description: "Active Directory SSO Lockout",
      service_affected: "Active Directory SSO",
      priority: :p2_high
    )

    assert incident.start_progress!("Can Korkmaz (Senior ITSM Lead)")
    assert_equal "in_progress", incident.reload.state
    assert_equal "Can Korkmaz (Senior ITSM Lead)", incident.assigned_to
    assert_not_nil incident.investigating_at

    last_event = incident.timeline_events.last
    assert_equal "in_progress_started", last_event.event_type
    assert_includes last_event.message, "Can Korkmaz"
  end

  test "durum akışı: In Progress -> On Hold (put_on_hold!)" do
    incident = Incident.create!(
      short_description: "Cisco AnyConnect Certificate Renewal",
      service_affected: "Global VPN Gateway",
      priority: :p3_moderate
    )
    incident.start_progress!("Network Engineer")

    assert incident.put_on_hold!("Sertifika otoritesinden yeni kök sertifika yanıtı bekleniyor")
    incident.reload
    assert_equal "on_hold", incident.state
    assert_includes incident.on_hold_reason, "Sertifika otoritesinden"

    last_event = incident.timeline_events.last
    assert_equal "on_hold", last_event.event_type
  end

  test "durum akışı: On Hold -> In Progress -> Resolved (resolve!)" do
    incident = Incident.create!(
      short_description: "SAP ERP Batch Work Process Saturation",
      service_affected: "SAP ERP",
      priority: :p1_critical
    )
    incident.start_progress!("SAP Admin")
    incident.put_on_hold!("Dönem sonu mutabakatı tamamlanması bekleniyor")
    incident.start_progress!("SAP Admin")

    assert incident.resolve!(
      resolution_notes: "SM50 work process havuzu 36'ya çıkarıldı.",
      root_cause: "Aşırı eşzamanlı RFC çağrısı"
    )

    incident.reload
    assert_equal "resolved", incident.state
    assert_equal "within_sla", incident.sla_status
    assert_not_nil incident.resolved_at
    assert_includes incident.resolution_notes, "SM50 work process havuzu"
    assert_includes incident.timeline_events.last.message, "Bilet çözüldü"
  end

  # =========================================================================
  # 3. ZAMAN KURALI & SLA TESTLERİ (travel_to kullanımı - Mecburi Kriter)
  # =========================================================================

  test "zaman kuralı: P1 (15m SLA) için 10. dakikada check_sla! ihlal oluşturmaz" do
    base_time = Time.zone.parse("2026-10-14 09:00:00")
    incident = nil

    travel_to base_time do
      incident = Incident.create!(
        short_description: "SAP S/4HANA Critical Lockout",
        service_affected: "SAP ERP",
        priority: :p1_critical
      )
    end

    # 10 dakika sonra (15 dakikalık SLA henüz dolmadı)
    travel_to base_time + 10.minutes do
      assert_equal false, incident.check_sla!
      assert_equal "within_sla", incident.reload.sla_status
      assert_equal false, incident.sla_expired?
      assert incident.sla_time_remaining_seconds > 0
    end
  end

  test "zaman kuralı: travel_to ile 20 dakika ileri sarıldığında P1 bilet 'SLA Breached' olur" do
    base_time = Time.zone.parse("2026-10-14 10:00:00")
    incident = nil

    travel_to base_time do
      incident = Incident.create!(
        short_description: "Payment Gateway DB Connection Spike",
        service_affected: "Payment Gateway",
        priority: :p1_critical
      )
      assert_equal base_time + 15.minutes, incident.sla_deadline
    end

    # 20 dakika ileri sarıyoruz (15 dakikalık SLA 5 dakika aşıldı)
    travel_to base_time + 20.minutes do
      assert incident.sla_expired?

      # SLA kontrolünü tetikliyoruz
      breached = incident.check_sla!
      assert_equal true, breached

      incident.reload
      assert_equal "sla_breached", incident.sla_status
      assert incident.sla_breached?
      assert_not_nil incident.sla_breached_at

      # Zaman çizelgesine SLA ihlal uyarısı düştü mü?
      breach_event = incident.timeline_events.find_by(event_type: "sla_breached")
      assert_not_nil breach_event
      assert_includes breach_event.message, "KURUMSAL SLA İHLALİ"
    end
  end

  test "zaman kuralı: P3 (4 saat SLA) için 3. saatte kural geçerli, 5. saatte SLA ihlali" do
    base_time = Time.zone.parse("2026-10-14 14:00:00")
    incident = nil

    travel_to base_time do
      incident = Incident.create!(
        short_description: "Corporate Wi-Fi Certificate Expired",
        service_affected: "Internal Network",
        priority: :p3_moderate
      )
      assert_equal base_time + 4.hours, incident.sla_deadline
    end

    # 3. saatte SLA geçerli
    travel_to base_time + 3.hours do
      assert_equal false, incident.check_sla!
      assert_equal "within_sla", incident.reload.sla_status
    end

    # 5. saatte SLA ihlal edildi
    travel_to base_time + 5.hours do
      assert_equal true, incident.check_sla!
      assert_equal "sla_breached", incident.reload.sla_status
      assert incident.sla_breached?
    end
  end

  test "zaman kuralı: SLA ihlali yaşayan bilet gecikmeli de olsa başarıyla çözümlenebilir" do
    base_time = Time.zone.parse("2026-10-14 11:00:00")
    incident = nil

    travel_to base_time do
      incident = Incident.create!(
        short_description: "Active Directory SSO Clock Drift",
        service_affected: "Active Directory SSO",
        priority: :p1_critical
      )
    end

    travel_to base_time + 30.minutes do
      incident.check_sla!
      assert incident.reload.sla_breached?

      # Gecikmeli çözüm uygulanıyor
      assert incident.resolve!(
        resolution_notes: "NTP senkronizasyonu DC-02 üzerinde yeniden sağlandı.",
        root_cause: "VM Time Sync modülü saat sapması"
      )

      assert_equal "resolved", incident.reload.state
      assert_equal "sla_breached", incident.sla_status
    end
  end
end
