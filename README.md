# Humani.se

My personal site: a server-rendered Rails page with responsive
background imagery, a downloadable resume, and links to GitHub, LinkedIn,
and Calendly. The canonical URL is <https://www.humani.se/>.

## Development

Use Ruby 4.0.7 and Bundler 4.0.23, as specified by `.ruby-version`, `Gemfile`,
and `Gemfile.lock`. The app uses Rails 8.1 with 8.1 framework defaults.

```sh
bin/setup
bin/dev
```

`bin/setup` installs gem dependencies, clears logs and temporary files, and
requests an application server restart. `bin/dev` uses Foreman to start Rails
at <http://localhost:3000> and watch the Dart Sass sources. It installs
Foreman if missing.

No database, Redis, JavaScript toolchain, or background worker is required.
The app loads controller, view, and test railties. The Rails umbrella gem
still installs other framework components, but their railties are disabled.

## Checks

Run the local check sequence:

```sh
bin/ci
```

The executable script works from any directory and stops on the first
failure. It runs these commands in order:

```sh
bin/brakeman --no-pager
bundle exec bundle-audit check --update
bin/rubocop
bin/rails zeitwerk:check
bin/rails dartsass:build
bin/rails test
```

The security checks may need network access. Request tests cover the home
page, responsive assets, sharing metadata, manifest, health, public status,
and removed framework routes.

Production checks are separate from `bin/ci`. From the repository root, run:

```sh
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails runner test/production_smoke.rb
```

The smoke tests check allowed/rejected hosts, HTTPS redirects, forwarded
HTTPS requests, CSP, public status, stable startup timestamps, and retrieval
of compiled/public assets. `test/production_smoke.rb` runs through Rails
runner; `bin/rails test` does not include it.

[GitHub Actions](.github/workflows/ci.yml) runs source and dependency security
scans, lint, eager loading, request tests, production asset compilation, and
production smoke tests. It runs those checks in separate steps/jobs rather
than invoking `bin/ci`.

## Application structure

| Location | Purpose |
| --- | --- |
| `app/views/application/index.html.erb` | Home page content and profile links |
| `app/views/layouts/application.html.erb` | Shared markup, responsive background, canonical and sharing metadata |
| `app/assets/stylesheets/` | Sass source; `application.scss` imports typography and layout |
| `app/assets/config/manifest.js` | Sprockets publishing directives for images and compiled CSS |
| `app/controllers/application_controller.rb` | Home and deployment-status actions |
| `app/views/pwa/manifest.json.erb` | Web app metadata and icon references |
| `public/` | Favicons, resume PDF, social preview, and static error pages |
| `design-sources/` | Original photo and social-card artwork |
| `design-explorations/` | Design references |

The page uses system fonts and no runtime JavaScript. Sprockets publishes
compiled CSS and WebP backgrounds at widths 640, 960, 1440, 2560, and 3200.
Generated CSS in `app/assets/builds/` and fingerprinted assets in
`public/assets/` are ignored by Git.

## Production: Heroku

The repository is configured for Git/buildpack deployment to Heroku:

```sh
git push heroku main
```

The Ruby buildpack installs gems and precompiles assets. The root `Procfile`
starts Puma using `config/puma.rb`; Puma reads Heroku's `PORT`. There is no
Dockerfile or container deployment configuration.

Production accepts `humani.se`, `www.humani.se`, and
`humanise.herokuapp.com`. Add other exact app/preview hostnames through the
comma-separated `RAILS_ALLOWED_HOSTS` environment variable. The configured
allowlist describes expected hosts; it does not verify the live app's domain
or stack configuration. Canonical and sharing URLs use the fixed
`https://www.humani.se/` origin.

Rails forces HTTPS and recognizes Heroku's forwarded HTTPS headers. The
production CSP allows same-origin images, styles, and manifest; it disables
scripts, network connections from page scripts, web fonts, forms, embedded
objects, and framing. Development retains its exception console.

Provide the runtime secret key base through `SECRET_KEY_BASE` or encrypted
credentials with their `RAILS_MASTER_KEY`. `SECRET_KEY_BASE_DUMMY=1` is for
local asset compilation and smoke checks, not a live server.

The `.slugignore` file excludes design sources/references, the `docs/`
directory, tests, image-authoring scripts, and editor tooling from Heroku's
deployed bundle. It does not remove those files from Git. Runtime assets
and public files remain included.

## Routes and status

| Route | Purpose |
| --- | --- |
| `/` | Home page |
| `/manifest.json` | Web app metadata; no service worker is registered |
| `/up` | Rails health check |
| `/status` | Public deployment/startup metadata |

The status response contains `version`, `sha`, `environment`, `deployed_at`,
and `started_at`. Release version, commit SHA, and deployment time come from
`HEROKU_RELEASE_VERSION`, `HEROKU_BUILD_COMMIT`, and
`HEROKU_RELEASE_CREATED_AT`; they may be null when those variables are not
provided. `started_at` is captured once when application configuration loads,
so preloaded workers can share the timestamp. It is separate from release
deployment time. Tests use placeholder release metadata.

The resume is available at `/jeff-miller-resume.pdf`. Open Graph and Twitter
metadata reference the 1200×630 image at `/social-preview.jpg`.

## Image authoring

The photo master is `design-sources/night-sky.jpg`; the social-card overlay
is `design-sources/social-preview.svg`. To regenerate the checked-in images
from the repository root:

```sh
npm install --prefix tmp/image-tools sharp --no-audit --no-fund
NODE_PATH="$PWD/tmp/image-tools/node_modules" node script/build-images.cjs
```

This writes the five WebP backgrounds at quality 85 and the JPEG social
preview. Node and sharp are optional authoring dependencies; they are not
required to run Rails, CI, or the Heroku build. Commit the generated images
along with source changes.

See [AGENTS.md](AGENTS.md) for agent guidance and the
[repository review](docs/repository-review.md) for cleanup evidence and
follow-up decisions. The review records the work and checks performed at
the time; current code, scripts, and workflow files define present behavior.
