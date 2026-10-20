# Triage evaluation

- Date: 2026-10-20
- Dataset: `eval/triage_golden.jsonl` (40 labeled tickets)
- Provider: No model metrics are reported unless EVAL_LIVE=1 and a real provider is configured.

## Keyword baseline (evaluation-only)

```json
{
  "priority_accuracy": 0.4,
  "priority_confusion_matrix": {
    "P1": {
      "P1": 10,
      "P2": 2,
      "P3": 0,
      "P4": 0
    },
    "P2": {
      "P1": 4,
      "P2": 5,
      "P3": 1,
      "P4": 3
    },
    "P3": {
      "P1": 3,
      "P2": 0,
      "P3": 0,
      "P4": 2
    },
    "P4": {
      "P1": 8,
      "P2": 0,
      "P3": 1,
      "P4": 1
    }
  },
  "needs_human_precision": 1.0,
  "needs_human_recall": 0.4,
  "needs_human_true_positive": 8,
  "needs_human_predicted_positive": 8,
  "needs_human_actual_positive": 20,
  "average_latency_ms": 0.02
}
```

## Model provider

```json
{
  "status": "not_run",
  "note": "No model metrics are reported unless EVAL_LIVE=1 and a real provider is configured."
}
```

Model metrics are intentionally omitted unless they come from a real provider call (`EVAL_LIVE=1`).
