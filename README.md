# humani.se

Jeff Miller's personal site. A server-rendered Rails page with responsive
background imagery, a downloadable resume, and links to GitHub, LinkedIn,
and Calendly.

## Development

- Ruby 4.0.7 (see `.ruby-version`)
- Bundler 4.0.23 (see `Gemfile.lock`)

Run `bin/setup`, then `bin/dev`. The site is served at
<http://localhost:3000>; the second process watches Dart Sass sources.
No database, Redis, JavaScript toolchain, or background worker is required.

The application loads Action Controller, Action View, and Rails' test support.
Unused database, mail, storage, job, and WebSocket frameworks are not enabled.
The `rails` gem still includes those components as transitive dependencies.

## Checks

```sh
bin/rails dartsass:build
bin/rails test
bin/rails zeitwerk:check
bin/rubocop
bin/brakeman --no-pager
bundle exec bundle-audit check --update
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
```

CI runs source and dependency security scanning, lint, the production asset
build, request tests, eager-loading checks, and production smoke tests.
Request tests cover the page, linked assets, sharing metadata, manifest,
health check, deployment status, and removed framework routes.

Run the production smoke checks after precompiling assets:

```sh
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails runner test/production_smoke.rb
```

These check allowed and rejected hosts, HTTPS redirects, Heroku's forwarded
HTTPS headers, CSP, public status, and every responsive image asset.

## Production: Heroku

Deploy using the existing Git remote:

```sh
git push heroku main
```

Heroku's Ruby buildpack installs gems and precompiles assets. The `Procfile`
starts Puma on the port Heroku provides.

The canonical URL is `https://www.humani.se/`, matching the existing live
redirect from the bare domain. Production accepts `humani.se`,
`www.humani.se`, and `humanise.herokuapp.com`. For other exact app or preview
hostnames, set `RAILS_ALLOWED_HOSTS` to a comma-separated list. Wildcards are
not needed. The Heroku CLI credentials were unavailable during the review,
so the remote stack and domain list have not been independently verified.

Keep Heroku's forwarded protocol headers intact. Rails forces HTTPS and
recognizes requests already secured by Heroku's router. The production CSP
permits same-origin images/styles/manifest and disables scripts, embedded
objects, forms, and framing. Development retains its exception console.
`/status` remains public by design; `started_at` records application boot
configuration time and is shared by workers if the server preloads the app.

The `.slugignore` file excludes design sources, documentation, tests, and
authoring tooling from Heroku slugs. Compiled assets and public files remain.

Set a real `SECRET_KEY_BASE` at runtime, or provide `RAILS_MASTER_KEY` for
encrypted credentials.
`SECRET_KEY_BASE_DUMMY` is only for the asset build.

Routes: `/` (home), `/manifest.json` (web app metadata), `/up` (health),
and `/status` (deployment metadata). Public files include favicons and
`/jeff-miller-resume.pdf`.

## Repository notes

The page lives in `app/views/application/index.html.erb`, with shared markup
in `app/views/layouts/application.html.erb`. Sass starts at
`app/assets/stylesheets/application.scss` and uses system fonts.
Sprockets publishes the compiled CSS and five responsive WebP backgrounds.

Design references remain in `design-explorations/` and are excluded from
Heroku slugs. See [the repository review](docs/repository-review.md) for
cleanup evidence and prioritized follow-up work.

## Image sources and sharing preview

The original photo and preview artwork live in `design-sources/`.
`public/social-preview.jpg` is the 1200×630 social card. The layout includes
Open Graph and Twitter metadata with absolute canonical URLs.

To regenerate the images locally (optional authoring dependencies only):

```sh
npm install --prefix tmp/image-tools sharp --no-audit --no-fund
NODE_PATH="$PWD/tmp/image-tools/node_modules" node script/build-images.cjs
```

Node and sharp are not required by Rails, CI, or Heroku. The checked-in WebP
images preserve the original composition and use quality 85 encoding.
