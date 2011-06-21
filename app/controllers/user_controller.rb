require 'oauth/consumer'

class UserController < ApplicationController

  def home
    @token = session[:token]
  end

  def go_add
    session[:admin] = false

    # there may be a record_id specified
    request_token_params = {}
    record_id = params[:record_id]
    document_id = params[:document_id]

    if record_id
      request_token_params[:indivo_record_id] = record_id
    end

    if document_id and document_id != "":
      session[:document_id] = document_id
    end
    
    @request_token = INDIVO.oauth_consumer.get_request_token({:oauth_callback => 'oob'}, request_token_params)
    save_request_token @request_token

    # we override the authorize URL here
    config = INDIVO_CONFIG[:indivo]
    if config[:ui_server]
      redirect_to "#{config[:ui_server]}#{config[:oauth_authorize]}?oauth_token=#{@request_token.token}"
    else
      redirect_to @request_token.authorize_url
    end
  end

  def after
    @request_token = restore_request_token

    # verify that this matches
    if params['oauth_token'] != nil and @request_token.token != params['oauth_token']
      redirect_to root_path()
      return
    end

    @access_token = @request_token.get_access_token({:oauth_verifier => params['oauth_verifier']})

    save_access_token @access_token

    # FIXME: better ways to remove session variables
    session[:request_token] = nil

    if session[:document_id]:
      redirect_to :controller => :survey, :action => :show, :id => session[:document_id] 
      session[:document_id] = nil
    else
      # redirect so reload always works
      redirect_to :controller => :survey, :action => :home
    end
  end

  def logout
    # FIXME: better way to clear this
    session[:token] = nil
    redirect_to :controller => :user
  end

  def save_request_token(rt)
    session[:request_token] = {:token => rt.token, :secret => rt.secret}
  end

  def restore_request_token
    OAuth::RequestToken.new(INDIVO.oauth_consumer, session[:request_token][:token], session[:request_token][:secret])
  end
  
end
