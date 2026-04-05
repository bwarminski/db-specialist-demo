class AddIndexToTodosStatus < ActiveRecord::Migration[7.1]
  def change
    add_index :todos, :status
  end
end
