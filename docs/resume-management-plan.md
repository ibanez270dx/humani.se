# Resume management plan

Approved direction: October 28, 2026. This document plans implementation;
this branch does not introduce uploads or change the public resume route.

## Outcome and agreed scope

Visitors can use `https://www.humani.se/resume` as a stable link to the
latest successfully published resume. Jeff can replace it through the admin
portal without editing Git or deploying the application.

- Store one current PDF in the existing PostgreSQL database.
- Allow only the fixed owner to upload and publish replacements.
- Limit uploads to 5 MiB (5,242,880 bytes); reject empty files.
- Publish immediately after validation and a successful database commit.
- Serve the PDF inline, without an HTML wrapper or a download attribute.
- Update both existing resume links and preserve the old URL with a redirect.
- Start with the existing checked-in PDF so there is no empty launch state.
- Preserve the current resume if a replacement is invalid or persistence fails.

Version history, rollback UI, drafts, scheduled publication, multiple resumes,
S3, Active Storage, background jobs, and runtime JavaScript are outside this
first version. A visitor's browser preferences may override inline viewing;
the server can request inline display but cannot force a PDF viewer.

## Current application

The implementation starts from the merged admin portal on `main`:

- `public/jeff-miller-resume.pdf` is currently served as a static asset.
- `app/views/application/index.html.erb` and
  `app/views/layouts/application.html.erb` each link to that file.
- Admin controllers inherit authentication, private response headers, and
  CSRF protection from `Admin::BaseController`; `require_owner` already
  restricts account management to Jeff.
- PostgreSQL and Active Record are loaded. Active Storage and job railties
  are not loaded, and there is no upload workflow.
- Heroku releases run database migrations and the owner bootstrap.
- `docs/` is excluded from deployment by `.slugignore`.

## Storage and publication

Introduce a `Resume` model and `resumes` table representing a singleton
published document. Use a fixed primary key and a database check restricting
it to that key so concurrent first writes cannot create multiple current
resumes. Keep the PDF and its metadata in the same row:

| Field | Purpose |
| --- | --- |
| `pdf_data` (`binary` / PostgreSQL `bytea`) | Validated PDF bytes |
| `byte_size` | Validated payload length |
| `sha256` | Digest of the exact published bytes, used as the HTTP validator |
| `original_filename` | Display-only, normalized upload filename |
| `uploaded_by_id` | Foreign key to `Admin`; nullable for the initial import |
| Timestamps | Publication time and ordinary record timestamps |

Keep nonempty data and required metadata constraints in the database, with
the size limit enforced in the upload path and a database constraint on the
binary payload. Always derive byte size and digest from the actual bytes;
do not trust client-supplied metadata. Do not log the PDF bytes or dump them
into validation errors. Preserve uploader attribution when accounts are
revoked; account deletion must not cascade into deletion of the resume.

Validate the complete candidate before replacing the current row. Write the
bytes, checksum, size, uploader, filename, and timestamps atomically. Readers
see either the old complete document or the new complete document. If two
valid uploads finish concurrently, the last successful publication commit
wins. Do not retain previous PDF bytes as application version history.

This is deliberately a bounded use of database binary storage: one document
of at most 5 MiB, infrequent writes, and low public traffic. The PDF becomes
part of normal database backups and restores. If document volume or serving
traffic grows, revisit object storage rather than generalizing this table
into an attachment system.

## Upload and validation

Add owner-only `GET /resume` and `PATCH /resume` within the existing admin
host scope, with distinct `admin_resume_path` and public `resume_path`
helpers. Use `Admin::ResumesController` and a regular multipart HTML form.
Apply the exact admin-host constraint and `require_owner` to both actions;
other approved admins cannot view the management page or submit uploads.

The page shows the current filename, size, publication time, uploader, and
an accessible link to view the public PDF in a new tab. Label the submit
button "Upload and publish resume" and explain that replacement is immediate.
Provide a clearly labeled PDF input with `accept="application/pdf,.pdf"`.
The input hint improves usability; it is not server-side validation.

On submission:

1. Require exactly one uploaded file; reject missing or malformed parameters.
2. Read at most the size limit plus one byte so oversize input is rejected
   without reading an arbitrarily large file into application memory.
3. Check PDF content identification and parse the candidate as a PDF using a
   maintained Ruby parser, selected after checking dependency compatibility
   and the security audit. Do not rely on filename or declared MIME type.
4. Reject unreadable, truncated, malformed, password-protected/encrypted, or
   zero-page documents. Validate content synchronously within the size bound.
5. Atomically publish the validated document, then redirect to the management
   page with a success status message. Render validation failures with an
   alert and HTTP 422; preserve the previously published file. Document a
   consistent HTTP 400 response for malformed request structure.

Content validation establishes a readable PDF, not arbitrary-content
sanitization. Do not add previews, thumbnail rendering, or execute embedded
content on the server. The existing trusted-owner boundary remains in place.
Keep the current admin CSP, script-free UI, POST/PATCH CSRF protection, and
private response headers. Verify that temporary upload files are cleaned up.

## Public delivery and freshness

Add public `GET /resume` and `HEAD /resume` through a dedicated
`ResumesController#show`, outside admin authentication. On the admin host,
the same path belongs to the owner-only management page. Scope the public
action to the public side of the existing `AdminHost` boundary; link to the
absolute canonical public URL from admin to avoid this path ambiguity.

Return the stored bytes directly with Rails `send_data` and:

- `Content-Type: application/pdf`.
- `Content-Disposition: inline` and the stable suggested filename
  `jeff-miller-resume.pdf`, independent of the uploaded filename.
