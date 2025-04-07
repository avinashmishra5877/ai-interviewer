class TranscribeAnswerJob < ApplicationJob
  queue_as :default

  def perform(answer_id)
    answer = Answer.find(answer_id)
    return unless answer.audio.attached?

    # Step 1: download the webm blob to temp file
    webm_path = Rails.root.join("tmp", "answer_#{answer.id}.webm")
    File.binwrite(webm_path, answer.audio.download)

    # Step 2: convert to .wav using ffmpeg
    wav_path = Rails.root.join("tmp", "answer_#{answer.id}.wav")
    system("ffmpeg -y -i #{webm_path} -ar 44100 -ac 2 #{wav_path}")

    unless File.exist?(wav_path)
      Rails.logger.error "FFmpeg failed to create WAV file for Answer #{answer.id}"
      return
    end

    # Step 3: send WAV to OpenAI Whisper
    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    response = client.audio.transcribe(
      parameters: {
        model: "whisper-1",
        file: File.open(wav_path),
        response_format: "text"
      }
    )

    answer.update!(transcript: response)

  ensure
    # Step 4: cleanup temp files
    File.delete(webm_path) if File.exist?(webm_path)
    File.delete(wav_path) if File.exist?(wav_path)
  end
end
