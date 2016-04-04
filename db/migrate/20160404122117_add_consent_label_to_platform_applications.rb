class AddConsentLabelToPlatformApplications < ActiveRecord::Migration
  def self.up
    add_column :platform_applications, :consent_label, :text
  end

  def self.down
    remove_column :platform_applications, :consent_label
  end
end
