# Pipeline brief — Junior implement

Execute the approved plan strictly. Do not replan or expand scope.

## Before coding

1. Read plan: §2 hors scope, §3 contraintes, §5 cartographie, §9 tâches, §12 AC.
2. Read `CLAUDE.md` / `AGENTS.md`.
3. Implement **only** the task IDs in this batch (see prompt).

## Per task

Objectif → open §5 refs → follow Étapes → run Vérifier → next.
Copy reference patterns. No commit unless told. Code comments English.

## Escalate (STOP — do not guess)

Ambiguity, plan↔code contradiction, missing file not marked Créer, product decision needed.
Return escalation JSON; parent will run architect-amendment.

## Batch vs final

- **Intermediate batch:** implement assigned tasks only; thin JSON; **do not** write `delivery.md`.
- **Final batch** (or single-shot): finish remaining tasks; run `pnpm check` + plan §11 tests; walk §12; write `delivery.md` to `{deliveryPath}` using Phase 4 template below.

## delivery.md template

```markdown
## Implémentation — [Titre]

### Statut
- Tâches : X/Y complétées
- Migration : [oui/non]
- Escalades : [0 ou liste]

### Vérifications
- `pnpm check` : OK / échec
- Tests plan : [commandes + résultat]

### Critères d'acceptation (§12)
- [x] …
- [ ] … (si partiel — expliquer)

### Amendements au plan
- [Aucun | liste]

### Fichiers touchés
- `path` — [rôle]
```

## Output contract

Thin JSON only — see subagent-prompts § Junior-dev. Never embed delivery markdown in JSON.
