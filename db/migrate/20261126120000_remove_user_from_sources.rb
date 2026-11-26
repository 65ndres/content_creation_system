class RemoveUserFromSources < ActiveRecord::Migration[7.2]
  def change
    remove_reference :sources, :user, foreign_key: true, index: true
  end
end
