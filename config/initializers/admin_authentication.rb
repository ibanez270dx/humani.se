require Rails.root.join("lib/admin_host")
require Rails.root.join("lib/admin_google_authentication")

Rails.application.config.session_store :cookie_store,
  key: Rails.env.production? ? "__Host-humanise_session" : "humanise_session",
  secure: Rails.env.production?, httponly: true, same_site: :lax

OmniAuth.config.full_host = AdminHost.origin
OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.on_failure = ->(env){ [302, { "location" => "/sign-in?error=authentication", "content-type" => "text/html" }, []] }
Rails.application.config.middleware.use AdminGoogleAuthentication
