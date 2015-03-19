Rails.application.routes.draw do

  root "boards#index"

  get "/sign_in" => "sessions#create", as: :login
  get "/sign_out" => "sessions#destroy", as: :logout
  get '/oauth/callback' => "sessions#auth"
  get '/lists/update_card' => "lists#update_card"
  get '/lists/refresh_card' => "lists#refresh_card"
  get '/lists/selected' => "lists#selected"
  get '/lists/selected/stats' => "lists#stats"
  get '/lists/selected/report' => "lists#report"

  resources :boards, only: [:index, :show] do
    member do
      post :update_session
    end
  end

  resources :lists, only: [:show] do
    member do
      get :stats
      get :report
    end
  end

end
