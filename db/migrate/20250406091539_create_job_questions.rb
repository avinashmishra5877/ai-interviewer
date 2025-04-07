class CreateJobQuestions < ActiveRecord::Migration[7.2]
  def change
    create_table :job_questions do |t|
      t.references :job, null: false, foreign_key: true
      t.text :content

      t.timestamps
    end
  end
end
