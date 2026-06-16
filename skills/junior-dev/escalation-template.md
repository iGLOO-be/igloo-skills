# Template — Escalade architecte

Copier ce bloc dans le chat. Remplir tous les champs ; ne pas coder tant que la section **Décision architecte** n'est pas remplie.

```markdown
## Escalade architecte

| Champ | Valeur |
|-------|--------|
| Plan | [Titre § métadonnées] |
| Tâche bloquée | §9 — Tâche N — [Titre] |
| Type | Ambiguïté / Contradiction / Impossibilité / Faille / Décision produit |
| Bloquant | Oui |

### Contexte

[1–3 phrases : ce que le junior tentait de faire]

### Ce que dit le plan

- Section : [ex. §7 Contrats API]
- Citation / résumé : [extrait pertinent]

### Ce que dit le codebase

- Fichier(s) : `path/to/file.ts` [Lxx–yy]
- Constat : [fait observable — pas d'opinion]

### Question

[Une question précise, une seule si possible]

### Options (si applicable)

| Option | Effort | Impact |
|--------|--------|--------|
| A — […] | S/M/L | […] |
| B — […] | S/M/L | […] |

---

### Décision architecte

*(Remplir en mode architecte — relire plan + code)*

- **Réponse :** [clarification tranchée]
- **Amendement plan :** [Aucun | §X — nouvelle formulation]
- **Reprise :** Tâche N, étape [k]
```

## Règles

- Une escalade = un blocage ; ne pas mélanger plusieurs sujets non liés.
- Toujours citer un chemin de fichier réel vérifié par Read/Grep.
- Si l'architecte amende le plan, ne pas implémenter au-delà de l'amendement sans re-validation utilisateur sur les changements de scope.
