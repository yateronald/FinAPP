# FinApp Backend (NestJS)

Production-ready REST API for the AI Personal Finance Management platform.

## Stack

- **NestJS 10** + TypeScript
- **Prisma ORM** + PostgreSQL (Aiven in production)
- **JWT** access tokens + **refresh token rotation** (Argon2-hashed, stored)
- **Passport** (JWT + Google OAuth)
- **Google Gemini** AI coach
- **Swagger**, **Helmet**, **Throttler** (rate limiting), **Winston** logging, **compression**, **CORS**
- Class-validator DTOs, global exception filter, response transform, audit logs, soft delete

## Getting started

```bash
cd backend
cp .env.example .env         # fill in real secrets
npm install
npx prisma generate
```

### Database

Point `DATABASE_URL` at your Aiven PostgreSQL instance (or run the bundled
local Postgres via `docker compose up postgres` from the repo root), then:

```bash
npm run prisma:migrate       # create tables (dev)
npm run prisma:seed          # optional demo data
```

Demo login after seeding: `demo@finapp.local` / `Password123!`

### Run

```bash
npm run start:dev            # watch mode
# API:     http://localhost:4000/api/v1
# Swagger: http://localhost:4000/api/v1/docs
```

## Environment variables

All secrets live in `.env` (never committed). See [`.env.example`](.env.example)
for the full list: database, JWT secrets, Google OAuth, Gemini API key, SMTP.

> The app boots without SMTP or Gemini configured — emails are logged to the
> console and AI endpoints fall back to rule-based insights.

## API surface

`/api/v1/{auth, users, categories, income, expenses, budgets, dashboard, ai, reports, notifications, settings, health}`

Full interactive documentation is served at `/api/v1/docs`.

## Scripts

| Script | Description |
| --- | --- |
| `npm run start:dev` | Dev server (watch) |
| `npm run build` | Compile to `dist/` |
| `npm test` | Unit tests (Jest) |
| `npm run prisma:migrate` | Run dev migrations |
| `npm run prisma:seed` | Seed demo data |
| `npm run prisma:studio` | Prisma Studio |
| `npm run lint` | ESLint |

## Architecture

```
src/
├── config/            # env loading + validation
├── common/            # prisma, logger, guards, filters, interceptors, decorators
└── modules/
    ├── auth/          # register, login, OTP, refresh rotation, Google, sessions
    ├── users/         # profile, account deletion
    ├── categories/    # CRUD, archive, reorder
    ├── income/        # income CRUD + filters
    ├── expenses/      # expense CRUD + budget/large-expense triggers
    ├── budgets/       # monthly objectives + budget engine (threshold alerts)
    ├── dashboard/     # summary, distribution, trends, financial score
    ├── ai/            # Gemini finance coach + insights
    ├── reports/       # period reports + CSV export
    ├── notifications/ # in-app notifications
    ├── settings/      # preferences + data export
    ├── mail/          # transactional email (SMTP)
    └── audit/         # audit logging
```

Security: Argon2 password hashing, refresh-token rotation with reuse detection,
rate limiting, Helmet headers, RBAC guard, input validation, Prisma
parameterized queries, and audit logging on sensitive actions.
