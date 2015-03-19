class BoardsController < ApplicationController

  def index
    @boards = trello_user.boards.sort_by(&:name)
  end

  def show
    session[:selected] = []
    @board = trello_client.find(:board, params[:id])
    @lists = @board.lists.reverse
  end

  def update_session
    session[:selected] = []
    params[:list_ids].each do |list_id|
      session[:selected] << list_id
    end
    render nothing: true
  end

end
