require "test_helper"

class SiteTest < ActionDispatch::IntegrationTest
  test "home page renders its navigation and responsive assets" do
    get root_path

    assert_response :success
    assert_select "h1", "Hi. I’m Jeff."
    assert_select "main#main-content"
    assert_select "a.skip-link[href='#main-content']"
    assert_select "a[href='/jeff-miller-resume.pdf']", count: 2
    assert_select "a[href='https://calendly.com/jeff-dev/meeting']"
    assert_select "link[rel='manifest'][href='/manifest.json']"
    assert_select "script", count: 0

    assert_select "link[rel='stylesheet']" do |links|
      links.each{ |link| assert_public_asset link["href"] }
    end
    assert_select ".night-sky img" do |images|
      image = images.first
      assert_public_asset image["src"]
      variants = image["srcset"].split(",").map(&:split)
      assert_equal %w[1440w 2560w 3200w], variants.map(&:last)
      variants.each{ |url, _width| assert_public_asset url }
    end
  end

  test "manifest icons and resume are available" do
    get "/manifest.json"

    assert_response :success
    manifest = response.parsed_body
    assert_equal "/", manifest.fetch("start_url")
    manifest.fetch("icons").each do |icon|
      assert_public_asset icon.fetch("src")
    end
    assert_public_asset "/jeff-miller-resume.pdf"
  end

  test "health and deployment status remain available" do
    get rails_health_check_path
    assert_response :success

    get "/status"
    assert_response :success
    assert_equal "test", response.parsed_body.fetch("environment")
    assert_equal "test", response.parsed_body.fetch("version")
    assert_equal "test", response.parsed_body.fetch("sha")
    assert_equal "test", response.parsed_body.fetch("deployed_at")
    assert_equal Rails.application.config.started_at, response.parsed_body.fetch("started_at")
    assert_nothing_raised{ Time.iso8601(response.parsed_body.fetch("started_at")) }
  end

  test "unused framework and service worker routes are absent" do
    %w[/service-worker /cable /rails/active_storage/blobs/redirect/unused/file].each do |path|
      get path
      assert_response :not_found
    end
  end

  private

  def assert_public_asset(url)
    asset_path = Rails.root.join("public", url.delete_prefix("/"))
    return assert File.file?(asset_path), "Missing public file: #{url}" unless url.start_with?("/assets/")

    # Integration tests do not mount Sprockets' development asset server.
    # Resolve URLs against the compiled manifest or asset environment.
    digest_path = url.delete_prefix("/assets/")
    logical_path = digest_path.sub(/-[0-9a-f]{64}(?=\.)/, "")
    asset = Rails.application.assets&.find_asset(logical_path)
    available = File.file?(asset_path) || asset&.digest_path == digest_path
    assert available, "Missing pipeline asset: #{url}"
  end
end
