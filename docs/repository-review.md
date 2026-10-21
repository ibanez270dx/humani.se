# Repository review

Reviewed October 21, 2026. Scope: tracked application code, configuration,
assets, dependency lockfile, CI, development scripts, and Docker packaging.
This is a source and local-runtime review; it does not establish the live
site's hosting configuration or production traffic patterns.

## Assessment

The site is small and understandable: one HTML page, a web app manifest,
two operational endpoints, a resume PDF, and favicon assets. Its templates
already have useful accessibility features: semantic landmarks, a skip link,
visible keyboard focus, descriptive navigation labels, and screen-reader
labels for external links. The active Sass is compact and all its selectors
are accounted for in the templates.

Most excess came from the previous visual design and generated Rails
scaffolding. Keeping Rails is reasonable while it remains the existing
hosting and maintenance path. A framework migration would add work without
improving the content itself.

## Cleanup completed

| Area | Evidence and action |
| --- | --- |
| Fonts and icon system | The active stylesheet imports only typography and layout; typography uses system fonts. Removed 36 font files and the unimported font, icon, and helper Sass files. |
| Old imagery | Only the 1440, 2560, and 3200 backgrounds appear in the live layout. Removed seven unused crop/blur variants and the unreferenced old logo. |
| JavaScript | No Stimulus controllers, actions, forms, frame navigation, or other interactive features exist. Removed Hotwire/importmap dependencies and setup. The old resize handler wrote background styles on header/article elements, while the current background is a fixed image with CSS object-fit. |
| Rails frameworks | No concrete models, database queries, uploads, mailers, jobs, channels, or rich-text features exist. Load only controller/view/test railties, remove unused base classes and framework configuration, and remove SQLite and database setup steps. The Rails umbrella gem still installs its component gems; these frameworks are no longer initialized or mounted. |
| Service worker | The file contained only commented examples and no registration exists. Removed its route and template. Retained the manifest and favicons because the layout actually links them. |
| Test scaffolding | The original suite ran zero tests; its Selenium base referenced dependencies absent from the Gemfile. Removed empty channel/system scaffolding and added request coverage for current behavior. |
| CI and packaging | Removed unused JavaScript auditing, browser installation, database preparation, and system-test artifact handling. Added production asset compilation and eager-loading checks. Removed unused Docker packaging after confirming Heroku buildpacks are the intended deployment path. |
| Documentation | Replaced the generated README with setup, checks, runtime requirements, and deployment guidance. |
| Deployment status | Reduce the response to version, commit SHA, environment, deployment time, and application startup time. Use release metadata for deployment time and capture startup time during application configuration; remove subprocesses and the directory modification timestamp. |

Deleted files total 9,245,795 bytes (about 9.2 MB), across 67 files. This is
working-tree source reduction, not a claim about visitor download savings
or Git history size. Some unused assets were previously precompiled but
never requested by the page. Design explorations remain in Git as references.

## Follow-up disposition

The approved follow-up work is implemented locally:

| Item | Result |
| --- | --- |
| Optimize images | Replace the runtime JPEGs with five WebP widths (640, 960, 1440, 2560, 3200). Keep the original photo outside the asset pipeline, excluded from Heroku slugs. |
| Public status | Keep `/status` public, as requested. The simplified metadata and separate deployment/startup timestamps remain. |
| Rails defaults | Set `config.load_defaults 8.1`. Review the installed Rails 8.0/8.1 defaults: strict HTTP freshness, regexp timeout, environment-dependent YJIT, JSON escaping, relative redirect protection, and view template tracking. No application code depends on the old behavior; request and production smoke checks pass. Database-specific defaults do not apply because Active Record is disabled. |
| Host restrictions and CSP | Allow the two public domain names and the known app hostname, plus explicit names from `RAILS_ALLOWED_HOSTS`. Enforce a production policy for this script-free page. Preserve HTTP-to-HTTPS redirects and test Heroku's forwarded protocol headers. |
| Presentation checks | User reports the existing desktop/mobile presentation looks good. Preserve the layout and inspect the newly encoded image and social card locally. |
| Sharing metadata | Add canonical, Open Graph, and Twitter tags and a matching 1200×630 JPEG preview. Use `https://www.humani.se/`, matching the live redirect from the bare domain. |
| Maintenance checks | Add a locked-gem advisory scan and seven production smoke tests to CI. Add an explicit Heroku Puma Procfile and slug exclusions. A Docker build check is not part of the current buildpack deployment workflow. |

### Image transfer sizes

| Width | Original JPEG bytes | WebP bytes | Reduction |
| --- | ---: | ---: | ---: |
| 640 | — | 18,748 | New smaller candidate |
| 960 | — | 46,774 | New smaller candidate |
| 1440 | 957,988 | 113,456 | 88.2% |
| 2560 | 2,613,449 | 401,444 | 84.6% |
| 3200 | 987,489 | 660,314 | 33.1% |

The browser chooses one source based on viewport width and pixel density.
These are encoded file-size reductions, not measured live load-time or
Largest Contentful Paint improvements. The 57,285-byte sharing card is
metadata for crawlers and is not downloaded by the page itself.
Regeneration instructions and source files are included; authoring tools
are not runtime dependencies.

## Validation

- Five request tests, 55 assertions, passing.
- Seven production smoke tests, 31 assertions, passing.
- Production checks cover host rejection (including forwarded hosts), HTTPS
  redirects, forwarded HTTPS without a redirect loop, CSP, public status,
  stable startup timestamps, and successful retrieval of all referenced
  compiled backgrounds, stylesheet, manifest, resume, and social card.
- Eager loading, RuboCop, and production asset compilation pass.
- Brakeman reports zero errors and zero security warnings.
- The locked-gem advisory scan reports no vulnerabilities against the updated
  Ruby advisory database.
- Route inspection still shows only home, health, status, and manifest.
- The original cleanup left compiled CSS byte-for-byte unchanged; this
  follow-up also leaves the Sass and layout styles unchanged.
- Read-only live requests confirm a redirect from `https://humani.se/` to
  `https://www.humani.se/`, whose response identifies the Heroku router.

## Deployment limits

No changes have been deployed. The repository has a standard Heroku Git
remote and no `heroku.yml` or other container-stack configuration. Remove
the unused Dockerfile, `.dockerignore`, and `bin/docker-entrypoint`; deploy
through Heroku buildpacks and the Puma Procfile.
The authenticated Heroku stack/domain lookup could not run because the CLI
credentials are expired. If the app has another generated or preview domain,
add that exact hostname to `RAILS_ALLOWED_HOSTS` before using it.

Live Largest Contentful Paint, social network cache refreshes, and production
security headers should be checked after deployment. The user's visual
approval covers the page layout; no new browser automation dependency was
introduced. The new encoded image and preview were inspected as local images.
