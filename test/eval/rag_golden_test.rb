require "test_helper"

class RagGoldenTest < ActiveSupport::TestCase
  test "golden corpus includes twenty answerable and at least five unanswerable scenarios" do
    records = File.readlines(Rails.root.join("eval/rag_golden.jsonl"), chomp: true).reject(&:empty?).map { |line| JSON.parse(line) }
    slugs = YAML.safe_load_file(Rails.root.join("config/knowledge_base.yml")).map { |entry| entry.fetch("slug") }

    assert_operator records.length, :>=, 25
    assert_operator records.count { |record| !record.fetch("answerable") }, :>=, 5
    assert_equal 20, records.count { |record| record.fetch("answerable") }
    assert records.select { |record| record.fetch("answerable") }.all? { |record| slugs.include?(record.fetch("expected_article_slug")) }
    assert records.select { |record| !record.fetch("answerable") }.all? { |record| record["expected_article_slug"].nil? }
  end
end
