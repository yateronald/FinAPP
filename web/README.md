# FinTrack Web

Next.js 15 web client for the FinTrack platform. Talks only to the backend API.

## Stack

Next.js 15 (App Router) · TypeScript · TailwindCSS · shadcn-style UI (Radix) ·
TanStack Query · Zustand · Recharts · next-intl (🇫🇷/🇬🇧) · next-themes (dark/light)

## Setup

```bash
cd web
cp .env.example .env.local     # set NEXT_PUBLIC_API_URL (default http://localhost:4000/api/v1)
npm install
npm run dev                    # http://localhost:3000
```

The backend must be running (see `../backend`). Seed the backend first, then log
in with the demo account: `demo@finapp.local` / `Password123!`.

## Features implemented

- Auth: login, register, email OTP verification, Google button, refresh-token flow
- App shell: dark sidebar navigation, top bar with greeting, notifications, language + theme toggles
- Dashboard: income/expenses/savings/balance cards with trends, expense-distribution
  donut, income-vs-expenses line chart, budget objectives with progress bars &
  status badges, live AI coach panel (ask + generate insights), recent transactions
- i18n: French (default) & English, cookie-based, no hardcoded strings
- Light & dark themes

## Structure

```
src/
├── app/
│   ├── (auth)/         # login, register, verify-email  (+ brand layout)
│   └── (app)/          # authenticated shell + dashboard, income, expenses, ...
├── components/
│   ├── ui/             # button, card, input, progress, badge, ...
│   ├── layout/         # sidebar, topbar, language switcher, theme toggle
│   └── dashboard/      # stat cards, charts, budget list, AI panel, transactions
├── hooks/              # use-auth, use-dashboard (TanStack Query)
├── lib/                # api client (auto token refresh), types, utils, providers
├── store/              # Zustand auth store
└── i18n/               # next-intl config + locale server actions
```

## Next

Full CRUD screens for income, expenses, budgets, categories, reports and settings
(placeholder pages exist and are wired into navigation).
