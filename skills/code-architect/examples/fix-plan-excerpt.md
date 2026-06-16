# Exemple — extrait de plan (bugfix)

Input : Fix PRD « OAuth error affiché en anglais sur la page login ».

---

## 1. Résumé exécutif

Afficher les erreurs OAuth Better-Auth en français via `next-intl`, en réutilisant le composant `OAuthErrorAlert` et les clés i18n existantes du namespace `Auth`.

## 5. Cartographie des fichiers

| Fichier | Action | Rôle |
|---------|--------|------|
| `src/components/features/auth/OAuthErrorAlert.tsx` | Modifier | Mapper `error` query param → clé i18n |
| `src/messages/fr.json` | Modifier | Ajouter clés `Auth.oauthErrors.*` |
| `src/messages/en.json` | Modifier | Parité EN |
| `src/components/features/auth/__tests__/OAuthErrorAlert.test.tsx` | Créer | Couvrir mapping + fallback |

## 9. Plan de tâches

### Tâche 1 — Clés i18n

**Objectif:** Centraliser les messages d'erreur OAuth connus.

**Fichiers:** `src/messages/fr.json`, `src/messages/en.json`

**Étapes:**
1. Lister les codes `error` renvoyés par Better-Auth callback (grep `oauth` dans auth config).
2. Ajouter `Auth.oauthErrors.<code>` pour chaque code documenté.
3. Ajouter `Auth.oauthErrors.unknown` comme fallback.

**Vérifier:**
- [ ] JSON valide, clés identiques FR/EN

**Référence:** pattern clés `Auth.loginErrors.*` existantes

---

### Tâche 2 — Composant + tests

**Objectif:** Remplacer le texte brut par `useTranslations('Auth')`.

**Fichiers:** `OAuthErrorAlert.tsx`, `__tests__/OAuthErrorAlert.test.tsx`

**Étapes:**
1. Lire `searchParams.get('error')`, normaliser (lowercase, trim).
2. `t(\`oauthErrors.${code}\`)` avec fallback `oauthErrors.unknown`.
3. Tests RTL : code connu, code inconnu, pas de param.

**Vérifier:**
- [ ] `pnpm test -- OAuthErrorAlert`
- [ ] `pnpm check`

## 12. Critères d'acceptation

- [ ] Erreur OAuth `access_denied` affiche le message FR documenté
- [ ] Code inconnu affiche le fallback sans crash
- [ ] Login password inchangé (régression)
