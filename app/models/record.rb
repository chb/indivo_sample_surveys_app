#
# Record wrapper to Indivo
#
class Record
  def initialize(token)
    @token = token
    @client = INDIVO.set_token @token
    @record_id = token[:record_id]
    @survey_pha_email = INDIVO_CONFIG[:indivo][:survey_pha_email]
  end
  
  def client
    @client
  end

  def record_id
    @record_id
  end

  def contact
    begin
      @client.get_contact(@record_id)
    rescue WrappedHTTPError
      return nil 
    end

    @client.get_contact(@record_id)
  end

  def survey_ids
    result = @client.document_list(@record_id, 'Survey')
    if result['Document']
      result['Document'].collect {|d| d['id']}
    else
      []
    end
  end
  
  def survey_info
    result = @client.document_list(@record_id, 'Survey')
    if result['Document']
      result['Document'].collect do |d|
        {'id' => d['id'], 'createdAt' => d['createdAt'][0]}
        end
    else
      []
    end
  end
  
  
  def survey(survey_id, raw=true)
    @client.document(@record_id, survey_id, {:raw => raw})
  end

  def survey_meta(survey_id)
    @client.document_meta(@record_id, survey_id, {:raw => true})
  end

  ##
  ## state and answers are strings for now
  ##

  def save_state(survey_id, state)
    state_xml = "<SurveyState>#{CGI::escapeHTML(state)}</SurveyState>"
    @client.app_doc_store_external(@record_id, @survey_pha_email, "state_#{survey_id}", state_xml)
  end

  def get_state(survey_id)
    begin
      state_doc_meta = @client.app_doc_meta_external(@record_id, @survey_pha_email, "state_#{survey_id}")
      if state_doc_meta
        state = @client.app_doc(@record_id, @survey_pha_email, state_doc_meta['id'])
      else
        state = ''
      end
    rescue WrappedHTTPError
      state = ''
    end
  end

  def save_answers(survey_id, answers_xml)
    doc_external_id = "survey_answers_#{survey_id}"

    begin
      # check if there are already answers there
      answers_doc_meta = @client.doc_meta_external(@record_id, @survey_pha_email, doc_external_id)
    rescue WrappedHTTPError
      answers_doc_meta = nil
    end

    # do we need to replace the doc?
    if answers_doc_meta
      doc_id = answers_doc_meta['latest'][0]['id']
      @client.document_replace(@record_id, doc_id, answers_xml)
    else
      debugger
      @client.document_new_by_rel(@record_id, survey_id, "answers", @survey_pha_email, doc_external_id, answers_xml)
    end
  end

  def get_answers(survey_id)
    begin
      answers_doc_meta = @client.doc_meta_external(@record_id, @survey_pha_email, "survey_answers_#{survey_id}")
      if answers_doc_meta
        # get the latest version of the answers
        answers = @client.document(@record_id, answers_doc_meta['latest'][0]['id'], {:raw => true})
      else
        answers = nil
      end
    rescue WrappedHTTPError
      answers = nil
    end
  end
end
