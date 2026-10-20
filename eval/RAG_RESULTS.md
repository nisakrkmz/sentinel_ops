# Incident Memory evaluation

- Date: 2026-10-20
- Dataset: `eval/rag_golden.jsonl` (25 cases; 20 answerable, 5 unanswerable)
- Provider status: not_run

```json
{
  "status": "not_run",
  "note": "Set EVAL_RAG_LIVE=1 and configure real embedding, decision, and LLM providers."
}
```

Live metrics are reported only after real embedding, relevance, and generation provider calls. `EVAL_RAG_LIVE=1` is an opt-in network operation.
