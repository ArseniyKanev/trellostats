class User < ActiveRecord::Base

  def self.create_user_by_oauth_info(trello_user, data)
    user = User.find_or_initialize_by(uid: trello_user.id)
    user.name = trello_user.username
    user.oauth_token = data[:oauth_token]
    user.oauth_token_secret = data[:oauth_token_secret]
    user.time_zone = Time.zone.name
    user.save
    user
  end
end
