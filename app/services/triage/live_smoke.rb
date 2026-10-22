require "digest"
require "fileutils"
require "json"
require "pathname"
require "securerandom"

module Triage
  class LiveSmoke
    Incident = Struct.new(:short_description, :description, :service_affected, :category, :assignment_group, keyword_init: true)

    SAMPLE = Incident.new(
      short_description: "Finance users cannot complete SAP month-end posting",
      description: "A synthetic smoke-test ticket: several finance users report that month-end SAP posting is blocked.",
      service_affected: "SAP ERP",
      category: "Enterprise Software",
      assignment_group: "Enterprise ERP Operations"
    ).freeze

    def self.call(provider: nil, output_directory: Rails.root.join("eval/live_runs"))
      new(provider, output_directory).call
    end

    def initialize(provider, output_directory)
      @provider = provider
      @output_directory = Pathname.new(output_directory)
    end

    def call
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      report = {
        "run_at" => Time.current.utc.iso8601(3),
        "status" => "failed",
        "provider" => ENV["DECISION_PROVIDER"].presence || "unconfigured",
        "model" => ENV["DECISION_MODEL"],
        "input_digest" => Digest::SHA256.hexdigest(JSON.generate(SAMPLE.to_h))
      }

      begin
        @provider ||= DecisionProviders::Factory.build
        report["provider"] = @provider.provider
        report["model"] = @provider.model
        output = @provider.call(SAMPLE)
        errors = Schema.validate(output)
        raise ProviderError.new("invalid_provider_output", errors.join("; ")) if errors.any?

        report["status"] = "completed"
        report["decision"] = output
      rescue ProviderError => error
        report["error_code"] = error.code
      ensure
        report["latency_ms"] = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      end

      FileUtils.mkdir_p(@output_directory)
      report_path = @output_directory.join("#{Time.current.utc.strftime('%Y%m%dT%H%M%S%LZ')}_#{SecureRandom.hex(4)}_triage.json")
      File.write(report_path, "#{JSON.pretty_generate(report)}\n")
      [ report, report_path ]
    end
  end
end
