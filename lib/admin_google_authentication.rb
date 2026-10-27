# OmniAuth is middleware, so route constraints alone cannot isolate its endpoints.
class AdminGoogleAuthentication
  def initialize(app)
    @app = app
    @authentication = OmniAuth::Builder.new(app) do
      provider :google_oauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"],
        scope: "openid,email,profile", access_type: "online", prompt: "select_account",
        provider_ignores_state: false, pkce: true,
        overridable_authorize_options: [],
        client_options: { connection_opts: { request: { timeout: 10, open_timeout: 5 } } },
        redirect_uri: "#{AdminHost.origin}/auth/google_oauth2/callback"
    end
  end

  def call(env)
    if AdminHost.matches?(Rack::Request.new(env))
      @authentication.call(env)
    else
      @app.call(env)
    end
  end
end
