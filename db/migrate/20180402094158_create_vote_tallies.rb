class CreateVoteTallies < ActiveRecord::Migration[5.1]
  def change
    create_table :vote_tallies do |t|
      t.string  :name,      null: false
      t.integer :num_votes, null: false

      t.timestamps
    end
  end
end
