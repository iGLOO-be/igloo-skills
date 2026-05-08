# plan-to-paperclip

Convert a plan from the current conversation into a Paperclip issue with a plan document.

Read the `paperclip-operator` skill and follow its API conventions — especially the **API Route Patterns** section and the **"Create Issue with Plan from File"** workflow (7).

Minimize questions — infer what you can, only ask when truly ambiguous.

## Steps

1. **Resolve Paperclip context**: set env vars from `~/.paperclip/auth.json` per the skill's Auth Setup. Fetch companies, match project by workspace directory name, fetch agents. Ask only if ambiguous.

2. **Extract plan metadata** from the conversation:
   - **Title**: imperative form (e.g. "Add rate limiting with Upstash")
   - **Description**: 1–3 sentences (Paperclip truncates long descriptions)
   - **Priority**: infer from content, default `medium`
   - **Plan file path**: locate the plan file from the conversation context (e.g. `.cursor/plans/*.plan.md`, `.claude/plans/*.md`, or any markdown plan file referenced in the conversation)

3. **Resolve assignee**: if the user specified a name, first match against agents (workflow 11). If no match, fetch the user directory (workflow 12) and match by name. Use `assigneeAgentId` for agents, `assigneeUserId` for humans — never both.

4. **Create issue + attach plan**: follow the skill's workflow 7 ("Create Issue with Plan from File"). Use `--rawfile` to read the plan file from disk — never re-type plan content in the curl body.

5. **Report back**: issue identifier, clickable board link, confirmation that the plan document was attached.
