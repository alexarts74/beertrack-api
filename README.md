# beertrack-api

Backend NestJS de Beertrack — le Strava de la bière.

## Stack

- **NestJS** + TypeScript strict
- **Supabase** — PostgreSQL + Auth + Storage (pas d'ORM)
- **`@supabase/supabase-js`** comme client DB
- Auth via JWT Supabase (vérifié par un `SupabaseAuthGuard`)
- RLS activée sur toutes les tables

## Prérequis

- Node.js >= 20
- Supabase CLI (`npm i -g supabase` ou via npx)
- Un projet Supabase actif

## Installation

```bash
npm install
```

## Variables d'environnement

Copier `.env.example` en `.env` et remplir les valeurs :

```bash
cp .env.example .env
```

| Variable | Description |
|---|---|
| `PORT` | Port du serveur (défaut : 3000) |
| `CORS_ORIGIN` | Origine autorisée (ex: `http://localhost:8081`) |
| `SUPABASE_URL` | URL du projet Supabase |
| `SUPABASE_ANON_KEY` | Clé publique Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | Clé service role (secret — bypass RLS) |

## Lancer en dev

```bash
npm run start:dev
```

L'API tourne sur `http://localhost:3000`. Toutes les routes sont préfixées `/v1/`.

## Tests

```bash
npm run test          # unit
npm run test:e2e      # e2e
npm run test:cov      # couverture
```

## Supabase CLI

```bash
npx supabase login
npx supabase link --project-ref <ref>
npx supabase migration new <nom>    # nouvelle migration
npx supabase db push                # applique sur Supabase cloud
npx supabase db reset               # reset local
npm run types:gen                   # régénère database.types.ts
```

## Générer les types TypeScript

```bash
npm run types:gen
```

Génère `src/types/database.types.ts` depuis le schéma Supabase.

## Déploiement

À définir (Railway / Fly.io / VPS).
