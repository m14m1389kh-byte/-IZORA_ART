# IZORA Platform

A Persian-first creative media discovery platform built with Next.js, TypeScript and Supabase.

## Stack
- Next.js App Router
- TypeScript
- Supabase Auth, PostgreSQL and Storage
- Vercel deployment

## Local setup
1. Install Node.js 20.9 or newer.
2. Configure the Supabase project URL and public client key in your local environment.
3. Run `npm install` and `npm run dev`.

## Current implementation
The first build establishes the responsive public landing page, visual system, theme switcher and Supabase server/browser clients. Database schema, RLS, authentication flows, dashboards and production integration are still in progress.

## Security
Never expose a Supabase service-role or secret key in browser code or public environment variables.
