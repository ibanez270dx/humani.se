# Agent guidance

## Project scope

humani.se is Jeff Miller's personal site: one server-rendered Rails page,
a Google-authenticated admin portal, a web app manifest, health and
deployment-status endpoints, and public
resume/favicon/social-preview files. Ruby and Rails versions are defined in
`.ruby-version`, `Gemfile`, and `Gemfile.lock`. Framework defaults are 8.1.

The app loads Active Record, controller, view, and test railties. PostgreSQL
stores admins, sessions, access audit events, and the current resume PDF.
The owner can upload PDFs; there is no Active Storage, background job, mail
delivery, WebSocket, or runtime JavaScript infrastructure.
The Rails umbrella gem still installs framework components that are not
loaded. Keep the implementation small; add infrastructure or dependencies
only when the requested behavior needs them.

## Where to work

- `app/views/application/index.html.erb`: home page content and profile links.
- `app/views/layouts/application.html.erb`: shared markup, responsive image,
  canonical URL, and social metadata.
- `app/assets/stylesheets/application.scss`: Sass entry point, importing
  `typography.scss` and `layout.scss`.
- `app/assets/config/manifest.js`: Sprockets asset publishing directives;
  unrelated to the web app manifest in `app/views/pwa/manifest.json.erb`.
- `app/controllers/application_controller.rb`: home and status actions.
- `app/models/resume.rb` and the public/admin resume controllers: bounded PDF
  validation, singleton publication, inline delivery, and owner-only upload.
- `db/bootstrap/jeff-miller-resume.pdf`: initial PDF, never a runtime fallback.
- `config/initializers/humanise.rb`: Heroku release metadata lookup.
- `config/environments/production.rb` and the CSP initializer: host, HTTPS,
  and content security configuration.
- `test/integration/site_test.rb`: normal request tests.
- `test/production_smoke.rb`: separate production-mode checks.
- `public/404.html`, `406-unsupported-browser.html`, `422.html`, and
  `500.html`: static error pages sharing `public/error.css` and
  `public/error-background.webp`; keep them independent of Rails rendering
  and fingerprinted assets.
- `script/build-images.cjs`: optional image generation tooling. Its original
  inputs and design explorations were removed; restore the inputs from Git
  history as described in the README before regenerating images.

## Development and checks

Use `bin/setup` to install gems, clear logs/tempfiles, and request a server
restart. `bin/dev` starts Rails on port 3000 and the Dart Sass watcher using
Foreman, installing Foreman if missing. PostgreSQL must be running; `bin/setup`
prepares the database and bootstraps the fixed owner. One `bin/dev` process serves
`lvh.me:3000` and `admin.lvh.me:3000`. Real Google sign-in on lvh.me needs the
optional local HTTPS mode described in the README.

Run `bin/ci` for application changes. It stops at the first failure and runs:

```sh
bin/brakeman --no-pager
bundle exec bundle-audit check --update
bin/rubocop
bin/rails zeitwerk:check
bin/rails dartsass:build
bin/rails test
```

Security checks may need network access. `bin/ci` does not run production
asset compilation or production smoke tests. For asset, deployment, Rails
configuration, or security changes, also run from the repository root:

```sh
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails runner test/production_smoke.rb
```

The smoke test deliberately does not end in `_test.rb`: it must run through
Rails runner in production, not as part of `bin/rails test`. GitHub Actions
runs the security, lint, request, eager-loading, production asset, and smoke
checks in separate steps/jobs; it does not invoke `bin/ci` directly.
For documentation-only changes, check referenced paths and commands and run
`git diff --check`; no new test cases are needed.

## Implementation conventions

- Follow `.rubocop.yml`, including its no-space styles for single-line block
  braces and array brackets. Use `bin/rubocop` rather than changing style rules.
- Preserve semantic landmarks, the skip link, keyboard focus styles, and
  accessible labels for external links. Inspect narrow and wide layouts
  when changing presentation; request tests do not establish visual quality.
- Keep `/status` public. Its fields are `version`, `sha`, `environment`,
  `deployed_at`, and `started_at`. Deployment metadata comes from Heroku;
  startup time is captured during application configuration and may be
  shared by preloaded workers. Directory modification time is not a release
  or startup timestamp.
- Keep canonical and sharing URLs on `https://www.humani.se/`, independent
  of request hosts or query parameters.
- Production intentionally blocks scripts, embedded objects, and framing
  through CSP. Public pages block forms; admin pages allow same-origin forms and Google sign-in redirects. If a requested feature needs a policy change, update
  the policy and corresponding production checks together.
- Production hosts are explicitly allowed. Additional exact domains use
  comma-separated `RAILS_ALLOWED_HOSTS`; avoid broad wildcard allowances.
- Add request coverage for behavior changes and production smoke coverage
  for host/HTTPS/CSP changes. Keep changes focused and preserve existing
  user edits in the working tree.

## Admin conventions

- Admin routes and OmniAuth middleware share `AdminHost`; production accepts
  only `admin.humani.se`, while local admin uses `admin.lvh.me:3000`.
- `jeff@humani.se` is the fixed owner. Only the owner manages administrators;
  all invitations create admins, with no email delivery.
- Never enable OmniAuth test mode outside tests. Keep Google scopes limited
  to identity and do not persist Google access or refresh tokens.
- Preserve stable Google identity binding, seven-day server-side sessions,
  host-only secure cookies, access checks on every admin request, and atomic
  audited revocation that deletes all target sessions.
- Keep admin styling in the separate admin layout; Pico is vendored locally.
- The Heroku release process migrates the database and bootstraps the owner.
  Provisioning, OAuth credentials, DNS, and HTTPS still require live setup.
- Only the owner can manage resumes at `/resume` on the admin host. The same
  path serves the published PDF on public hosts. Keep the preview URL on
  `https://www.humani.se/resume`, validate PDF contents up to 5 MiB, and retain
  the current document on failed uploads. Keep bytes and metadata atomic,
  upload contents out of logs, and public responses inline with revalidation.
- Setup and releases run `resume:bootstrap` after migrations. Never overwrite
  an existing resume with the bundled initial PDF. Keep production smoke
  checks independent of a database; integration tests cover PDF delivery.

## Assets and deployment

Image masters are no longer present in the checkout. Restore the two inputs
from Git history before editing sources or using the README's optional sharp
workflow to regenerate the five WebP variants, `public/error-background.webp`,
and `public/social-preview.jpg`.
Commit generated deliverable images with their source changes. Node/sharp
are authoring tools, not Rails or Heroku dependencies. Sass output under
`app/assets/builds/` and fingerprinted output under `public/assets/` are
ignored build artifacts; edit the Sass sources instead.

Heroku deployment uses the Git remote and root `Procfile`, which starts
Puma with `config/puma.rb`. There is no Docker deployment configuration.
`.slugignore` excludes design sources/references, the `docs/` directory,
tests, and authoring tooling from the deployed slug; preserve runtime
assets and public files. The README documents deployment commands and
configuration. Local checks do not prove the live app's stack, domain list,
or deployed release. Keep secrets and credential keys out of Git.
