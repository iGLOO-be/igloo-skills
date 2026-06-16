# Checklist — Code Architect (avant livraison)

Cocher mentalement chaque item. Un seul ❌ = corriger le plan avant présentation.

## Spécification

- [ ] Comportement attendu formulé en termes observables (pas d'implémentation vague)
- [ ] Hors scope explicite
- [ ] Critères d'acceptation binaires pass/fail
- [ ] Fix PRD §7 repris sans affaiblissement (si input = Fix PRD)

## Codebase

- [ ] Tous les chemins de fichiers existent ou sont clairement marqués **Créer**
- [ ] Au moins un fichier de référence cité par tâche complexe
- [ ] Contraintes repo pertinentes listées (multi-tenant, offline, RBAC, i18n)
- [ ] Aucun module inventé

## Implémentabilité junior

- [ ] Tâches ordonnées par dépendance (DB → API → UI → tests)
- [ ] Chaque tâche a Objectif, Fichiers, Étapes, Vérifier
- [ ] Une tâche ≈ 1–4 h junior (pas de mega-tâche)
- [ ] Commandes de vérification concrètes (`pnpm test -- …`, `pnpm check`)

## Qualité

- [ ] Décisions d'architecture documentées avec rationale
- [ ] Edge cases et erreurs couverts
- [ ] Plan de tests lié aux critères d'acceptation
- [ ] Migration / seed mentionnés ou **Aucune**
- [ ] Risques identifiés si migration ou changement auth/permissions

## Process

- [ ] Pas de code applicatif modifié par l'architecte
- [ ] Pas d'appel Paperclip API
- [ ] Conflits spec ↔ architecture signalés (pas contournés silencieusement)
