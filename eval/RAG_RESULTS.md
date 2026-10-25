# Incident Memory evaluation

- Date: 2026-10-25
- Dataset: `eval/rag_golden.jsonl` (25 cases; 20 answerable, 5 unanswerable)
- Provider status: completed

```json
{
  "status": "completed",
  "embedding_provider": "gemini",
  "embedding_model": "gemini-embedding-001",
  "relevance_provider": "gemini",
  "relevance_model": "gemini-flash-lite-latest",
  "llm_provider": "gemini",
  "llm_model": "gemini-flash-lite-latest",
  "indexed_chunks": 0,
  "metrics": {
    "hit_at_1": 0.95,
    "hit_at_3": 1.0,
    "citation_validity": 1.0,
    "citation_count": 40,
    "valid_citation_count": 40,
    "correct_abstain_rate": 1.0,
    "average_latency_ms": 3030.16,
    "pending_cases": 0,
    "pending_case_details": []
  }
}
```

Live metrics are reported only after real embedding, relevance, and generation provider calls. `EVAL_RAG_LIVE=1` is an opt-in network operation.
