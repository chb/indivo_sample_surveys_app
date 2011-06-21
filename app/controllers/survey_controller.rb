class SurveyController < ApplicationController

  before_filter :set_access_token, :login_required

  @@RDF_NULL = '<?xml version="1.0"?><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" />'
 
  def test
    render :text => session[:token].to_s
  end
 
  def home
    # load all the surveys in the record
    begin
      survey_info = @record.survey_info
      if survey_info.length == 1
        #If there is only one survey, show it
        redirect_to :controller => :survey, :action => :show, :id => survey_info[0]['id']
      end
    rescue
      session[:token] = nil
      redirect_to :action => 'home'
      return
    end

    @surveys = survey_info.collect do |s|
      whole_survey = @record.survey s['id'], false
      # check for state and answers
      answers = @record.get_answers s['id']
      state = @record.get_state s['id']
      name = whole_survey['RDF'][0]['Survey'][0]['title'] ||= whole_survey['id']
      {:name => name, :id => s['id'], :createdAt => Time.parse(s['createdAt']), :answers => answers, :state => state}
    end

    begin
      @contact = @record.contact
    rescue
      @contact = nil
    end
  end

  def raw
    # special case the test survey
    if params[:id] == 'test'
      render :file => "#{RAILS_ROOT}/exampleSurvey.xml", :content_type => 'application/xml'
    else
      # go fetch the survey
      survey = @record.survey params[:id]
      render :xml => (survey || @@RDF_NULL)
    end
  end

  def meta
    # special case the test survey
    if params[:id] == 'test'
      render :file => "#{RAILS_ROOT}/exampleSurveyMeta.xml", :content_type => 'application/xml'
    else
      # go fetch the survey
      survey_meta = @record.survey_meta params[:id]
      render :xml => survey_meta
    end
  end

  def show
    @id = params[:id]
  end
  
  def state
    if params[:id] == "test"
      state = session[:survey_state] || []
    else
      state = @record.get_state(params[:id])
    end

    render :text => state
  end

  def save_state
    if params[:id] == 'test'
      session[:survey_state] = params[:survey_state]
    else
      @record.save_state params[:id], params[:survey_state]
    end

    render :nothing => true
  end

  def answers
    answers = nil
    
    if params[:id] == 'test'
      answers = session[:survey_answers]
    else
      answers = @record.get_answers(params[:id])
    end
    if answers == nil or answers == ''
      render :text => ''
    else
      render :xml => answers
    end
  end
  
  def save_answers
    if params[:id] == 'test'
      session[:survey_answers] = params[:answers_xml]
    else
      @record.save_answers params[:id], params[:answers_xml]
    end

    render :nothing => true
  end
 
  
end
