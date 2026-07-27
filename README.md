# FinApp — AI Personal Finance Management Platform

A modern, secure, AI-powered personal finance platform. Web + Mobile, both
talking **only** to the shared backend API. Bilingual (🇫🇷 French / 🇬🇧 English).

```
FinAPP/
├── backend/     # NestJS REST API (✅ built)
├── web/         # Next.js 15 web app (🚧 in progress)
└── mobile/      # React Native + Expo (⏳ later)
```

## Features

- **Dashboard** — income, expenses, net savings, savings rate, financial score, charts
- **Income & Expenses** — record transactions with categories, tags, receipts
- **Categories** — unlimited custom categories, icons, colors, archive, reorder
- **Monthly Budgets** — per-category objectives with progress bars & threshold alerts
- **AI Coach** — Google Gemini spending analysis, advice, predictions, NL assistant
- **Reports** — daily/weekly/monthly/yearly/custom + CSV export
- **Notifications** — budget alerts, large expenses, AI alerts
- **Auth** — email/password, OTP verification, Google login, refresh-token rotation, device management
- **Settings** — language, currency, theme, notifications, data export

## Tech

| Layer | Stack |
| --- | --- |
| Backend | NestJS, Prisma, PostgreSQL (Aiven), JWT, Passport, Gemini, Swagger |
| Web | Next.js 15, TypeScript, Tailwind, shadcn/ui, TanStack Query, Zustand, Recharts, next-intl |
| Mobile | React Native, Expo, Expo Router, NativeWind, React Query |

## Quick start

```bash
# 1. Backend
cd backend
cp .env.example .env      # add DB URL, JWT secrets, Gemini key, SMTP
npm install && npx prisma generate
npm run prisma:migrate && npm run prisma:seed
npm run start:dev         # http://localhost:4000/api/v1  (docs at /docs)

# 2. Web (once built)
cd ../web
cp .env.example .env.local
npm install && npm run dev   # http://localhost:3000
```

Or use Docker for the backend + a local Postgres:

```bash
docker compose up --build
```

## Security

All sensitive values live in `.env` files (never committed): database
credentials, JWT/cookie secrets, Google OAuth, Gemini API key, SMTP. The
backend adds Argon2 hashing, refresh-token rotation with reuse detection, rate
limiting, Helmet, RBAC, input validation and audit logs.

See [`backend/README.md`](backend/README.md) for API details.
