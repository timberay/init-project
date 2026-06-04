# Next.js Stack

> Installed by `install.sh` when a Next.js `package.json` or
> `next.config.*` file was detected. To switch language overlay, re-run
> `install.sh --lang <other>`.

## Project Layout

```
.
├── app/                    # App Router routes, layouts, and route handlers
├── components/             # reusable UI components
├── lib/                    # server-safe utilities and integrations
├── public/                 # static assets
├── tests/                  # integration/e2e tests
├── package.json
└── tsconfig.json
```

Prefer the App Router for new work. Keep route handlers thin: parse input,
authorize, call an application service, and return a typed response.

## Runtime

- Use Node 22 LTS unless the hosting platform requires a different supported
  version.
- Use TypeScript by default. Avoid plain JavaScript for new application code.
- Prefer React Server Components for data-heavy pages and Client Components
  only where browser state, effects, or event handlers are required.

## Dependency Management

Use the package manager that already owns the lockfile:

| Lockfile | Command |
|----------|---------|
| `package-lock.json` | `npm ci` |
| `pnpm-lock.yaml` | `pnpm install --frozen-lockfile` |
| `yarn.lock` | `yarn install --frozen-lockfile` |

Do not mix package managers in one repository. Commit the lockfile.

## Data Fetching

- Fetch server-side data in Server Components or route handlers.
- Use Server Actions for simple mutations when they keep validation and
  authorization close to the UI.
- Use a client data library only for truly client-owned state, optimistic
  updates, or polling.

## Styling

Tailwind CSS is the default choice for new projects. CSS Modules are acceptable
for component-specific styles. Keep design tokens centralized in the Tailwind
config or CSS variables.

## Testing

| Scope | Tool |
|-------|------|
| Unit/component | Vitest or Jest + Testing Library |
| Browser flows | Playwright |
| API/route handlers | Vitest/Jest with focused fixtures |

Prefer behavior tests over snapshot tests. Add Playwright coverage for critical
navigation, forms, auth boundaries, and checkout/payment flows.

## Security

- Validate all external input with Zod, Valibot, or the framework already used
  in the repo.
- Keep secrets in environment variables. Never expose a value to the browser
  unless it intentionally uses the `NEXT_PUBLIC_` prefix.
- Enforce authorization in route handlers, Server Actions, and server-side
  service functions, not only in UI components.
- Sanitize user-generated HTML before rendering it. Avoid `dangerouslySetInnerHTML`
  unless a trusted sanitizer is part of the call path.

## Deployment

Vercel is the default deployment target. Container or self-hosted deployments
are acceptable when infrastructure requires them; in that case, document the
runtime mode and cache behavior in this file.
