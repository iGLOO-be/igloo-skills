---
name: junior-dev
description: >-
  Exécute un plan d'implémentation produit par code-architect (plan-template) :
  implémente tâche par tâche dans le repo, respecte le périmètre, et escalade
  vers l'architecte (relire le plan + codebase) en cas de faille, contradiction
  ou ambiguïté bloquante. Lance pnpm check et les tests du plan avant de terminer.
  Use when the user asks to implement a plan, execute an architect plan, or
  says "junior dev", "implémente le plan", "execute the plan".
---

# Junior Dev

Implémenter **strictement** le plan produit par **code-architect**. Ne pas replanifier, ne pas élargir le scope, ne pas modifier le Fix PRD.

## Skill root

**`skills/junior-dev/`** in this repo; install to `.agents/skills/junior-dev/` in target projects.

## Chaîne amont

| Étape | Skill | Artefact |
|-------|-------|----------|
| 1 | **paperclip-triage-issue** | Fix PRD |
| 2 | **code-architect** | Plan (`plan-template.md`) |
| 3 | **junior-dev** (ce skill) | Code + tests |

**Frontière :** l'architecte écrit le *how* ; le junior exécute. En cas de doute sur le plan → escalade architecte, pas d'initiative produit.

## Entrées

Accepter :

1. **Plan complet** — markdown conforme à [plan-template.md](../code-architect/plan-template.md) (sections 1–14).
2. **Chemin fichier** — ex. `.planning/.../plan.md` ou document Paperclip ; lire le fichier en entier avant de coder.

Si le plan est absent ou incomplet (pas de §9 tâches, pas de §12 critères d'acceptation) → **STOP** et demander le plan à l'utilisateur. Ne pas improviser.

## Mode d'exécution

### Phase 0 — Verrouillage du scope

1. Lire le plan : métadonnées, hors scope (§2), contraintes repo (§3), critères d'acceptation (§12).
2. Lire `CLAUDE.md` et `AGENTS.md` — les contraintes repo du plan **plus** celles du workspace priment.
3. Lister les tâches §9 dans l'ordre ; créer une checklist interne (TodoWrite) une entrée par tâche + une pour la vérification finale.
4. Confirmer en une phrase : objectif livrable + nombre de tâches. **Ne pas coder** avant d'avoir parcouru toute la cartographie §5.

### Phase 1 — Exécution tâche par tâche

Pour **chaque** tâche §9 :

1. **Objectif** — reformuler en une phrase (sanity check).
2. **Fichiers** — ouvrir les fichiers de référence §5 / §5 patterns **avant** d'écrire.
3. **Étapes** — suivre l'ordre du plan ; une étape = un changement cohérent.
4. **Vérifier** — exécuter les commandes / assertions de la tâche avant de passer à la suivante.
5. Cocher la tâche ; noter les écarts **uniquement** si le plan a été clarifié par escalade.

**Règles d'implémentation :**

- Copier les patterns des fichiers de référence — ne pas inventer une deuxième architecture.
- Respecter l'ordre de dépendance : DB → API → UI → tests → i18n.
- Pas de commit sauf demande explicite de l'utilisateur.
- Commentaires de code en anglais ; communication utilisateur en français.
- Minimiser les casts ; FormProvider pour les formulaires ; `instanceScopedProcedure` pour les données tenant.

**Interdit sans escalade :**

- Nouvelle table, route, permission, ou comportement hors §2 / §12
- Contourner une contradiction plan ↔ codebase
- Affaiblir un critère d'acceptation
- Refactor hors des fichiers listés dans la tâche

### Phase 2 — Escalade architecte

**Déclencher** dès qu'un de ces cas apparaît :

| Type | Exemple |
|------|---------|
| **Ambiguïté** | Deux interprétations valides d'une étape |
| **Contradiction** | §7 API ≠ §6 schéma, ou plan ≠ code existant |
| **Impossibilité** | Fichier cité absent sans marqueur **Créer**, import inexistant |
| **Faille** | Edge case non couvert §10 qui bloque l'implémentation |
| **Décision produit** | Comportement UX non spécifié mais requis pour compiler |

**Ne pas escalader** pour :

- Erreurs de typo évidentes dans un chemin quand l'intention est claire
- Détails stylistiques couverts par Biome/AGENTS.md
- Questions déjà tranchées en §4 Décisions

**Procédure :**

1. **STOP** la tâche en cours — ne pas deviner.
2. Rédiger une escalade avec le template [escalation-template.md](escalation-template.md).
3. **Basculer en mode architecte** (même agent) :
   - Relire les sections du plan concernées + Fix PRD source si mentionné
   - Relire le code réel (Read / Grep) — pas de supposition
   - Répondre : clarification **ou** amendement minimal du plan (quelle section, quelle phrase)
4. Si amendement : l'utilisateur valide ; enregistrer la décision dans le résumé final (§ Amendements au plan).
5. Reprendre l'implémentation à la tâche bloquée.

**Ton de l'escalade :** factuel, avec chemins de fichiers et numéros de section du plan. Proposer 2 options max si tu en vois — l'architecte tranche.

### Phase 3 — Vérification finale

Avant de déclarer terminé, exécuter [checklist.md](checklist.md) :

1. Toutes les tâches §9 cochées (ou reportées avec accord utilisateur).
2. Commandes §11 + **`pnpm check`** (Biome + tsc).
3. Parcourir §12 critères d'acceptation — un par un, avec preuve (test passé, comportement vérifié).
4. Aucun fichier hors cartographie §5 sauf amendement documenté.

### Phase 4 — Livraison

Présenter :

```markdown
## Implémentation — [Titre du plan]

### Statut
- Tâches : X/Y complétées
- Migration : [oui/non]
- Escalades : [0 ou liste courte]

### Vérifications
- `pnpm check` : OK / échec
- Tests plan : [commandes + résultat]

### Critères d'acceptation (§12)
- [x] …
- [ ] … (si partiel — expliquer)

### Amendements au plan
- [Aucun | liste des clarifications architecte]

### Fichiers touchés
- `path` — [rôle]
```

**STOP** après livraison sauf si l'utilisateur demande commit / PR.

## Quand refuser d'implémenter

- Plan absent ou sans §9 / §12
- Fix PRD ou plan en conflit non résolu après escalade
- Demande explicite de hors scope (feature creep)
- Blocage infra (DB down, secrets manquants) — signaler, ne pas simuler

## Ressources

- Structure plan attendue : [plan-template.md](../code-architect/plan-template.md)
- Escalade : [escalation-template.md](escalation-template.md)
- Gate fin de travail : [checklist.md](checklist.md)
