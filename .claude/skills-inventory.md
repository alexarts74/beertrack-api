# Skills Inventory — Beertrack API

Inventaire des skills installés dans `.claude/skills/`. Pour la politique de résolution des conflits (TypeORM → Supabase JS) et l'auth flow Supabase, voir le `CLAUDE.md` à la racine du repo.

| Skill | Source | Couvre | S'active quand | Lignes |
|---|---|---|---|---|
| nestjs-best-practices | [Kadajett/agent-nestjs-skills](https://github.com/Kadajett/agent-nestjs-skills) | 10 sections : architecture (modules, features, repository pattern), DI (scopes, ISP, LSP, tokens), error handling (exception filters, HTTP exceptions, async), sécurité (guards, validation, sanitization, rate limiting — *auth JWT custom à ignorer, voir résolution*), performance (caching, lazy loading), testing (testing module, e2e Supertest, mocks), DB/ORM (*écrit pour TypeORM, à traduire en Supabase JS*), API design (DTOs, interceptors, pipes, versioning), microservices (patterns, health checks, queues), DevOps (config module, logging, graceful shutdown) | Toute tâche NestJS : création de module/service/controller, refactoring, review, patterns d'architecture | 130 + ~30 sub-rules |

**Total : 1 skill actif**

## Historique des changements
- **2026-04-21** — Installation initiale : `nestjs-best-practices` (Kadajett) + 7 skills `prisma-*` (officiels Prisma)
- **2026-04-21** — Passage à Supabase (DB + Auth) via `@supabase/supabase-js`, abandon de Prisma → **désinstallation des 7 skills `prisma-*`** (devenus sans objet)

## Conflits identifiés

### Conflit 1 — ORM TypeORM vs Supabase JS (pas d'ORM)
Le skill `nestjs-best-practices` (Kadajett) donne tous ses exemples ORM en **TypeORM** (`@InjectRepository`, `Repository<User>`, `createQueryBuilder`, `DataSource.transaction()`). Nous n'utilisons **aucun ORM** — juste `@supabase/supabase-js`.

**Résolution** (détails complets dans `CLAUDE.md`) :
- Les **principes** du skill NestJS restent valides (repository pattern, éviter N+1, DTOs validés, exceptions NestJS, pas de logique métier dans les controllers)
- Les **exemples de syntaxe ORM** sont à traduire automatiquement vers Supabase JS (`.from('table').select/insert/update/delete()`)
- Les **transactions** TypeORM → à remplacer par des **RPC Postgres** (`supabase.rpc('fn_name', args)`) car Supabase JS n'a pas d'API de transaction côté client

### Conflit 2 — Auth JWT custom vs Supabase Auth
Le skill NestJS (règle `security-auth-jwt`) présume qu'on **émet** ses propres JWT via Passport. **Non applicable** : Supabase émet les JWT, notre API NestJS les **vérifie** seulement.

**Résolution** : remplacer les exemples Passport/JWT par un `SupabaseAuthGuard` custom qui appelle `supabase.auth.getUser(token)` sur chaque requête protégée. Voir le template dans `CLAUDE.md` section "Auth flow".

### Pas de conflit sur le reste
Sur les 8 autres sections de `nestjs-best-practices` (architecture, DI, error handling, sécurité hors JWT, perf, testing, API design, microservices, DevOps), tout reste applicable tel quel.

## Récapitulatif des priorités
| Domaine | Référence |
|---|---|
| Architecture NestJS (modules, features) | **nestjs-best-practices** |
| Dependency Injection | **nestjs-best-practices** |
| Exception filters, error handling | **nestjs-best-practices** |
| Guards, validation, rate limiting, sanitization | **nestjs-best-practices** |
| Tests (unit, e2e, mocks) | **nestjs-best-practices** |
| DTOs, interceptors, pipes, versioning | **nestjs-best-practices** |
| Logging, config, graceful shutdown | **nestjs-best-practices** |
| Repository pattern (concept) | **nestjs-best-practices** |
| Auth JWT custom | ❌ **ne pas appliquer** — remplacer par SupabaseAuthGuard |
| Syntaxe DB (queries, filters, joins) | **Docs officielles Supabase JS** — pas de skill dédié installé |
| Migrations | **Supabase CLI** (`supabase migration new`, `supabase db push`) |
| Row-Level Security | **Docs Supabase** — à définir pour chaque table côté SQL |
| Génération de types TS depuis le schéma | `supabase gen types typescript --linked` |
| Transactions | **RPC Postgres** (fonction SQL appelée via `supabase.rpc()`) |

## À consulter directement (pas de skill installé)
- [Supabase JS client docs](https://supabase.com/docs/reference/javascript)
- [Supabase Auth docs](https://supabase.com/docs/guides/auth)
- [Supabase CLI reference](https://supabase.com/docs/reference/cli)
- [Row-Level Security guide](https://supabase.com/docs/guides/database/postgres/row-level-security)
