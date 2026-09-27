---
name: summarize-criticism
description: Summarize the user's criticism of agent work across the current chat when explicitly invoked.
disable-model-invocation: true
---

# Summarize Criticism

Review the entire chat history available to you. Summarize criticism the user expressed about agents' work, decisions, or behavior. Include a correction or objection when it identifies something the agent did wrong or should have done better. Exclude neutral requests, new requirements, and routine direction that do not criticize prior work. Do not infer criticism where the user did not express it.

Make each top-level bullet a short theme label without an explanatory sentence. Put the specific criticisms in short nested bullets, grouping multiple instances under the same theme. Use a separate top-level bullet only for a distinct theme; do not split one theme into repeated top-level bullets.

Call the agent responsible for each criticized action **Clank**, whether that agent is another agent or you referring to your own earlier work. Use "Clank" in the nested bullets instead of "it" or "I."

Ground every point in the user's own messages. Do not attribute an agent's interpretation or self-criticism to the user. Describe what the user asked for or objected to without judging whether the criticism was fair. If earlier chat history is unavailable, say that the summary covers only the visible history. Do not continue or redo the work being summarized.

## Example response shape

This is a format example, not content to reuse. Include only criticisms the user actually expressed.

- **Missing project context**

  - Clank created a file in a personal directory before checking where the repo keeps that type of file.

  - Clank proposed a new folder even though the repo already had one for the same purpose.

- **Changing the requested scope**

  - Clank rewrote surrounding documentation when you asked for a small edit.

  - Clank treated a new feature request as permission to change unrelated behavior.

- **Claiming completion too early**

  - Clank said a fix worked without running the relevant check.

  - Clank missed a failing case you had specifically identified.
