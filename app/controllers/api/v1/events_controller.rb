module Api
  module V1
    class EventsController < BaseController
      def index
        return unless require_scope!("events:read")

        cursor = params[:last_event_id].presence || request.headers["Last-Event-ID"].presence || "0"
        last_event_id = Integer(cursor)
        return render_error(code: "invalid_event_cursor", message: "Last-Event-ID must be a non-negative integer.", status: :bad_request) if last_event_id.negative?

        events = TimelineEvent.includes(:incident, :actor)
          .where("timeline_events.id > ?", last_event_id)
          .order(:id)
          .limit(100)
        payload = events.map do |event|
          data = {
            incident_id: event.incident_id,
            incident_number: event.incident.number,
            type: event.event_type,
            message: event.message,
            actor: event.actor&.name,
            created_at: event.created_at.iso8601
          }
          "id: #{event.id}\nevent: incident\ndata: #{JSON.generate(data)}\n\n"
        end
        payload.unshift("retry: 5000\n")
        payload << ": keep-alive\n\n" if events.empty?
        render plain: payload.join, content_type: "text/event-stream"
      rescue ArgumentError, TypeError
        render_error(code: "invalid_event_cursor", message: "Last-Event-ID must be a non-negative integer.", status: :bad_request)
      end
    end
  end
end
