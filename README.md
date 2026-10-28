# Humani.se

My personal site and a small Google-authenticated admin portal. The public
page is server-rendered with responsive
background imagery, a PDF resume, and links to GitHub, LinkedIn,
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

PostgreSQL is required. `bin/setup` prepares the development database and
creates the initial owner (`jeff@humani.se`) and imports the initial resume.
Database connection settings
are in `config/database.yml`; standard `PGHOST`, `PGUSER`, and `PGPASSWORD`
variables can override local connection defaults. Production uses
`DATABASE_URL`. No Redis, JavaScript toolchain, or background worker is
required. The app loads Active Record, controller, view, and test railties;
other framework railties remain disabled.

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

The security checks may need network access. Request tests cover admin authentication/access management and the home
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
| `public/` | Favicons, social preview, and static error pages |
| `db/bootstrap/` | Initial resume PDF, imported only when no resume is published |
| `docs/` | Implementation plans and historical repository reviews |

The public page and admin portal use system fonts and no runtime JavaScript. Sprockets publishes
compiled CSS and WebP backgrounds at widths 640, 960, 1440, 2560, and 3200.
Generated CSS in `app/assets/builds/` and fingerprinted assets in
`public/assets/` are ignored by Git.

## Production: Heroku

The repository is configured for Git/buildpack deployment to Heroku:

```sh
git push heroku main
```

The Ruby buildpack installs gems and precompiles assets. The root `Procfile`
runs migrations and the idempotent owner/resume bootstraps in its release process,
then starts Puma using `config/puma.rb`; Puma reads Heroku's `PORT`. There is no
Dockerfile or container deployment configuration.

Production accepts `humani.se`, `www.humani.se`,
`admin.humani.se`, and `humanise.herokuapp.com`. Add other exact app/preview hostnames through the
comma-separated `RAILS_ALLOWED_HOSTS` environment variable. The configured
allowlist describes expected hosts; it does not verify the live app's domain
or stack configuration. Canonical and sharing URLs use the fixed
`https://www.humani.se/` origin.

Rails forces HTTPS and recognizes Heroku's forwarded HTTPS headers. The
production CSP allows same-origin images, styles, and manifest; it disables
scripts, network connections from page scripts, web fonts, embedded
objects, and framing. Public pages block forms; admin pages allow same-origin
forms and redirects to Google sign-in. Development retains its exception console.

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
| `/resume` | Latest published PDF, served inline on public hosts |
| `/jeff-miller-resume.pdf` | Temporary redirect to `/resume` |

The status response contains `version`, `sha`, `environment`, `deployed_at`,
and `started_at`. Release version, commit SHA, and deployment time come from
`HEROKU_RELEASE_VERSION`, `HEROKU_BUILD_COMMIT`, and
`HEROKU_RELEASE_CREATED_AT`; they may be null when those variables are not
provided. `started_at` is captured once when application configuration loads,
so preloaded workers can share the timestamp. It is separate from release
deployment time. Tests use placeholder release metadata.

The resume is available at `/resume`; the previous PDF URL redirects there.
Open Graph and Twitter
metadata reference the 1200×630 image at `/social-preview.jpg`.

The 404, unsupported-browser (406), 422, and 500 pages are static HTML in
`public/`. They share `public/error.css` and `public/error-background.webp`
so their appearance does not depend on Rails rendering or compiled assets.
The unsupported-browser page offers a LinkedIn link as an alternative.

## Admin portal

