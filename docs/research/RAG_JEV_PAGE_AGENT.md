# Incident Memory, Jev, and Alibaba Page Agent

Research checked 2026-10-20. This note distinguishes verified upstream behavior from SentinelOps implementation decisions.

## Page Agent

[Alibaba's Page Agent](https://github.com/alibaba/page-agent) describes itself as an in-page GUI agent: it reads a text representation of the current page's DOM rather than using screenshots, and accepts an OpenAI-compatible model configuration. Its project README lists SaaS copilots and form filling as use cases. The optional Chrome extension is the separate multi-page feature; the embedded agent is a current-page operator, not the agent-to-agent API path.

The [npm registry](https://registry.npmjs.org/page-agent/latest) reported `page-agent@1.12.4` as the latest release when checked. The published [package README](https://www.npmjs.com/package/page-agent) documents the IIFE demo bundle and supports `?autoInit=false` followed by `new window.PageAgent(...)`. SentinelOps vendors that exact IIFE artifact and its MIT license in `public/vendor/`, so the browser does not fetch executable code from a third-party CDN at runtime. The SHA-256 of the vendored bundle is `72f3705cfe3e30fec6b1eae4632eeb7bcc445a817f7a42a2ae1702aec12d0892`.

The versioned public declarations in the [published package tarball](https://registry.npmjs.org/page-agent/-/page-agent-1.12.4.tgz) verify the `interactiveWhitelist`, `includeAttributes`, custom `fetch`, lifecycle hooks, and `customTools` configuration. SentinelOps uses those supported controls to:

- allow only elements explicitly marked `data-agent-id`;
- remove the `execute_javascript` tool, so the copilot cannot run arbitrary page scripts;
- strip client-supplied authorization and send requests only to the same-origin proxy;
- mask caller names marked `data-agent-private`, plus stored caller values, email addresses, and phone numbers before provider forwarding;
- require a human confirmation for UI forms/buttons that perform state-changing actions.

The UI copilot is therefore a read/search/navigation helper. It cannot assign, claim, resolve, approve, reject, or otherwise mutate incidents. For those actions, the operator must use the normal UI and confirm explicitly. This is intentional: the existing application does not offer a safe copilot-specific assignment workflow. Ticket content remains untrusted data; the copilot's system instructions say to ignore embedded instructions.

The server-side proxy is `POST /page-agent/v1/chat/completions`. Provider credentials never enter the page. Configuration is server-only: `PAGE_AGENT_API_KEY`, HTTPS `PAGE_AGENT_BASE_URL` (the OpenAI-compatible API base, normally ending in `/v1`), `PAGE_AGENT_MODEL`, and `PAGE_AGENT_ALLOWED_MODELS` (comma-separated exact allowlist that must contain the selected model). The proxy enforces same-origin requests, Rails CSRF, a 10-request-per-minute per-IP limit, a 64 KiB request cap, a 1,200-token completion cap, TLS verification, and an eight-second read timeout. Its rate-limit cache is process-local, so horizontally scaled deployments need a shared cache.

No Page Agent provider credentials were supplied for this phase. Without all four server settings the feature is visibly disabled and the proxy returns a service-unavailable response; no demo provider is called. The exact bundle contains the upstream demonstration bootstrap code, but `autoInit=false` is explicitly set and SentinelOps constructs the agent with its own same-origin proxy configuration. No third-party demo endpoint or demo API key is used.

## Fit with SentinelOps

- **Useful for:** a human operator searching the incident list and Incident Memory using natural-language instructions while staying on the current page.
- **Not the agent-first interface:** monitoring/resolver agents should use the scoped REST API or MCP, where identity, idempotency, audit, and HITL policy are explicit. Page Agent is a browser copilot for a human, not a replacement for those contracts.
- **Limits:** the embedded integration handles one page at a time. Turbo navigation disposes the current copilot; multi-page automation would require the separate extension and is out of scope. A task takes multiple model/tool turns and can expose page context to the configured model, hence the local proxy, narrow DOM allowlist, and masking.
- **Jev and RAG:** Jev/System 1 remains the typed, auditable decision layer when a verified provider is configured. Incident Memory retrieval and grounded System 2 responses remain distinct. Page Agent can help a human navigate/search those surfaces; it does not make triage decisions, provide citations, or execute the incident workflow.

## Sources

1. [Alibaba Page Agent repository README](https://github.com/alibaba/page-agent) — in-page DOM-based approach, BYO LLM, use cases, optional extension/MCP, MIT license.
2. [Page Agent npm package README](https://www.npmjs.com/package/page-agent) — IIFE integration, `autoInit=false`, and programmatic initialization.
3. [npm registry metadata for the latest `page-agent` release](https://registry.npmjs.org/page-agent/latest) — version, package integrity, source commit, and dependency metadata.
4. [`page-agent@1.12.4` published tarball](https://registry.npmjs.org/page-agent/-/page-agent-1.12.4.tgz) — shipped TypeScript declarations for DOM allowlisting, request interception, and tool customization.
