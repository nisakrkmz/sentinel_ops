class HandoffsController < ApplicationController
  before_action :set_current_actor
  before_action :set_handoff, only: [ :accept, :reject ]

  def index
    @handoffs = Handoff.open.includes(:incident, :from_actor).order(created_at: :asc)
  end

  def accept
    return redirect_to handoffs_path, alert: "Bu devir artık açık değil." unless @handoff.open?

    incident = @handoff.incident
    resolution = incident.decisions.resolution.order(created_at: :desc).first
    source_ids = resolution&.sources || @handoff.brief.fetch("sources", [])
    chunks = KnowledgeChunk.includes(:knowledge_article)
      .joins(:knowledge_article)
      .where(knowledge_articles: { approved: true })
      .where(chunk_id: source_ids)
    suggested_steps = resolution&.output_json&.fetch("steps", []) || []
    notes = params[:resolution_notes].presence || suggested_steps.map { |step| step["text"] }.join("\n")
    root_cause = params[:root_cause].presence || chunks.map { |chunk| chunk.knowledge_article.root_cause }.uniq.join("\n")

    unless notes.present? && root_cause.present?
      return redirect_to handoffs_path, alert: "Onay için çözüm notları ve kök neden gereklidir; eksik alanları düzeltip tekrar deneyin."
    end

    feedback = params[:review_action] == "correct" ? "corrected" : "approved"
    incident.transaction do
      @handoff.update!(status: :accepted, resolved_by: Current.actor)
      incident.resolve!(resolution_notes: notes, root_cause: root_cause)
      if params[:verification].present?
        incident.kb_candidates.create!(
          submitted_by: Current.actor,
          root_cause: root_cause,
          resolution_steps: notes.lines.map(&:strip).reject(&:blank?),
          verification: params[:verification]
        )
      end
      record_feedback(incident, feedback, resolution&.sources || [], params[:feedback])
      incident.timeline_events.create!(
        actor: Current.actor,
        event_type: "handoff_accepted",
        message: "Human operator #{feedback} the agent proposal and resolved the incident."
      )
    end

    redirect_to incident, notice: "Devir onaylandı; olay insan operatör tarafından çözüldü."
  rescue ActiveRecord::RecordInvalid
    redirect_to handoffs_path, alert: "Onay kaydedilemedi. Handoff hâlâ açıksa bilgileri kontrol edip tekrar deneyin."
  end

  def reject
    return redirect_to handoffs_path, alert: "Bu devir artık açık değil." unless @handoff.open?

    incident = @handoff.incident
    incident.transaction do
      @handoff.update!(status: :rejected, resolved_by: Current.actor)
      record_feedback(incident, "rejected", [], params[:feedback])
      incident.timeline_events.create!(
        actor: Current.actor,
        event_type: "handoff_rejected",
        message: "Human operator rejected the agent proposal: #{params[:feedback].presence || 'No reason supplied.'}"
      )
    end
    redirect_to handoffs_path, notice: "Agent önerisi reddedildi ve geri bildirim denetim izine kaydedildi."
  rescue ActiveRecord::RecordInvalid
    redirect_to handoffs_path, alert: "Devir reddedilemedi."
  end

  private

  def set_current_actor
    Current.actor = Actor.demo_ui_operator
  end

  def set_handoff
    @handoff = Handoff.find(params[:id])
  end

  def record_feedback(incident, action, sources, feedback)
    incident.decisions.create!(
      actor: Current.actor,
      kind: :verify,
      provider: "human-review",
      model: "operator",
      prompt_version: "hitl-feedback-v1",
      output_json: { "action" => action, "feedback" => feedback.to_s },
      sources: sources
    )
  end
end
