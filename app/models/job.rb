class Job < ApplicationRecord
  has_many :job_questions, dependent: :destroy
  has_many :interviews

  after_create :generate_screening_questions

  def generate_screening_questions
    return unless description.present?

    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    prompt = <<~PROMPT
      Generate 10 concise screening interview questions for the following role:
      Title: #{title}
      Description: #{description}
    PROMPT

    begin
      response = client.chat(
        parameters: {
          model: "gpt-4o",
          messages: [
            { role: "system", content: "You are an expert hiring manager." },
            { role: "user", content: prompt }
          ]
        }
      )
      questions = response.dig("choices", 0, "message", "content")
      questions.split("\n").each do |line|
        clean = line.strip.sub(/^\d+\.\s*/, "")
        next if clean.blank?
        job_questions.create(content: clean)
      end
    rescue Faraday::ResourceNotFound => e
      Rails.logger.error("OpenAI 404: #{e.response}")
    rescue => e
      Rails.logger.error("Something terrible happened: #{e.message}")
    end
  end
end
