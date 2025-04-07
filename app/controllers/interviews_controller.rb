class InterviewsController < ApplicationController
  before_action :set_interview, only: %i[ show evaluate voice answers answers_by_voice take edit update destroy ]

  # GET /interviews or /interviews.json
  def index
    @interviews = Interview.includes(:job).order(created_at: :desc)
  end

  # GET /interviews/1 or /interviews/1.json
  def show
  end

  # GET /interviews/new
  def new
    @interview = Interview.new
  end

  # GET /interviews/1/edit
  def edit
  end

  # POST /interviews or /interviews.json
  def create
    @interview = Interview.new(interview_params)

    if @interview.save
      redirect_to @interview
    else
      render :new
    end
  end

  # PATCH/PUT /interviews/1 or /interviews/1.json
  def update
    respond_to do |format|
      if @interview.update(interview_params)
        format.html { redirect_to @interview, notice: "Interview was successfully updated." }
        format.json { render :show, status: :ok, location: @interview }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @interview.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /interviews/1 or /interviews/1.json
  def destroy
    @interview.destroy!

    respond_to do |format|
      format.html { redirect_to interviews_path, status: :see_other, notice: "Interview was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def voice
    @questions = @interview.job.job_questions.order(:id)
  end

  def answers
    params[:answers].each do |ans|
      answer = Answer.find(ans[:id])
      answer.update(transcript: ans[:transcript])
    end

    evaluate_interview(@interview)

    redirect_to interviews_path, notice: "Your interview has been submitted and evaluated. View results below."
  end

  def answers_by_voice
    index = params[:job_question_index].to_i
    question = @interview.job.job_questions.order(:id)[index]
    answer = @interview.answers.find_or_initialize_by(job_question: question)

    answer.audio.attach(params[:audio])
    answer.save!

    render json: { status: "ok" }
  end

  def evaluate
    job = @interview.job

    # Build up Q&A input from answers
    input = @interview.answers.includes(:job_question).map.with_index do |answer, i|
      q = answer.job_question.content
      a = answer.transcript.presence || "[No response]"
      "Q#{i + 1}: #{q}\nA#{i + 1}: #{a}"
    end.join("\n\n")

    # Prompt to GPT
    prompt = <<~PROMPT
      Evaluate the following candidate's responses for a #{job.title} position.

      Job Description:
      #{job.description}

      Responses:
      #{input}

      Instructions:
      - Provide a score out of 10 for each answer
      - Calculate a total score
      - Write a short summary highlighting strengths and weaknesses
      - Keep it professional and structured
    PROMPT

    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    begin
      response = client.chat(
        parameters: {
          model: "gpt-4o",
          messages: [
            { role: "system", content: "You are a professional hiring evaluator." },
            { role: "user", content: prompt }
          ]
        }
      )

      summary = response.dig("choices", 0, "message", "content")
      @interview.update!(evaluation_summary: summary)

      redirect_to interviews_path, notice: "Evaluation complete for #{@interview.job.title} interview."

    rescue => e
      Rails.logger.error("OpenAI evaluation failed: #{e.message}")
      redirect_to interviews_path, alert: "Evaluation failed. Please try again later."
    end
  end

  def evaluate_interview(interview)
    @interview = Interview.find(params[:id])
    job = @interview.job

    input = @interview.answers.includes(:job_question).map.with_index do |a, i|
      "Q#{i + 1}: #{a.job_question.content}\nA#{i + 1}: #{a.transcript}"
    end.join("\n\n")

    prompt = <<~PROMPT
      Evaluate the candidate based on the following job description and their answers.
      
      Job Title: #{job.title}
      Description: #{job.description}

      #{input}

      Provide a score out of 10 per answer, total score, and a brief summary.
    PROMPT

    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
    result = client.chat(
      parameters: {
        model: "gpt-4o",
        messages: [
          { role: "system", content: "You are a professional hiring evaluator." },
          { role: "user", content: prompt }
        ]
      }
    )

    @interview.update(evaluation_summary: result.dig("choices", 0, "message", "content"))
    summary = result.dig("choices", 0, "message", "content")
    interview.update(evaluation_summary: summary)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_interview
      @interview = Interview.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def interview_params
      params.require(:interview).permit(:job_id, :evaluation_summary)
    end
end
