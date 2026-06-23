# frozen_string_literal: true

class AddManualVerifiedBadgeToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :manual_verified_badge, :boolean, null: false, default: false
  end
end
