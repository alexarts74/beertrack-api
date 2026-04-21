# API NestJS — Instructions Claude Code

## Stack
- **NestJS** (dernière version stable, TypeScript strict)
- **Supabase** comme plateforme : PostgreSQL managé + Auth + (Storage/Realtime si besoin plus tard)
- **Client** : `@supabase/supabase-js` utilisé **directement** côté NestJS (pas de Prisma, pas de TypeORM, pas d'ORM)
- **Auth** : Supabase Auth (JWT émis par Supabase) — **pas de Passport local, pas de JWT custom**
- **Validation** : `class-validator` + `class-transformer` (via `ValidationPipe` global)
- **Doc API** : `@nestjs/swagger` (OpenAPI auto)
- **Config** : `@nestjs/config` + validation Joi/Zod
- **Tests** : Jest (unit) + Supertest (e2e)

## Priorités des Skills

### Architecture & Patterns
- Pour l'architecture NestJS (modules, DI, guards, interceptors, pipes, exception filters, API design, logging) → suivre **`nestjs-best-practices`** (Kadajett) en priorité
- Ce skill couvre 10 sections — **tout reste valide sauf la section "DB/ORM" qui est écrite pour TypeORM** (voir résolution ci-dessous)

### Base de données
- **Pas d'ORM** — accès DB via `@supabase/supabase-js` (méthodes `.from('table').select/insert/update/delete()`)
- Les migrations se gèrent via **Supabase CLI** (`supabase migration new <nom>`, `supabase db push`) ou via le SQL Editor de Supabase Studio
- Le schéma n'est pas versionné dans le repo NestJS — il vit dans `supabase/migrations/*.sql` (convention Supabase CLI)

### Sécurité, perf, tests
- `nestjs-best-practices` sections `security-*`, `perf-*`, `test-*` font autorité
- **Exception** : `security-auth-jwt` du skill est pour un JWT custom — nous utilisons le JWT Supabase (voir guard plus bas)

## Résolution des conflits entre skills

### Conflit 1 — ORM (TypeORM dans le skill NestJS) vs pas d'ORM
`nestjs-best-practices` présume TypeORM (`@InjectRepository`, `Repository<User>`, `createQueryBuilder`, `DataSource.transaction()`). Nous n'utilisons **aucun ORM** — juste le client Supabase JS.

Traduction à appliquer :

| Pattern TypeORM (skill) | Équivalent Supabase JS (à utiliser) |
|---|---|
| `@InjectRepository(User) private repo: Repository<User>` | `constructor(private readonly supabase: SupabaseService) {}` |
| `this.repo.find()` | `this.supabase.client.from('users').select('*')` |
| `this.repo.findOne({ where: { id } })` | `this.supabase.client.from('users').select('*').eq('id', id).single()` |
| `this.repo.save(user)` | `this.supabase.client.from('users').insert(user).select().single()` |
| `this.repo.update(id, patch)` | `this.supabase.client.from('users').update(patch).eq('id', id).select().single()` |
| `this.repo.delete(id)` | `this.supabase.client.from('users').delete().eq('id', id)` |
| `createQueryBuilder().leftJoinAndSelect('user.orders', …)` | `from('users').select('*, orders(*)')` (jointures via foreign keys) |
| `DataSource.transaction(async (manager) => …)` | **Pas de transaction client-side** — utiliser une RPC Postgres (`supabase.rpc('fn_name', args)`) ou un Edge Function |
| Custom repository (`UsersRepository extends Repository<User>`) | Service dédié (`UsersRepository`) qui wrappe `SupabaseService` et expose les queries métier |
| Entités `@Entity()` / `@Column()` | Pas d'entités — le schéma vit dans `supabase/migrations/*.sql`, les types TS sont générés via `supabase gen types typescript` |
| Migrations TypeORM | `supabase migration new <nom>` + SQL, puis `supabase db push` ou `db reset` en local |

**Conclusion** : on garde **tous les principes** du skill NestJS (repository pattern, éviter N+1, DTOs validés, exceptions NestJS, pas de logique dans les controllers…) mais on **traduit les exemples de code** en appels `@supabase/supabase-js`.

### Conflit 2 — Auth JWT custom vs Supabase Auth
`nestjs-best-practices` (`security-auth-jwt`) présume qu'on implémente son propre JWT avec Passport. **Non applicable** : Supabase émet les JWT. Notre API NestJS **vérifie** les tokens (on ne les émet pas).

Pattern correct (voir section "Auth" plus bas).

## Architecture Supabase + NestJS

### Deux clients Supabase, deux usages
```ts
// 1. Client "service role" (clé secrète) — bypass RLS — admin uniquement
const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

// 2. Client "user" (JWT du requester) — respecte RLS — par requête
const supabaseUser = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  global: { headers: { Authorization: `Bearer ${userJwt}` } }
})
```

**Règle** : par défaut on utilise le **client user** (scoped à la requête via un provider `REQUEST`-scoped) pour bénéficier des **Row-Level Security policies** définies dans Supabase. Le **service role** est réservé aux cas admin explicites (webhooks, tâches cron, opérations batch).

### Auth flow
1. Le front (Expo) appelle `supabase.auth.signInWithPassword()` / `signUp()` / `signInWithOAuth()` **directement** contre Supabase — notre API n'intervient pas dans le signup/login
2. Le front reçoit une session `{ access_token, refresh_token, user }` — stockée par le SDK Supabase (à configurer avec `expo-secure-store` côté front)
3. À chaque requête vers notre API, le front met `Authorization: Bearer <access_token>` dans les headers
4. Un **`SupabaseAuthGuard`** côté NestJS vérifie le JWT via `supabase.auth.getUser(token)`, récupère l'utilisateur, et l'attache à `request.user`
5. Un décorateur `@CurrentUser()` expose l'utilisateur dans les controllers
6. Les **Row-Level Security (RLS)** dans Supabase font le deuxième niveau d'autorisation au niveau DB

### Guard type (exemple de structure)
```ts
// src/common/guards/supabase-auth.guard.ts
@Injectable()
export class SupabaseAuthGuard implements CanActivate {
  constructor(private readonly supabase: SupabaseService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest()
    const token = extractBearerToken(req)
    if (!token) throw new UnauthorizedException()

    const { data, error } = await this.supabase.admin.auth.getUser(token)
    if (error || !data.user) throw new UnauthorizedException()

    req.user = data.user          // { id, email, app_metadata, user_metadata, ... }
    req.supabaseToken = token     // nécessaire pour créer un client user-scoped
    return true
  }
}
```

## Conventions backend

### Structure par module
```
src/
├── modules/
│   └── users/
│       ├── users.module.ts
│       ├── users.controller.ts
│       ├── users.service.ts
│       ├── users.repository.ts         ← wrapper Supabase client
│       ├── dto/
│       │   ├── create-user.dto.ts
│       │   └── update-user.dto.ts
│       └── users.controller.spec.ts
├── common/
│   ├── guards/
│   │   └── supabase-auth.guard.ts
│   ├── decorators/
│   │   └── current-user.decorator.ts
│   ├── interceptors/
│   ├── filters/
│   └── pipes/
└── supabase/
    ├── supabase.module.ts
    └── supabase.service.ts             ← expose .admin et .forUser(token)
```

### Règles
- Un module NestJS = **un domaine métier** (pas une couche technique)
- Chaque endpoint a un **DTO de validation** (`class-validator`)
- Pas de logique métier dans les controllers — tout dans les **services**
- Les queries Supabase complexes vont dans un **`*.repository.ts`** dédié (pas directement dans le service)
- Jamais retourner directement l'objet Supabase brut — mapper vers un type de réponse (`ResponseDto`)
- **Pas d'entités ORM** — les types TS sont générés depuis Supabase via `supabase gen types typescript --linked > src/types/database.types.ts` (à automatiser dans un npm script)
- **RLS activée sur toutes les tables** par défaut — ne jamais désactiver sans raison documentée
- **Service role** uniquement dans des endpoints explicitement admin

## Sécurité (obligatoire dès le début)
- **Helmet** + **CORS** whitelist (uniquement le front Expo autorisé)
- **Rate limiting** via `@nestjs/throttler`
- Validation stricte des inputs via `ValidationPipe({ whitelist: true, forbidNonWhitelisted: true })`
- **Secrets** JAMAIS committés — `.env` dans `.gitignore`, notamment :
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY` (publique, mais au même endroit)
  - `SUPABASE_SERVICE_ROLE_KEY` ⚠️ **secret critique** — ne jamais exposer côté front, ne jamais logger
- **RLS policies** systématiques dans Supabase (tout refuser par défaut, whitelister ce qui est autorisé)

## Routes & API
- Toutes les routes préfixées `/v1/`
- Versionning via `VersioningType.URI`
- Format d'erreur standardisé NestJS : `{ statusCode, message, error }`
- Endpoints protégés décorés avec le `SupabaseAuthGuard` (soit par controller, soit global avec `@Public()` sur les exceptions)

## Commandes utiles
```bash
npm run start:dev                                   # mode watch
npm run test
npm run test:e2e
npx nest g module <nom>
npx nest g resource <nom> --no-spec                 # adapter le template pour Supabase

# Supabase CLI (à installer : npm i -D supabase)
npx supabase login
npx supabase link --project-ref <ref>
npx supabase migration new <nom>                    # nouvelle migration SQL
npx supabase db push                                # applique les migrations sur Supabase cloud
npx supabase db reset                               # reset local
npx supabase gen types typescript --linked > src/types/database.types.ts
```

## Skills installés
Voir `.claude/skills/` et l'inventaire détaillé dans `.claude/skills-inventory.md`.

Actuellement : **1 skill** (`nestjs-best-practices`). Les skills Prisma ont été désinstallés suite au passage à Supabase.
