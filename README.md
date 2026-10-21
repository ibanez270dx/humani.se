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
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
```

CI runs security scanning, lint, the production asset build, request tests,
and eager-loading checks. Request tests cover the page, linked assets,
manifest, health check, deployment status, and removed framework routes.

## Production

Precompile assets before starting Rails. Set a real `SECRET_KEY_BASE` at
runtime, or provide `RAILS_MASTER_KEY` for encrypted credentials.
`SECRET_KEY_BASE_DUMMY` is only for the asset build.
Production forces HTTPS, so configure the hosting platform's TLS proxy.

```sh
docker build -t humani-se .
docker run --rm -p 3000:3000 -e SECRET_KEY_BASE humani-se
```

The Docker command expects `SECRET_KEY_BASE` to be exported in the host shell
and HTTPS to be handled by a reverse proxy.

Routes: `/` (home), `/manifest.json` (web app metadata), `/up` (health),
and `/status` (deployment metadata). Public files include favicons and
`/jeff-miller-resume.pdf`.

## Repository notes

The page lives in `app/views/application/index.html.erb`, with shared markup
in `app/views/layouts/application.html.erb`. Sass starts at
`app/assets/stylesheets/application.scss` and uses system fonts.
Sprockets publishes the compiled CSS and three responsive background images.

Design references remain in `design-explorations/` and are excluded from
Docker images. See [the repository review](docs/repository-review.md) for
cleanup evidence and prioritized follow-up work.
