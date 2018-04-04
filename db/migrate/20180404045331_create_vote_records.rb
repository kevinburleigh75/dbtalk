class CreateVoteRecords < ActiveRecord::Migration[5.1]
  def change
    create_table :vote_records do |t|
      t.uuid    :uuid,              null: false
      t.string  :name,              null: false
      t.boolean :has_been_counted,  null: false

      t.timestamps
    end
  end
end
