require "json"
require "yaml"

module Triage
  class Schema
    PRIORITIES = %w[P1 P2 P3 P4].freeze
    IMPACTS = %w[enterprise department individual].freeze
    URGENCIES = %w[high medium low].freeze
    SLA_RISKS = %w[low medium high].freeze
    REASON_CODES = %w[
      low_confidence insufficient_evidence major_incident_candidate provider_unavailable
      ambiguous_scope security_sensitive manual_review not_required
    ].freeze

    def self.catalog
      @catalog ||= YAML.safe_load_file(Rails.root.join("config/triage_catalog.yml")).freeze
    end

    def self.json_schema
      catalog = self.catalog
      {
        "type" => "object",
        "additionalProperties" => false,
        "required" => %w[
          priority impact urgency category affected_service assignment_group
          major_incident_candidate duplicate_of is_actionable needs_human
          sla_breach_risk rationale
        ],
        "properties" => {
          "priority" => { "type" => "string", "enum" => PRIORITIES },
          "impact" => { "type" => "string", "enum" => IMPACTS },
          "urgency" => { "type" => "string", "enum" => URGENCIES },
          "category" => { "type" => "string", "enum" => catalog.fetch("categories") },
          "affected_service" => { "type" => "string", "enum" => catalog.fetch("services") },
          "assignment_group" => { "type" => "string", "enum" => catalog.fetch("assignment_groups") },
          "major_incident_candidate" => probability_object_schema,
          "duplicate_of" => {
            "type" => "object",
            "additionalProperties" => false,
            "required" => %w[incident_id probability],
            "properties" => {
              "incident_id" => {
                "anyOf" => [
                  { "type" => "integer" },
                  { "type" => "null" }
                ]
              },
              "probability" => probability_schema
            }
          },
          "is_actionable" => { "type" => "boolean" },
          "needs_human" => {
            "type" => "object",
            "additionalProperties" => false,
            "required" => %w[value probability reason_code],
            "properties" => {
              "value" => { "type" => "boolean" },
              "probability" => probability_schema,
              "reason_code" => { "type" => "string", "enum" => REASON_CODES }
            }
          },
          "sla_breach_risk" => { "type" => "string", "enum" => SLA_RISKS },
          "rationale" => { "type" => "string", "minLength" => 1, "maxLength" => 600 }
        }
      }
    end

    def self.validate(value)
      errors = []
      schema = json_schema
      validate_object(value, schema, "$", errors)
      errors
    end

    def self.valid?(value)
      validate(value).empty?
    end

    def self.probability_object_schema
      {
        "type" => "object",
        "additionalProperties" => false,
        "required" => %w[value probability],
        "properties" => {
          "value" => { "type" => "boolean" },
          "probability" => probability_schema
        }
      }
    end
    private_class_method :probability_object_schema

    def self.probability_schema
      { "type" => "number", "minimum" => 0.0, "maximum" => 1.0 }
    end
    private_class_method :probability_schema

    def self.validate_object(value, schema, path, errors)
      unless value.is_a?(Hash)
        errors << "#{path} must be an object"
        return
      end

      missing = schema.fetch("required") - value.keys
      errors.concat(missing.map { |key| "#{path}.#{key} is required" })
      extras = value.keys - schema.fetch("properties").keys
      errors.concat(extras.map { |key| "#{path}.#{key} is not allowed" })

      value.each do |key, child|
        property = schema.fetch("properties")[key]
        next unless property

        validate_value(child, property, "#{path}.#{key}", errors)
      end
    end
    private_class_method :validate_object

    def self.validate_value(value, schema, path, errors)
      if schema["anyOf"]
        valid_branch = schema.fetch("anyOf").any? do |branch|
          branch_errors = []
          validate_value(value, branch, path, branch_errors)
          branch_errors.empty?
        end
        errors << "#{path} does not match any allowed type" unless valid_branch
        return
      end

      expected_types = Array(schema.fetch("type"))
      actual_type = json_type(value)
      unless expected_types.include?(actual_type) || (actual_type == "integer" && expected_types.include?("number"))
        errors << "#{path} must be #{expected_types.join(' or ')}"
        return
      end

      if schema["enum"] && !schema.fetch("enum").include?(value)
        errors << "#{path} must be one of: #{schema.fetch('enum').join(', ')}"
      end
      if schema["minimum"] && value < schema.fetch("minimum")
        errors << "#{path} is below minimum"
      end
      if schema["maximum"] && value > schema.fetch("maximum")
        errors << "#{path} is above maximum"
      end
      if schema["minLength"] && value.length < schema.fetch("minLength")
        errors << "#{path} is too short"
      end
      if schema["maxLength"] && value.length > schema.fetch("maxLength")
        errors << "#{path} is too long"
      end
      validate_object(value, schema, path, errors) if actual_type == "object"
    end
    private_class_method :validate_value

    def self.json_type(value)
      case value
      when Hash then "object"
      when Array then "array"
      when String then "string"
      when Integer then "integer"
      when Numeric then "number"
      when TrueClass, FalseClass then "boolean"
      when NilClass then "null"
      else "unknown"
      end
    end
    private_class_method :json_type
  end
end
