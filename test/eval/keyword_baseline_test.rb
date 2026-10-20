require "test_helper"
require Rails.root.join("eval/baselines/keyword_baseline")

class KeywordBaselineTest < ActiveSupport::TestCase
  test "golden set contains at least forty labeled bilingual cases" do
    records = File.readlines(Rails.root.join("eval/triage_golden.jsonl"), chomp: true).reject(&:empty?).map { |line| JSON.parse(line) }

    assert_operator records.length, :>=, 40
    assert records.any? { |record| record.fetch("short_description").match?(/[ğüşöçıİ]/i) }
    assert records.any? { |record| record.fetch("description").include?("injection") }
    assert records.all? { |record| %w[P1 P2 P3 P4].include?(record.fetch("expected_priority")) }
  end

  test "keyword baseline is isolated in eval and demonstrates urgent-word false positives" do
    record = {
      "short_description" => "Acil: tek kullanıcı profil fotoğrafını güncelleyemiyor",
      "description" => "Low impact, one person only; no service interruption.",
      "service_affected" => "unknown"
    }

    prediction = Eval::Baselines::KeywordBaseline.call(record)

    assert_equal "P1", prediction.fetch("priority")
    assert_not Rails.root.join("app").glob("**/*.rb").any? { |path| File.read(path).include?("KeywordBaseline") }
  end
end
