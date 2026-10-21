# Local exception pages use the development console; enforce this policy in production.
Rails.application.configure do
  if Rails.env.production?
    config.content_security_policy do |policy|
      policy.default_src :self
      policy.base_uri :self
      policy.img_src :self
      policy.style_src :self
      policy.manifest_src :self
      policy.script_src :none
      policy.font_src :none
      policy.connect_src :none
      policy.object_src :none
      policy.form_action :none
      policy.frame_ancestors :none
    end
  end
end
