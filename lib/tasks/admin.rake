namespace :admin do
  desc "Create the fixed site owner without changing an existing identity"
  task bootstrap: :environment do
    owner = Administrator.find_or_initialize_by(email: Administrator::OWNER_EMAIL)
    owner.role = "owner"
    owner.save!
    puts "Owner ready: #{owner.email}"
  end
end
