class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  helper_method :trello_client, :trello_user, :system_user
  before_filter :authenticate

  include ApplicationHelper

  private

  def trello_user
    return unless system_user
    @trello_user ||= fetch_member(system_user.uid)
  end

  def trello_client
    return unless system_user
    @trello_client ||= TrelloWrapper::trello_client(system_user)
  end

  def system_user
    @system_user ||= User.where(id: session[:user_id], oauth_token: session[:token]).try(:first)
  end

  def authenticate
    redirect_to login_url if !system_user || !trello_user
  end

  def fetch_member(member_id, force = false)
    begin
      Rails.cache.fetch("member-#{member_id}", expires_in: 10.minutes, force: force) do
        trello_client.find(:member, member_id)
      end
    rescue Trello::Error
      nil
    end
  end

end
