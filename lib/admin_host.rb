class AdminHost
  def self.matches?(request)
    request.host == "admin.humani.se" || (!Rails.env.production? && request.host == "admin.lvh.me")
  end

  def self.origin
    return "https://admin.humani.se" if Rails.env.production?

    scheme = ENV["LOCAL_HTTPS"] == "1" ? "https" : "http"
    "#{scheme}://admin.lvh.me:3000"
  end
end