Production admin routes are constrained to the exact `admin.humani.se`
hostname. Authentication middleware uses the same constraint. Admin pages
have a separate locally served [Pico CSS 2.1.1](https://picocss.com/) layout
(MIT license in `vendor/assets/stylesheets/PICO-LICENSE.md`). Public pages
retain their existing layout and canonical URL. `/up` and `/status` remain
public on both hosts.

Only approved Google accounts can sign in. `jeff@humani.se` is the fixed owner;
only the owner can invite, revoke, and restore administrators. Everyone added
through the interface receives the admin role. Invited accounts become active
on their first successful sign-in. No invitation email is sent: share the
admin URL yourself. Access changes record the actor, target, action, and time
in `admin_access_events`; revoked records are retained rather than deleted.

Google identities are bound to Google's stable subject identifier on first
sign-in. After binding, a Google email change does not transfer the account
to another Google identity or alter the approved email stored in this app.
To use a different Google account, revoke the old invitation and invite a new
email. Ownership transfers are intentionally not exposed in the interface.

Authentication uses OmniAuth's authorization-code flow with OAuth state,
PKCE, verified Google email, and Rails CSRF protection on the POST sign-in
request. Only `openid`, `email`, and `profile` scopes are requested. Google
access/refresh tokens are not persisted. Server-side sessions contain a
SHA-256 digest of a random cookie token and expire after seven days.
Production cookies are secure, HTTP-only, SameSite=Lax, host-only, and use
`__Host-` names. Signing out removes the current session; revocation removes
all sessions for the administrator and access is checked on every request.
Admin HTML is marked `no-store` and `noindex, nofollow`.

### Resume uploads

The owner can open **Resume** in admin navigation to upload and immediately
publish a replacement. Other admins cannot manage the resume. Uploads must
be readable, unencrypted PDFs with at least one page and no larger than 5 MiB
(5,242,880 bytes). Validation uses PDF contents rather than the supplied MIME
type or filename. Invalid uploads leave the current resume unchanged.

`Resume` stores one current PDF and its metadata in PostgreSQL, including the
uploader, publication time, byte size, and SHA-256 digest. Replacement is atomic;
concurrent uploads use the last successful write. Previous versions are not
retained by the application. Include the resume in database backup/restore
procedures. PDF parsing checks readability; it does not sanitize arbitrary
embedded content or render previews on the server.

`https://www.humani.se/resume` returns the PDF with `Content-Disposition: inline`
and a stable suggested filename. Browser preferences can still force downloads.
The strong ETag changes with the PDF; `Cache-Control: public, no-cache` requires
revalidation before a cached copy is reused. Existing open tabs are not refreshed.
On the admin host, `/resume` is the owner-only editor; its preview link points
to the canonical public host. Public hosts do not accept resume uploads.

`bin/setup` and Heroku releases run `resume:bootstrap` after migrations. It
validates `db/bootstrap/jeff-miller-resume.pdf` and inserts it only if no resume
exists, including during competing creation attempts. Subsequent releases
never replace an uploaded resume. Run `bin/rails resume:bootstrap` for manual
initialization after migration. A missing published record returns 404, without
silently serving the initial PDF as a fallback.

Production smoke tests remain database-independent; PDF delivery and cache
revalidation are covered against the test database in integration tests.

`Admin` stores each approved account and its Google identity, role, and access
status. `AdminSession` belongs to an admin and stores a login token digest and
expiry; sessions are removed on sign-out or revocation. `AdminAccessEvent`
records an invitation, revocation, or restoration. Its `admin` is the affected
account and its `actor` is the admin who performed the change. From an admin,
`admin_access_events` returns changes to that account, while
`performed_admin_access_events` returns changes they made. Audit events survive
revocation, and their associations and database foreign keys prevent deleting
referenced accounts.

### Local Google sign-in

Run `bin/dev` once. The same Rails process serves both hosts on port 3000:

- Public site: <http://lvh.me:3000> (localhost also works).
- Admin: <http://admin.lvh.me:3000>.

`lvh.me` and its subdomains resolve to the loopback address; no hosts-file
changes or second Rails process are needed. Development explicitly allows
these two hostnames, and production continues to reject them.

For real Google sign-in, Google requires HTTPS on non-localhost callback
hosts, including `lvh.me`. HTTP works for local browsing, but do not register
an HTTP `lvh.me` callback. To test Google sign-in, use the optional TLS mode
on the same Rails process. With a locally trusted certificate tool such as
[mkcert](https://github.com/FiloSottile/mkcert) installed, generate a certificate
for these local names (install/trust its local CA first):

```sh
mkdir -p tmp/certs
mkcert -cert-file tmp/certs/lvh.me.pem -key-file tmp/certs/lvh.me-key.pem lvh.me admin.lvh.me localhost 127.0.0.1 ::1
LOCAL_HTTPS=1 LOCAL_SSL_CERT="$PWD/tmp/certs/lvh.me.pem" LOCAL_SSL_KEY="$PWD/tmp/certs/lvh.me-key.pem" bin/dev
```

Stop any existing `bin/dev` before starting TLS mode. Visit
<https://lvh.me:3000> and <https://admin.lvh.me:3000>. `LOCAL_HTTPS=1`
configures Puma TLS and the Google callback scheme together. Certificates
under `tmp/` are ignored by Git. Production does not use this local TLS mode.

Set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` in the server environment
before startup, using a separate development Google OAuth web client with
this exact authorized redirect URI:

```text
https://admin.lvh.me:3000/auth/google_oauth2/callback
```

See Google's [redirect URI validation rules](https://developers.google.com/identity/protocols/oauth2/web-server#uri-validation).

`bin/dev` loads a local `.env` file through Foreman; direct `bin/rails`
commands do not. Keep `.env` and all secrets outside Git.
Tests use mock Google responses and dummy client credentials; no real Google
account or network authentication is required to run them. Mock sign-in is
never enabled by application configuration.

### Production setup

Before deploying this change:

1. Provision a Heroku PostgreSQL database on the existing app and confirm it
   supplies `DATABASE_URL`. Choose the plan and backup policy deliberately;
   database provisioning incurs a recurring cost.
2. Add `admin.humani.se` to the existing Heroku app, configure its DNS record
   using the exact target returned by Heroku, and verify HTTPS/certificate
   coverage. The route constraint does not provision DNS or certificates.
3. In Google Auth Platform, configure the app's branding and audience and
   create an OAuth client of type **Web application**. Use an External
   audience if administrators may use personal Gmail or other organizations'
   Google accounts. If left in Testing mode, add permitted people as Google
   test users as well as approving them in this portal.
4. Register this exact production authorized redirect URI:
   `https://admin.humani.se/auth/google_oauth2/callback`. Request only basic
   identity scopes (`openid`, `email`, `profile`). This redirect flow does not
   require a browser JavaScript client or authorized JavaScript origins.
5. Set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` securely in Heroku config,
   along with the existing runtime secret key base. Use separate production
   and development OAuth clients.
6. Deploy through the existing Heroku Git workflow. The release process runs
   `db:migrate admin:bootstrap resume:bootstrap`; it preserves an existing owner's Google
   binding. For manual setup/recovery, the same idempotent command is
   `bin/rails admin:bootstrap` (or `heroku run rails admin:bootstrap`).
7. Sign in as `jeff@humani.se`, add an admin, and verify their sign-in,
   owner-only restrictions, and immediate access revocation in production.

Local checks cannot verify live DNS, Heroku provisioning, Google client
configuration, or an end-to-end Google sign-in. Follow Google's
[web-server OAuth setup documentation](https://developers.google.com/identity/protocols/oauth2/web-server)
for current console requirements.

## Image authoring

Design explorations and original image sources have been removed from the
current checkout. Generated runtime images remain checked in. The optional
`script/build-images.cjs` tool requires the photo master at
`design-sources/night-sky.jpg` and overlay at
`design-sources/social-preview.svg`; restore those two inputs from Git history
before regenerating images. The last version before their removal is:

```sh
git restore --source=8b806e0 -- design-sources/night-sky.jpg design-sources/social-preview.svg
```

With the inputs restored, run from the repository root:

```sh
npm install --prefix tmp/image-tools sharp --no-audit --no-fund
NODE_PATH="$PWD/tmp/image-tools/node_modules" node script/build-images.cjs
```

This writes the five WebP backgrounds at quality 85, the static error-page
background, and the JPEG social preview. Node and sharp are optional authoring
dependencies; they are not required to run Rails, CI, or the Heroku build.
Commit the generated images along with source changes.

See [AGENTS.md](AGENTS.md) for agent guidance and the
[repository review](docs/repository-review.md) for cleanup evidence and
follow-up decisions. The review records the work and checks performed at
the time; current code, scripts, and workflow files define present behavior.
The [resume management plan](docs/resume-management-plan.md) records the approved
upload and public-delivery design and implementation acceptance checks.
