class CreateInterviews < ActiveRecord::Migration[7.2]
  def change
    create_table :interviews do |t|
      t.references :job, null: false, foreign_key: true
      t.text :evaluation_summary

      t.timestamps
    end
  end
end