- `X-Content-Type-Options: nosniff`.
- `Cache-Control: public, no-cache, max-age=0, must-revalidate`.
- An ETag derived from the current document's SHA-256 digest.

Read the current document and evaluate the ETag against that document on
every request. An unchanged conditional request can return 304; a previously
cached response must not hide a newly published version. Keep validators,
headers, and body consistent with one document snapshot during replacement.
Do not promise to refresh PDF tabs that visitors already have open.

HEAD returns the corresponding headers without a body. Full 200 responses
are sufficient for this bounded PDF; Range requests may be ignored initially,
and the action must not advertise byte-range support it does not implement.
Verify browser viewing with the full-response behavior. If no record exists,
return a controlled 404 rather than an HTML success page labeled as a PDF.

Direct top-level PDF navigation does not require an iframe, object element,
or public upload form. Preserve the existing public CSP rather than relaxing
script, object, or framing restrictions. Retain public-host/HTTPS checks.

## Existing links and initial import

Change both homepage/layout resume links to `resume_path`, preserving their
accessible labels, new-tab behavior, and `rel="noopener"`. Do not add
`download` attributes.

Move the existing static PDF to a deployment-included bootstrap location
such as `db/bootstrap/jeff-miller-resume.pdf`. Add an idempotent
`resume:bootstrap` task that uses the same content validation and creates the
singleton only if no published resume exists. It must never overwrite an
admin upload, including during concurrent retries. Fail a first-time import
explicitly if the seed is missing or invalid. Existing published records do
not depend on re-reading the bootstrap PDF.

Run the bootstrap after migrations in `bin/setup` and the Heroku release
command, alongside `admin:bootstrap`. Keep file import out of schema migrations.
The bundled bootstrap copy is a launch seed, not a runtime fallback that can
silently restore stale content. Do not delete the published document through
the admin UI in this version.

Remove `public/jeff-miller-resume.pdf` as part of the same implementation;
otherwise static-file middleware could bypass the legacy route. Add a
temporary redirect from the old public URL to `/resume`, with revalidation
headers. Verify existing shared links end at the current PDF rather than
the bootstrap copy.

## Implementation sequence

1. Add the bounded singleton model, migration, PDF validation, and fixtures.
2. Add safe publication and idempotent bootstrap; import the existing PDF.
3. Add owner-only admin form, navigation, metadata, and success/error feedback.
4. Add public inline delivery, conditional requests, and legacy redirect.
5. Update both public links, setup/release commands, and application guidance.
6. Complete automated and visual checks, then submit an implementation PR.

Expected files include `app/models/resume.rb`, the new migration,
`app/controllers/resumes_controller.rb`,
`app/controllers/admin/resumes_controller.rb`, admin resume views,
`config/routes.rb`, `lib/tasks/resume.rake`, `db/bootstrap/`, `bin/setup`,
`Procfile`, both public link templates, admin navigation/dashboard, request
and model tests, `test/production_smoke.rb`, `README.md`, and `AGENTS.md`.
Update `Gemfile` and its lockfile only for the selected PDF parser.

## Acceptance and validation

- The current owner can upload a valid PDF and immediately retrieve its
  exact bytes at the public `/resume` URL without authentication.
- Anonymous, revoked, expired-session, and non-owner users cannot manage or
  replace the PDF. The admin upload action is unavailable on public hosts.
- Non-PDF, renamed/spoofed, empty, malformed, encrypted, oversize, and missing
  files are rejected without changing the current document or its metadata.
- Replacing a PDF changes the ETag. Requests using the previous ETag receive
  the new bytes; unchanged requests can return 304. HEAD has no body.
- Publication is atomic, bootstrap is retry-safe, and later releases preserve
  the current uploaded PDF. Test competing creation attempts and failed writes.
- Both public links resolve through `/resume`; the legacy URL redirects and
  never serves a stale static copy. A missing record has a deliberate 404.
- Verify headers, script-free/CSP behavior, canonical-host links from admin,
  CSRF, and accessible error/status messages through request/smoke coverage.
- Inspect the admin form at phone and desktop widths and check keyboard use.
  Open the delivered PDF in desktop and mobile browsers to verify inline
  viewing; recognize that visitor settings may force downloads.

Run the repository's required application checks:

```sh
bin/ci
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails runner test/production_smoke.rb
```

Production smoke tests currently run without a production database. Preserve
that workflow by testing the static-free legacy redirect and public security
policy there, while exercising seeded PDF delivery and ETags against the test
database in integration tests. Do not accidentally make the existing smoke
suite require live database credentials or live uploads.

For deployment, verify the database backup/restore procedure and bootstrap
inclusion, then deploy the implementation with its migration and release task.
Verify public inline viewing, one owner replacement, old-link redirection, and
persistence across a dyno restart. Deployment is a separate authorized step.

## This planning branch

Commit this plan and the approved removal of `design-explorations/` and
`design-sources/`. Retain all generated background, social-preview, and static
error assets. Keep the optional image build script, but document that its
source inputs must be restored from Git history before it can run.
Historical repository reviews remain dated records rather than current-state
documentation. No resume implementation or deployment belongs in this commit.

## References

- [Rails data streaming and inline disposition](https://api.rubyonrails.org/classes/ActionController/DataStreaming.html)
- [PostgreSQL binary data](https://www.postgresql.org/docs/current/datatype-binary.html)
- [Heroku ephemeral filesystem](https://devcenter.heroku.com/articles/dyno-isolation#ephemeral-filesystem)
- [Active Storage overview](https://guides.rubyonrails.org/active_storage_overview.html)
