class Interview < ApplicationRecord
  belongs_to :job
  has_many :answers, dependent: :destroy

  after_create :initialize_answers

  private

  def initialize_answers
    job.job_questions.each do |jq|
      answers.create!(job_question: jq)
    end
  end
end
