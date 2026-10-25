# Triage evaluation

- Date: 2026-10-25
- Dataset: `eval/triage_golden.jsonl` (40 labeled tickets)
- Provider: gemini / gemini-flash-lite-latest

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
  "average_latency_ms": 0.04
}
```

## Model provider

```json
{
  "status": "completed",
  "provider": "gemini",
  "model": "gemini-flash-lite-latest",
  "metrics": {
    "priority_accuracy": 0.525,
    "priority_confusion_matrix": {
      "P1": {
        "P1": 8,
        "P2": 4,
        "P3": 0,
        "P4": 0
      },
      "P2": {
        "P1": 0,
        "P2": 3,
        "P3": 7,
        "P4": 3
      },
      "P3": {
        "P1": 0,
        "P2": 0,
        "P3": 0,
        "P4": 5
      },
      "P4": {
        "P1": 0,
        "P2": 0,
        "P3": 0,
        "P4": 10
      }
    },
    "needs_human_precision": 1.0,
    "needs_human_recall": 0.6,
    "needs_human_true_positive": 12,
    "needs_human_predicted_positive": 12,
    "needs_human_actual_positive": 20,
    "average_latency_ms": 1949.39,
    "provider_errors": 0,
    "provider_error_details": []
  }
}
```

Model metrics are intentionally omitted unless they come from a real provider call (`EVAL_LIVE=1`).
