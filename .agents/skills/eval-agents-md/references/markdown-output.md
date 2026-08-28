# AGENTS.md Evaluation

**Eval ran at:** {{RUNTIME}}
**Eval commit:** `{{COMMIT}}`

**Test:** {{TEST_NAME}}

| Result    |                Runs |            Percentage |
| --------- | ------------------: | --------------------: |
| ✅ Pass   |      {{PASS_COUNT}} |      {{PASS_PERCENT}} |
| 🟡 Almost |    {{ALMOST_COUNT}} |    {{ALMOST_PERCENT}} |
| ❌ Fail   |      {{FAIL_COUNT}} |      {{FAIL_PERCENT}} |
| **Total** | **{{SCORED_RUNS}}** | **{{TOTAL_PERCENT}}** |

## Summary Findings

<!-- BEGIN FINDING -->

- {{FINDING}}
<!-- END FINDING -->

## Results

| Harness | Model | Result | Turns | Avg. Reply | Avg. Chars |
| ------- | ----- | :----: | :---: | ---------: | ---------: |

<!-- BEGIN MODEL -->

| {{HARNESS_LABEL}} | {{MODEL_LABEL}} | {{RESULT_BY_RUN}} | {{TURNS_BY_RUN}} | {{AVERAGE_REPLY_TIME}} | {{AVERAGE_REPLY_CHARS}} |

<!-- END MODEL -->

## Scoring criteria

<!-- BEGIN TURN -->

### Turn {{TURN_NUMBER}}

- **Pass:** {{PASS_CRITERIA}}
- **Almost:** {{ALMOST_CRITERIA}}
- **Fail:** {{FAIL_CRITERIA}}
<!-- END TURN -->

### Run result

- **Pass:** Every turn passed.
- **Fail:** Every turn failed.
- **Almost:** Any other scored combination.

### Model result

- **Pass:** At least {{PASS_THRESHOLD_PERCENT}} of its scored runs passed.
- **Fail:** Every scored run failed.
- **Almost:** Any other scored combination.
