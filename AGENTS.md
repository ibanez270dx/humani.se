# Agent guidance

## Project scope

humani.se is Jeff Miller's personal site: one server-rendered Rails page,
a web app manifest, health and deployment-status endpoints, and public
resume/favicon/social-preview files. Ruby and Rails versions are defined in
`.ruby-version`, `Gemfile`, and `Gemfile.lock`. Framework defaults are 8.1.

The app loads controller, view, and test railties. It has no database,
background jobs, mail delivery, uploads, WebSockets, or runtime JavaScript.
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
- `config/initializers/humanise.rb`: Heroku release metadata lookup.
- `config/environments/production.rb` and the CSP initializer: host, HTTPS,
  and content security configuration.
- `test/integration/site_test.rb`: normal request tests.
- `test/production_smoke.rb`: separate production-mode checks.
- `public/404.html`, `406-unsupported-browser.html`, `422.html`, and
  `500.html`: static error pages sharing `public/error.css` and
  `public/error-background.webp`; keep them independent of Rails rendering
  and fingerprinted assets.
- `design-sources/` and `script/build-images.cjs`: image masters and optional
  image generation tooling. `design-explorations/` contains design references.

## Development and checks

Use `bin/setup` to install gems, clear logs/tempfiles, and request a server
restart. `bin/dev` starts Rails on port 3000 and the Dart Sass watcher using
Foreman, installing Foreman if missing. No database preparation is needed.

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
- Production intentionally blocks scripts, forms, embedded objects, and
  framing through CSP. If a requested feature needs a policy change, update
  the policy and corresponding production checks together.
- Production hosts are explicitly allowed. Additional exact domains use
  comma-separated `RAILS_ALLOWED_HOSTS`; avoid broad wildcard allowances.
- Add request coverage for behavior changes and production smoke coverage
  for host/HTTPS/CSP changes. Keep changes focused and preserve existing
  user edits in the working tree.

## Assets and deployment

Edit image sources in `design-sources/` and use the README's optional sharp
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
