class AddQueueStateToStories < ActiveRecord::Migration[7.2]
  def up
    add_column :stories, :queue_state, :string, null: false, default: "queued"
    add_column :stories, :queued_at, :datetime
    add_column :stories, :started_at, :datetime
    add_column :stories, :finished_at, :datetime
    add_column :stories, :last_error, :text
    add_index :stories, [ :queue_state, :queued_at ]

    # Stories made before the queue already ran (or were run by hand), so the queue starts empty.
    execute "UPDATE stories SET queue_state = 'done', queued_at = created_at, finished_at = updated_at"
  end

  def down
    remove_index :stories, [ :queue_state, :queued_at ]
    remove_column :stories, :last_error
    remove_column :stories, :finished_at
    remove_column :stories, :started_at
    remove_column :stories, :queued_at
    remove_column :stories, :queue_state
  end
end
