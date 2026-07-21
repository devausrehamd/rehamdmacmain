# QMS Stack — Changelog

Release notes for the QMS stack as a whole (`rehamdmacmain`). The stack is
released together; each submodule carries its own `CHANGELOG.md` and a matching
`release_0.2.0` tag. Commit history follows
[Conventional Commits](https://www.conventionalcommits.org).

## 0.2.0 — 2026-07-21

The first coordinated stack release. Its theme is the **agent-platform control
plane** and a **hard architectural boundary**: every request-path database access
is API-mediated, and the answer path is deterministic wherever the data allows,
with the LLM confined to translation — never to inventing a value.

### rehamdmacflow (QMS Agent) — 0.1.0 → 0.2.0

- **Agent-platform control plane (Stages 0–5):** the Data Access API, Discovery-
  backed capability resolution, the git-tagged agent manifest, the DAG History
  store, the Supervisor, and the Talk Agent `/ask`.
- **Decision 13 — all request-path database access is API-mediated (R1–R4):**
  custody, trace/DAG-History, and vector search moved behind the API; the agent
  role stripped of every DB/vector/cache client and guarded by a runtime
  import-graph test. Ingestion recorded as a deliberate ETL exception (R5).
- **Deterministic answer path:** an exact-data short-circuit (no LLM for count
  answers), a grounding gate that calls out undefined terms, a QMS derivation
  registry that defines interpretive terms, and a decoder that abstains rather
  than guess. Plus answer-quality fixes (real, source-linked citations; no
  templated placeholders).

### gui (QMS GUI) — 0.0.0 → 0.2.0

- The **Ask-the-orchestrator** page: submit a question and see the selected
  capability, the orchestrated answer, and the session id.

### idserver (ID Server) — 0.1.0 → 0.2.0

- Version aligned; no functional changes this cycle.

### discovery (Discovery registry) — 0.1.0 → 0.2.0

- Version aligned; no functional changes this cycle.
