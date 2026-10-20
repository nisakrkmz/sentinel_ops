require "digest"
require "json"

class McpController < Api::V1::BaseController
  PROTOCOL_VERSION = "2025-03-26"

  class ToolError < StandardError
    attr_reader :code, :field_errors

    def initialize(code, message, field_errors: {})
      super(message)
      @code = code
      @field_errors = field_errors
    end
  end

  def handle
    body = request.request_parameters
    unless body.is_a?(Hash) && body["jsonrpc"] == "2.0" && body["method"].is_a?(String)
      return render_jsonrpc_error(body.is_a?(Hash) ? body["id"] : nil, -32_600, "Invalid JSON-RPC request.")
    end

    @request_id = body["id"]
    case body["method"]
    when "initialize"
      initialize_session(body["params"] || {})
    when "notifications/initialized"
      head :accepted
    when "ping"
      render json: jsonrpc_result({})
    when "tools/list"
      render json: jsonrpc_result(tools: tool_definitions)
    when "tools/call"
      call_tool(body["params"])
    else
      render_jsonrpc_error(@request_id, -32_601, "Method not found.")
    end
  end

  private

  def initialize_session(parameters)
    version = parameters["protocolVersion"]
    unless version == PROTOCOL_VERSION
      return render_jsonrpc_error(@request_id, -32_602, "Unsupported MCP protocol version.")
    end

    render json: jsonrpc_result(
      protocolVersion: PROTOCOL_VERSION,
      capabilities: { tools: { listChanged: false } },
      serverInfo: { name: "SentinelOps", version: "1.0.0" }
    )
  end

  def call_tool(parameters)
    unless parameters.is_a?(Hash) && parameters["name"].is_a?(String)
      return render_jsonrpc_error(@request_id, -32_602, "Tool name is required.")
    end
    arguments = parameters["arguments"] || {}
    return render_jsonrpc_error(@request_id, -32_602, "Tool arguments must be an object.") unless arguments.is_a?(Hash)

    result = execute_tool(parameters["name"], arguments)
    render json: jsonrpc_result(tool_result(result))
  rescue ToolError => error
    render json: jsonrpc_result(tool_result(
      { code: error.code, message: error.message, field_errors: error.field_errors },
      is_error: true
    ))
  rescue Rag::ProviderError => error
    render json: jsonrpc_result(tool_result(
      { code: error.code, message: error.message, retryable: true },
      is_error: true
    ))
  rescue ActiveRecord::RecordInvalid => error
    render json: jsonrpc_result(tool_result(
      { code: "validation_failed", message: error.record.errors.full_messages.join(", "), field_errors: error.record.errors.messages },
      is_error: true
    ))
  end

  def execute_tool(name, arguments)
    case name
    when "open_incident"
      open_incident(arguments)
    when "search_kb"
      search_kb(arguments)
    when "get_incident"
      get_incident(arguments)
    when "propose_resolution"
      propose_resolution(arguments)
    when "resolve_incident"
      resolve_incident(arguments)
    when "handoff_to_human"
      handoff_to_human(arguments)
    else
      raise ToolError.new("unknown_tool", "The requested tool is not available.")
    end
  end

  def open_incident(arguments)
    require_tool_scope!("incidents:create")
    key = required_string(arguments, "idempotency_key")
    unless key.length <= 255 && !key.match?(/[\r\n]/)
      raise ToolError.new("invalid_arguments", "idempotency_key must be at most 255 characters and contain no line breaks.")
    end
    attributes = %w[short_description description service_affected category requested_by].each_with_object({}) do |field, values|
      values[field] = arguments[field] if arguments.key?(field)
    end
    required_string(attributes, "short_description")
    required_string(attributes, "service_affected")
    attributes["requested_by"] = current_actor.name if attributes["requested_by"].blank?
    digest = Digest::SHA256.hexdigest(JSON.generate(attributes.sort.to_h))
    existing = Incident.find_by(idempotency_key: key)
    if existing
      raise ToolError.new("idempotency_key_reused", "The idempotency key belongs to a different request.") unless existing.idempotency_request_digest == digest

      return incident_data(existing, replay: true)
    end

    incident = Incident.create!(
      **attributes.symbolize_keys,
      idempotency_key: key,
      idempotency_request_digest: digest,
      origin: "mcp",
      opened_by_actor: current_actor,
      triage_status: "pending"
    )
    Triage::Runner.call(incident)
    incident_data(incident.reload)
  rescue ActiveRecord::RecordNotUnique
    existing = Incident.find_by!(idempotency_key: key)
    raise ToolError.new("idempotency_key_reused", "The idempotency key belongs to a different request.") unless existing.idempotency_request_digest == digest

    incident_data(existing, replay: true)
  end

  def search_kb(arguments)
    require_tool_scope!("kb:read")
    query = required_string(arguments, "query")
    result = Rag::Retriever.call(query)
    {
      results: result.chunks.map do |entry|
        chunk = entry.fetch(:chunk)
        article = chunk.knowledge_article
        {
          chunk_id: chunk.chunk_id,
          title: article.title,
          service: article.affected_service,
          source: article.source,
          content: chunk.content,
          similarity: entry.fetch(:similarity)
        }
      end
    }
  end

  def get_incident(arguments)
    require_tool_scope!("incidents:read")
    incident = find_incident(required_string(arguments, "incident_id"))
    raise ToolError.new("incident_not_found", "The incident was not found.") unless incident

    incident_data(incident)
  end

  def propose_resolution(arguments)
    require_tool_scope!("incidents:read")
    require_tool_scope!("kb:read")
    incident = find_incident(required_string(arguments, "incident_id"))
    raise ToolError.new("incident_not_found", "The incident was not found.") unless incident

    result = Rag::Workflow.call(incident)
    {
      status: result.status,
      error_code: result.error_code,
      decision: result.decision&.output_json,
      provider: result.decision&.provider,
      model: result.decision&.model,
      confidence: result.decision&.confidence,
      citations: result.decision&.sources || []
    }
  end

  def resolve_incident(arguments)
    require_tool_scope!("incidents:resolve")
    incident = find_incident(required_string(arguments, "incident_id"))
    raise ToolError.new("incident_not_found", "The incident was not found.") unless incident
    raise ToolError.new("incident_already_resolved", "The incident is already resolved or closed.") if incident.resolved? || incident.closed?

    notes = required_string(arguments, "resolution_notes")
    root_cause = required_string(arguments, "root_cause")
    citations = arguments["citations"]
    unless citations.is_a?(Array) && citations.length <= 50 && citations.all? { |citation| citation.is_a?(String) }
      raise ToolError.new("invalid_citations", "Citations must be an array of at most 50 chunk IDs.")
    end
    valid = KnowledgeChunk.joins(:knowledge_article)
      .where(knowledge_articles: { approved: true })
      .where(chunk_id: citations)
      .pluck(:chunk_id)
    invalid = citations - valid
    raise ToolError.new("invalid_citations", "Every citation must identify an approved knowledge chunk.", field_errors: { citations: invalid }) if invalid.any?

    incident.transaction do
      incident.resolve!(resolution_notes: notes, root_cause: root_cause)
      verification = arguments["verification"]
      if verification.is_a?(String) && verification.present?
        incident.kb_candidates.create!(
          submitted_by: current_actor,
          root_cause: root_cause,
          resolution_steps: [ notes ],
          verification: verification
        )
      end
    end
    { incident: incident_data(incident.reload), citations: citations }
  end

  def handoff_to_human(arguments)
    require_tool_scope!("handoff:create")
    incident = find_incident(required_string(arguments, "incident_id"))
    raise ToolError.new("incident_not_found", "The incident was not found.") unless incident

    reason_code = required_string(arguments, "reason_code")
    destination = required_string(arguments, "to_actor_or_group")
    brief = arguments["brief"]
    raise ToolError.new("invalid_brief", "The brief must be a structured object.") unless brief.is_a?(Hash)

    handoff = incident.handoffs.create!(
      from_actor: current_actor,
      to_actor_or_group: destination,
      reason_code: reason_code,
      confidence: arguments["confidence"],
      brief: brief
    )
    incident.update!(triage_status: "needs_human")
    incident.timeline_events.create!(
      actor: current_actor,
      event_type: "handoff_created",
      message: "Incident handed off to #{destination} (#{reason_code})."
    )
    {
      id: handoff.id,
      incident_id: handoff.incident_id,
      destination: handoff.to_actor_or_group,
      reason_code: handoff.reason_code,
      confidence: handoff.confidence,
      brief: handoff.brief,
      status: handoff.status
    }
  end

  def require_tool_scope!(scope)
    return if api_token.allows?(scope)

    raise ToolError.new("insufficient_scope", "The token does not grant #{scope}.", field_errors: { scope: [ scope ] })
  end

  def required_string(arguments, key)
    value = arguments[key]
    return value if value.is_a?(String) && value.present?

    raise ToolError.new("invalid_arguments", "#{key} is required.", field_errors: { key => [ "is required" ] })
  end

  def find_incident(identifier)
    Incident.find_by(number: identifier) || (identifier.match?(/\A\d+\z/) && Incident.find_by(id: identifier))
  end

  def incident_data(incident, replay: false)
    decision = incident.decisions.triage.order(created_at: :desc).first
    {
      id: incident.id,
      number: incident.number,
      short_description: incident.short_description,
      service_affected: incident.service_affected,
      priority: incident.priority,
      state: incident.state,
      triage_status: incident.triage_status,
      triage: decision && {
        status: decision.status,
        provider: decision.provider,
        model: decision.model,
        output: decision.output_json,
        error_code: decision.error_code
      },
      idempotent_replay: replay
    }
  end

  def tool_definitions
    [
      tool("open_incident", "Create and triage an incident. Requires incidents:create.", %w[idempotency_key short_description service_affected], {
        idempotency_key: { type: "string" },
        short_description: { type: "string" },
        description: { type: "string" },
        service_affected: { type: "string" },
        category: { type: "string" },
        requested_by: { type: "string" }
      }),
      tool("search_kb", "Search approved, embedded knowledge. Requires kb:read.", %w[query], { query: { type: "string" } }),
      tool("get_incident", "Get incident details and triage provenance. Requires incidents:read.", %w[incident_id], { incident_id: { type: "string" } }),
      tool("propose_resolution", "Create a sourced resolution proposal without executing it. Requires incidents:read and kb:read.", %w[incident_id], { incident_id: { type: "string" } }),
      tool("resolve_incident", "Resolve with approved knowledge citations. Requires incidents:resolve.", %w[incident_id resolution_notes root_cause citations], {
        incident_id: { type: "string" },
        resolution_notes: { type: "string" },
        root_cause: { type: "string" },
        verification: { type: "string" },
        citations: { type: "array", items: { type: "string" } }
      }),
      tool("handoff_to_human", "Hand an incident to a human or group with a structured brief. Requires handoff:create.", %w[incident_id reason_code to_actor_or_group brief], {
        incident_id: { type: "string" },
        reason_code: { type: "string" },
        to_actor_or_group: { type: "string" },
        confidence: { type: "number", minimum: 0, maximum: 1 },
        brief: { type: "object" }
      })
    ]
  end

  def tool(name, description, required, properties)
    {
      name: name,
      description: description,
      inputSchema: {
        type: "object",
        properties: properties.deep_stringify_keys,
        required: required
      }
    }
  end

  def tool_result(value, is_error: false)
    {
      content: [ { type: "text", text: JSON.generate(value) } ],
      structuredContent: value,
      isError: is_error
    }
  end

  def jsonrpc_result(result)
    { jsonrpc: "2.0", id: @request_id, result: result }
  end

  def render_jsonrpc_error(id, code, message)
    render json: { jsonrpc: "2.0", id: id, error: { code: code, message: message } }
  end
end
