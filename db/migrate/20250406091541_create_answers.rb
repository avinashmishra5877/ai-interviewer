class CreateAnswers < ActiveRecord::Migration[7.2]
  def change
    create_table :answers do |t|
      t.references :interview, null: false, foreign_key: true
      t.references :job_question, null: false, foreign_key: true
      t.text :transcript

      t.timestamps
    end
  end
end
