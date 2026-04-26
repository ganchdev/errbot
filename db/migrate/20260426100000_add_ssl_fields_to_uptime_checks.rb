# frozen_string_literal: true

class AddSslFieldsToUptimeChecks < ActiveRecord::Migration[8.2]

  def change
    add_column :uptime_checks, :ssl_status, :string, null: false, default: "not_applicable"
    add_column :uptime_checks, :ssl_expires_at, :datetime
    add_column :uptime_checks, :ssl_error, :string

    add_index :uptime_checks, :ssl_expires_at
  end

end
