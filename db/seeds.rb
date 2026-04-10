# frozen_string_literal: true

# Idempotent local development seeds for exercising Errbot ingestion.

require "uri"

authorized_email = ENV.fetch("AUTHORIZED_USER_EMAIL", "dev@example.com")
app_host = ENV.fetch("APP_HOST", "http://127.0.0.1:3000")
project_slug = "one"
project_name = "Smoke Test App"
project_token = "one"
project_environment = "development"
normalized_app_host = app_host.sub(/\/\z/, "")
uri = URI.parse(normalized_app_host)
dsn = "#{uri.scheme}://#{project_token}@#{uri.host}:#{uri.port}/#{project_slug}"

AuthorizedUser.find_or_create_by!(email_address: authorized_email)

project = Project.find_or_initialize_by(slug: project_slug)
project.name = project_name
project.ingest_token = project_token
project.default_environment = project_environment
project.save!

puts "Seeded authorized user: #{authorized_email}"
puts "Seeded project: #{project.name} (slug=#{project.slug}, token=#{project.ingest_token})"
puts "Smoke test host: #{normalized_app_host}"
puts "Smoke test DSN: #{dsn}"
