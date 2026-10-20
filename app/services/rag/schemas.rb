module Rag
  module Schemas
    def self.relevance
      {
        "type" => "object",
        "additionalProperties" => false,
        "required" => %w[results evidence_sufficient confidence],
        "properties" => {
          "results" => {
            "type" => "array",
            "items" => {
              "type" => "object",
              "additionalProperties" => false,
              "required" => %w[chunk_id relevant probability],
              "properties" => {
                "chunk_id" => { "type" => "string" },
                "relevant" => { "type" => "boolean" },
                "probability" => { "type" => "number", "minimum" => 0.0, "maximum" => 1.0 }
              }
            }
          },
          "evidence_sufficient" => { "type" => "boolean" },
          "confidence" => { "type" => "number", "minimum" => 0.0, "maximum" => 1.0 }
        }
      }
    end

    def self.resolution
      {
        "type" => "object",
        "additionalProperties" => false,
        "required" => %w[steps citations confidence insufficient_evidence],
        "properties" => {
          "steps" => {
            "type" => "array",
            "items" => {
              "type" => "object",
              "additionalProperties" => false,
              "required" => %w[text citations],
              "properties" => {
                "text" => { "type" => "string" },
                "citations" => { "type" => "array", "items" => { "type" => "string" } }
              }
            }
          },
          "citations" => { "type" => "array", "items" => { "type" => "string" } },
          "confidence" => { "type" => "number", "minimum" => 0.0, "maximum" => 1.0 },
          "insufficient_evidence" => { "type" => "boolean" }
        }
      }
    end
  end
end
