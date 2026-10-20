require "digest"
require "base64"
require "json"

module Api
  module V1
    class IncidentsController < BaseController
      QUEUE_ASSIGNEES = [ "ITSM Triage Queue", "Triage Team (Otomatik)" ].freeze

      def index
        return unless require_scope!("incidents:read")

        incidents = Incident.all
        if params[:state].present?
          unless Incident.states.key?(params[:state])
            return render_error(code: "invalid_state", message: "The state filter is invalid.", status: :bad_request, field_errors: { state: [ "is invalid" ] })
          end
          incidents = incidents.where(state: params[:state])
        end
        if params[:priority].present?
          priority = priority_value(params[:priority])
          return render_error(code: "invalid_priority", message: "The priority filter is invalid.", status: :bad_request, field_errors: { priority: [ "is invalid" ] }) unless priority

          incidents = incidents.where(priority: priority)
        end
        incidents = incidents.where(service_affected: params[:service]) if params[:service].present?

        cursor = decode_cursor
        return if performed?
        incidents = incidents.where(
          "created_at < :created_at OR (created_at = :created_at AND id < :id)",
          created_at: cursor.fetch(:created_at),
          id: cursor.fetch(:id)
        ) if cursor

        limit = page_limit
        return if performed?
        rows = incidents.order(created_at: :desc, id: :desc).limit(limit + 1).to_a
        has_more = rows.length > limit
        rows = rows.first(limit)
        render json: {
          data: rows.map { |incident| serialize_incident(incident) },
          next_cursor: has_more ? encode_cursor(rows.last) : nil
        }
      end

      def create
        return unless require_scope!("incidents:create")

        key = request.headers["Idempotency-Key"].to_s.strip
        unless key.present? && key.length <= 255 && !key.match?(/[\r\n]/)
          return render_error(
            code: "idempotency_key_required",
            message: "A valid Idempotency-Key header is required.",
            status: :bad_request,
            field_errors: { idempotency_key: [ "is required and must be at most 255 characters" ] }
          )
        end

        attributes = incident_params
        required_fields = %w[short_description service_affected]
        field_errors = required_fields.each_with_object({}) do |field, errors|
          errors[field] = [ "is required" ] if attributes[field].blank?
        end
        if field_errors.any?
          return render_error(
            code: "validation_failed",
            message: "Short description and affected service are required.",
            status: :unprocessable_entity,
            field_errors: field_errors
          )
        end
        attributes["requested_by"] = current_actor.name if attributes["requested_by"].blank?

        existing = Incident.find_by(idempotency_key: key)
        return render_idempotent_replay(existing, attributes) if existing

        incident = Incident.new(
          attributes.merge(
            idempotency_key: key,
            idempotency_request_digest: request_digest(attributes),
            origin: "api",
            opened_by_actor: current_actor,
            triage_status: "pending"
          )
        )
        unless incident.save
          return render_error(
            code: "validation_failed",
            message: "The incident could not be created.",
            status: :unprocessable_entity,
            field_errors: incident.errors.messages
          )
        end

        Triage::Runner.call(incident)
        render json: { data: serialize_incident(incident, include_triage: true) }, status: :created
      rescue ActiveRecord::RecordNotUnique
        existing = Incident.find_by!(idempotency_key: key)
        attributes = incident_params
        attributes["requested_by"] = current_actor.name if attributes["requested_by"].blank?
        render_idempotent_replay(existing, attributes)
      end

      def show
        return unless require_scope!("incidents:read")

        incident = find_incident
        return render_not_found unless incident

        render json: { data: serialize_incident(incident, include_triage: true) }
      end

      def create_comment
        return unless require_scope!("incidents:comment")

        incident = find_incident
        return render_not_found unless incident

        content = params[:content]
        unless content.is_a?(String) && content.present? && content.length <= 5_000
          return render_error(
            code: "validation_failed",
            message: "A non-empty comment of at most 5000 characters is required.",
            status: :unprocessable_entity,
            field_errors: { content: [ "is required and must be at most 5000 characters" ] }
          )
        end

        event = incident.timeline_events.create!(actor: current_actor, event_type: "comment", message: content)
        render json: { data: serialize_timeline_event(event) }, status: :created
      end

      def claim
        return unless require_scope!("incidents:claim")

        incident = find_incident
        return render_not_found unless incident
        return render_error(code: "incident_not_claimable", message: "Resolved incidents cannot be claimed.", status: :conflict) if incident.resolved? || incident.closed?

        conflict = false
        incident.with_lock do
          assignee = incident.assigned_to
          if assignee.present? && !QUEUE_ASSIGNEES.include?(assignee) && assignee != current_actor.name
            conflict = true
          else
            incident.update!(assigned_to: current_actor.name)
            incident.timeline_events.create!(
              actor: current_actor,
              event_type: "claimed",
              message: "Incident claimed by agent #{current_actor.name}."
            )
          end
        end
        return render_error(code: "incident_already_claimed", message: "The incident is already assigned to another operator.", status: :conflict) if conflict

        render json: { data: serialize_incident(incident.reload) }
      end

      def resolve
        return unless require_scope!("incidents:resolve")

        incident = find_incident
        return render_not_found unless incident

        notes = params[:resolution_notes]
        root_cause = params[:root_cause]
        citations = params[:citations]
        unless notes.is_a?(String) && notes.present? && root_cause.is_a?(String) && root_cause.present? &&
            citations.is_a?(Array) && citations.length <= 50 && citations.all? { |citation| citation.is_a?(String) }
          return render_error(
            code: "validation_failed",
            message: "Resolution notes, root cause, and a citations array are required.",
            status: :unprocessable_entity,
            field_errors: {
              resolution_notes: [ "is required" ],
              root_cause: [ "is required" ],
              citations: [ "must be an array" ]
            }
          )
        end

        valid_citations = KnowledgeChunk.joins(:knowledge_article)
          .where(knowledge_articles: { approved: true })
          .where(chunk_id: citations)
          .pluck(:chunk_id)
        invalid = citations - valid_citations
        return render_error(code: "invalid_citations", message: "Every citation must identify an approved knowledge chunk.", status: :unprocessable_entity, field_errors: { citations: invalid }) if invalid.any?
        return render_error(code: "incident_already_resolved", message: "The incident is already resolved or closed.", status: :conflict) if incident.resolved? || incident.closed?

        verification = params[:verification]
        incident.transaction do
          incident.resolve!(resolution_notes: notes, root_cause: root_cause)
          if verification.is_a?(String) && verification.present?
            incident.kb_candidates.create!(
              submitted_by: current_actor,
              root_cause: root_cause,
              resolution_steps: [ notes ],
              verification: verification
            )
          end
        end
        render json: { data: serialize_incident(incident.reload), citations: citations }
      end

      def handoff
        return unless require_scope!("handoff:create")

        incident = find_incident
        return render_not_found unless incident

        reason_code = params[:reason_code]
        target = params[:to_actor_or_group]
        brief = params[:brief]
        brief = brief.to_unsafe_h if brief.is_a?(ActionController::Parameters)
        unless reason_code.is_a?(String) && reason_code.present? &&
            target.is_a?(String) && target.present? && brief.is_a?(Hash)
          return render_error(
            code: "validation_failed",
            message: "A reason code, destination, and structured brief are required.",
            status: :unprocessable_entity,
            field_errors: { reason_code: [ "is required" ], to_actor_or_group: [ "is required" ], brief: [ "must be an object" ] }
          )
        end

        handoff = incident.handoffs.create!(
          from_actor: current_actor,
          to_actor_or_group: target,
          reason_code: reason_code,
          confidence: params[:confidence],
          brief: brief
        )
        incident.update!(triage_status: "needs_human")
        incident.timeline_events.create!(
          actor: current_actor,
          event_type: "handoff_created",
          message: "Incident handed off to #{target} (#{reason_code})."
        )
        render json: { data: serialize_handoff(handoff) }, status: :created
      rescue ActiveRecord::RecordInvalid => error
        render_error(
          code: "validation_failed",
          message: "The handoff could not be created.",
          status: :unprocessable_entity,
          field_errors: error.record.errors.messages
        )
      end

      private

      def incident_params
        params.permit(:short_description, :description, :service_affected, :category, :requested_by).to_h
      end

      def render_idempotent_replay(incident, attributes)
        unless incident.idempotency_request_digest == request_digest(attributes)
          return render_error(
            code: "idempotency_key_reused",
            message: "The Idempotency-Key has already been used for a different request.",
            status: :conflict
          )
        end

        render json: { data: serialize_incident(incident, include_triage: true), idempotent_replay: true }, status: :ok
      end

      def request_digest(attributes)
        Digest::SHA256.hexdigest(JSON.generate(attributes.sort.to_h))
      end

      def priority_value(value)
        { "P1" => "p1_critical", "P2" => "p2_high", "P3" => "p3_moderate", "P4" => "p4_low" }[value.to_s.upcase]
      end

      def find_incident
        Incident.find_by(number: params[:id]) || (params[:id].to_s.match?(/\A\d+\z/) && Incident.find_by(id: params[:id]))
      end

      def render_not_found
        render_error(code: "incident_not_found", message: "The incident was not found.", status: :not_found)
      end

      def page_limit
        value = Integer(params.fetch(:limit, rate_limit_settings.fetch("default_page_size")))
        max = rate_limit_settings.fetch("maximum_page_size")
        return value if value.between?(1, max)

        render_error(code: "invalid_page_size", message: "The page size is outside the allowed range.", status: :bad_request, field_errors: { limit: [ "must be between 1 and #{max}" ] })
        nil
      rescue ArgumentError, TypeError
        render_error(code: "invalid_page_size", message: "The page size must be an integer.", status: :bad_request, field_errors: { limit: [ "must be an integer" ] })
        nil
      end

      def decode_cursor
        return unless params[:cursor].present?

        value = JSON.parse(Base64.urlsafe_decode64(params[:cursor]))
        timestamp = Time.iso8601(value.fetch("created_at"))
        id = Integer(value.fetch("id"))
        raise ArgumentError unless id.positive?

        { created_at: timestamp, id: id }
      rescue ArgumentError, KeyError, JSON::ParserError, TypeError
        render_error(code: "invalid_cursor", message: "The pagination cursor is invalid.", status: :bad_request)
        nil
      end

      def encode_cursor(incident)
        Base64.urlsafe_encode64(
          JSON.generate(created_at: incident.created_at.iso8601(6), id: incident.id),
          padding: false
        )
      end

      def serialize_incident(incident, include_triage: false)
        result = {
          id: incident.id,
          number: incident.number,
          short_description: incident.short_description,
          description: incident.description,
          service_affected: incident.service_affected,
          category: incident.category,
          priority: { "p1_critical" => "P1", "p2_high" => "P2", "p3_moderate" => "P3", "p4_low" => "P4" }.fetch(incident.priority),
          state: incident.state,
          triage_status: incident.triage_status,
          assignment_group: incident.assignment_group,
          assigned_to: incident.assigned_to,
          origin: incident.origin,
          sla_status: incident.sla_status,
          sla_deadline: incident.sla_deadline&.iso8601,
          created_at: incident.created_at.iso8601,
          opened_by: incident.opened_by_actor&.name
        }
        if include_triage
          decision = incident.decisions.triage.order(created_at: :desc).first
          result[:triage] = decision && {
            status: decision.status,
            provider: decision.provider,
            model: decision.model,
            confidence: decision.confidence,
            output: decision.output_json,
            error_code: decision.error_code
          }
        end
        result
      end

      def serialize_timeline_event(event)
        { id: event.id, type: event.event_type, message: event.message, actor: event.actor&.name, created_at: event.created_at.iso8601 }
      end

      def serialize_handoff(handoff)
        {
          id: handoff.id,
          incident_id: handoff.incident_id,
          destination: handoff.to_actor_or_group,
          reason_code: handoff.reason_code,
          confidence: handoff.confidence,
          brief: handoff.brief,
          status: handoff.status,
          created_at: handoff.created_at.iso8601
        }
      end
    end
  end
end
