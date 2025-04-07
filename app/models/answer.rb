# app/models/answer.rb
class Answer < ApplicationRecord
  belongs_to :interview
  belongs_to :job_question
  has_one_attached :audio

  after_commit :transcribe_audio_if_needed, on: [:create, :update]

  private

  def transcribe_audio_if_needed
    return unless audio.attached? && previous_changes.dig("audio_attachment_id").present?

    TranscribeAnswerJob.perform_later(self.id)
  end
end
