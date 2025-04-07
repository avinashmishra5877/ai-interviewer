Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  root "jobs#index"

  # JOBS
  resources :jobs do
    post :start_interview, on: :member
  end

  # INTERVIEWS
  resources :interviews do
    member do
      get  :take                                  # View for text-based Q&A
      get  :voice                                 # View for voice-based bot interview
      post :answers, as: :submit_answers          # Form POST for typed answers
      post :evaluate                              # Triggers GPT evaluation
      post :answers_by_voice                      # Audio upload from bot interview
    end
  end

  # ANSWERS
  resources :answers, only: [] do
    post :upload_audio, on: :member # optional if you still have manual audio uploads
  end
end
