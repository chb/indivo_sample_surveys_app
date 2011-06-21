# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store NOTE: deprecated
  protect_from_forgery #:secret => 'b5e03a0d8428306b9d45b53ceaa90d75'
  
  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password"). 
  # filter_parameter_logging :password

  protected

  def login_required
    if @token
      return true
    end

    redirect_to :controller => :user
    return false
  end

  def set_access_token
    if session[:token]
      @token = session[:token]
      @record = Record.new(@token)
    end
  end
  
  def save_access_token(at)
    session[:token] = {:token => at.token, :secret => at.secret, :record_id => at.params[:xoauth_indivo_record_id]}
  end

end
