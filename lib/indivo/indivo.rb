require 'rubygems'

require 'digest/sha1'
require 'base64'

require 'cgi'

require 'ruby-debug'

require 'basic_client/basic_client'
require 'basic_client/null_logger'

class IndivoClient
  include BasicClient

  def initialize(server_url, consumer_auth, username_domain='', logger=nil)
    @server_url = server_url
    @consumer = OAuth::Consumer.new consumer_auth[:consumer_key], consumer_auth[:consumer_secret], {:site => @server_url}
    @access_token = OAuth::AccessToken.new @consumer

    @username_domain = username_domain

    @logger = logger || NullLogger.new
  end

  def oauth_consumer
    @consumer
  end

  def oauth_token
    @access_token
  end

  # set the token after the fact
  # FIXME: should make a copy here
  def set_token(access_token_auth)
    if access_token_auth
      @access_token = OAuth::AccessToken.new @consumer, access_token_auth[:token], access_token_auth[:secret]
    else
      @access_token = OAuth::AccessToken.new @consumer
    end
    self
  end

  def set_token_from_string(token_str)
    t = CGI::parse(token_str)
    set_token({:token => t['oauth_token'], :secret => t['oauth_token_secret']})
  end

  def get_account_id(account_id)
    begin
      result = get_account_info(account_id)
      result['id']
    rescue WrappedHTTPError => e
      allow_not_found(e)
      nil
    end
  end

  def get_account_info(account_id)
    begin
      do_xml_http(:GET, "/accounts/#{account_id}", {})  
    rescue Net::HTTPNotFound
      nil
    end
  end

  def create_account(full_name, contact_email, account_id = nil) 
    account_id ||= generate_account_id(full_name, contact_email)

    account = do_xml_http(:POST, "/accounts/", {:account_id => account_id, :full_name => full_name, :contact_email => contact_email, :primary_secret_p => "1", :secondary_secret_p => "1"})
    return account['id'], account['secret'][0]
  end

  def account_add_password_auth(account_id, username, password=nil)
    params = {:system => 'password', :username => username}
    if password
      params[:password] = password
    end
    do_xml_http(:POST, "/accounts/#{account_id}/authsystems/", params)
  end

  def account_add_auth(account_id, auth_system, username)
    do_xml_http(:POST, "/accounts/#{account_id}/authsystems/", {:system => auth_system, :username => username})
  end

  def account_resend_secret_url(email)
    do_xml_http(:POST, "/accounts/#{email}/secret-resend", {})
  end

  def account_secret(email)
    begin
      secret = do_xml_http(:GET, "/accounts/#{email}/secret", {})
    rescue WrappedHTTPError => e
      allow_not_found(e)
      nil
    end
  end

  def create_record(last_name, first_name, email, phone_number, address_street, address_postal_code, address_locality, address_region, address_country)
    record = do_xml_http(:POST, "/records/", "
<Contact>
  <name>
    <fullName>#{CGI::escapeHTML(first_name)} #{CGI::escapeHTML(last_name)}</fullName>
    <givenName>#{CGI::escapeHTML(first_name)}</givenName>
    <familyName>#{CGI::escapeHTML(last_name)}</familyName>
  </name>
  <email type='personal'>#{CGI::escapeHTML(email)}</email>
  <address type='home'>
    <streetAddress>#{CGI::escapeHTML(address_street)}</streetAddress>
    <postalCode>#{CGI::escapeHTML(address_postal_code)}</postalCode>
    <locality>#{CGI::escapeHTML(address_locality)}</locality>
    <region>#{CGI::escapeHTML(address_region)}</region>
    <country>#{CGI::escapeHTML(address_country)}</country>
    <timezone></timezone>
  </address>
  <phoneNumber type='home'>#{CGI::escapeHTML(phone_number)}</phoneNumber>
</Contact>
")
    return record['id']
  end

  def set_demographics(indivo_record_id, date_of_birth, gender)
    document = do_xml_http(:POST, "/records/#{indivo_record_id}/documents/special/demographics", "
<Demographics>
  <dateOfBirth>#{CGI::escapeHTML(date_of_birth.to_s)}</dateOfBirth>
  <gender>#{CGI::escapeHTML(gender)}</gender>
</Demographics>
")
    document['id']
  end

  def get_contact(indivo_record_id)
    do_xml_http(:GET, "/records/#{indivo_record_id}/documents/special/contact" , {})
  end

  def get_demographics(indivo_record_id)
    do_xml_http(:GET, "/records/#{indivo_record_id}/documents/special/demographics", {})
  end

  def session_create(username, password)
    do_http :POST, "/oauth/internal/session_create", {'system' => 'password', 'username' => username, 'password' => password}
  end

  def session_create_by_auth_system(system, username)
    do_http :POST, "/oauth/internal/session_create", {'system' => system, 'username' => username}
  end

  def request_token_claim(token)
    do_http :POST, "/oauth/internal/request_tokens/#{token}/claim", {}
  end

  def request_token_info(token)
    doc = do_http :GET, "/oauth/internal/request_tokens/#{token}/info", {}
    doc.body
  end

  def request_token_approve(token, record_id)
    do_http :POST, "/oauth/internal/request_tokens/#{token}/approve", {:record_id => record_id}
  end
  
  def record_list(account_email)
    records_xml = do_xml_http(:GET, "/accounts/#{account_email}/records/", {})
    records_xml['Record'].collect{|r| r['id']}
  end

  def default_record
    record_list[0]
  end

  def basic_record(record_id)
    do_xml_http(:GET, "/records/#{record_id}", {})
  end

  def record_set_owner(record_id, owner_account_id)
    do_xml_http(:POST, "/records/#{record_id}/owner", owner_account_id)
  end

  def record_get_owner(record_id)
    begin
      owner_xml = do_xml_http(:GET, "/records/#{record_id}/owner", {})
    rescue WrappedHTTPError => e
      allow_not_found(e)
      return nil
    end

    return owner_xml
  end

  def record_shares(record_id)
    begin
      shares_xml = do_xml_http(:GET, "/records/#{record_id}/shares/", {})
      return shares_xml['Share'] || []
    rescue WrappedHTTPError => e
      allow_not_found(e)
      nil
    end
  end

  def record_share_add(record_id, email, zone)
    # for now no zone
    begin
      do_xml_http(:POST, "/records/#{record_id}/shares/", {:email => email})
    rescue WrappedHTTPError => e
      allow_not_found(e)
      nil
    end
  end

  def record_share_remove(record_id, email)
    do_xml_http(:DELETE, "/records/#{record_id}/shares/#{email}/delete", {})
  end

  def setup(record_id, app_name, setup_doc_content)
    token_str = do_http(:POST, "/records/#{record_id}/apps/#{app_name}/setup", setup_doc_content)
    #puts token_str
    # parse the token str as a querystring
    token = CGI.parse(token_str.body)
    #puts token
    {:token => token['oauth_token'][0], :secret => token['oauth_token_secret'][0]}
  end

  def notify(record_id, message, document_id=nil, app_url=nil)
    params = {:content => message}
    if document_id
      params[:document_id] = document_id
    end

    if app_url
      params[:document_id] = app_url
    end

    do_xml_http(:POST, "/records/#{record_id}/notify", params)
  end

  def test(record_id)
    do_xml_http(:GET, "/records/#{record_id}/test?foo=bar", {})
  end

  def doc_meta_external(record_id, app_email, external_id)
    do_xml_http(:GET, "/records/#{record_id}/documents/external/#{app_email}/#{external_id}/meta", {})
  end
  
  # read a document
  def document(record_id, document_id, options={})
    raw = options[:raw]

    if(raw)
      do_http(:GET, "/records/#{CGI::escape(record_id)}/documents/#{CGI::escape(document_id)}", {}).body.strip
    else
      do_xml_http(:GET, "/records/#{CGI::escape(record_id)}/documents/#{CGI::escape(document_id)}", {})
    end
  end

  def document_meta(record_id, document_id, options={})
    raw = options[:raw]

    if(raw)
      do_http(:GET, "/records/#{CGI::escape(record_id)}/documents/#{CGI::escape(document_id)}/meta", {}).body.strip
    else
      do_xml_http(:GET, "/records/#{CGI::escape(record_id)}/documents/#{CGI::escape(document_id)}/meta", {})
    end
  end

  def document_versions(record_id, document_id, options={})
    raw = options[:raw]

    if(raw)
      do_http(:GET, "/records/#{CGI::escape(record_id)}/documents/#{CGI::escape(document_id)}/versions/", {}).body.strip
    else
      do_xml_http(:GET, "/records/#{CGI::escape(record_id)}/documents/#{CGI::escape(document_id)}/versions/", {})
    end
  end

  def document_list(record_id, doc_type=nil)
    extra_url = ""
    if doc_type
      extra_url = "?type=#{doc_type}"
    end
    do_xml_http(:GET, "/records/#{CGI::escape(record_id)}/documents/#{extra_url}", {})
  end

  # create a new record document
  def document_new(record_id, app_email, doc_id, content)
    new_doc = do_xml_http(:PUT, "/records/#{CGI::escape(record_id)}/documents/external/#{app_email}/#{CGI::escape(doc_id)}", content)
  end

  # replace a document
  def document_replace(record_id, doc_id, content)
    new_doc = do_xml_http(:POST, "/records/#{CGI::escape(record_id)}/documents/#{doc_id}/replace", content)
  end

  # delete a recently added document
  def document_delete(record_id, doc_id)
    new_doc = do_xml_http(:DELETE, "/records/#{CGI::escape(record_id)}/documents/#{CGI::escape(doc_id)}", {})
  end

  # create a new record document linked to an existing doc
  def document_new_by_rel(record_id, doc_id, rel_type, app_email, external_id, content)
    new_doc = do_xml_http(:POST, "/records/#{record_id}/documents/#{doc_id}/rels/#{rel_type}/external/#{app_email}/#{external_id}", content)
  end
  
  # application-specific documents
  def app_documents(record_id, app_email, tag)
    params = {}
    if tag
      params['tag'] = tag
    end
    do_xml_http(:GET, "/records/#{CGI::escape(record_id)}/apps/#{app_email}/documents/", params)
  end
  
  def app_doc(record_id, app_email, doc_id)
    do_xml_http(:GET, "/records/#{CGI::escape(record_id)}/apps/#{app_email}/documents/#{doc_id}", {})
  end
  
  def app_doc_meta_external(record_id, app_email, external_id)
    do_xml_http(:GET, "/records/#{record_id}/apps/#{app_email}/documents/external/#{external_id}/meta", {})
  end
  
  # create a new app document
  def app_doc_store_external(record_id, app_email, doc_id, content)
    do_xml_http(:POST, "/records/#{CGI::escape(record_id)}/apps/#{app_email}/documents/external/#{CGI::escape(doc_id)}", content)
  end
  
  # update an app doc
  def app_doc_store(record_id, app_email, doc_id, content)
    do_xml_http(:POST, "/records/#{CGI::escape(record_id)}/apps/#{app_email}/documents/#{doc_id}/update", content)
  end

  # get an app doc by its external ID
  def app_doc_by_external_id(record_id, app_email, external_id)
    # find the metadata
    doc_meta = app_doc_meta_external record_id, app_email, external_id
    if doc_meta
      return {:id => doc_meta['id'], :content => app_doc(record_id, app_email, doc_meta['id'])}
    else
      return nil
    end
  end

  def send_message_to_record(record_id, message_id, subject, body)
    # This really ought to be a PUT, but due to a bug in Django, a PUT won't
    # work here.

    do_xml_http(:POST, "/records/#{record_id}/inbox/#{message_id}", :subject => subject, :body => body)
  end

  def generate_account_id(full_name, contact_email)
    basename = full_name.downcase.gsub(/[^a-zA-Z]/, '')

    email_hash = Digest::SHA1.hexdigest(contact_email).to_i(16)
    email_hash_digits = (email_hash % 1000).to_s

    basename + email_hash_digits + "@" + @username_domain
  end

  attr_reader :server_url
end
