# A basic client that makes OAuth-authenticated requests and expects an XML
# response.

require 'rubygems'

require 'oauth'
require 'oauth/consumer'

require 'xmlsimple'
require 'rexml/document'
require 'xml/libxml'
require 'xml/xslt'

require 'basic_client/wrapped_http_error'

# patching OAuth for raw queries
module OAuth
  class Consumer
    def create_signed_request(http_method,path, token=nil,request_options={},*arguments)
      request=create_http_request(http_method,path,*arguments)

      # set appropriate content encoding if it's a raw post body
      # FIXME: this is a hack to set the content type to xml
      if arguments[0].kind_of? String
        request.content_type =  "application/xml"

        # add the request-body hash extension here
        extra_params = {
          'oauth_content_type' => request.content_type,
          'oauth_body_hash' => Base64.encode64(Digest::SHA1.digest(arguments[0])).chop
        }

        extra_options = {'extra_params' => extra_params}
      else
        extra_options = {}
      end

      sign!(request,token,request_options.merge(extra_options))
      request
    end
  end
end

# a quick patch to OAuth
module OAuth::Client
  class Helper
    def oauth_parameters
      extra_params = {}
      if @options.keys.include? 'extra_params'
        extra_params = @options['extra_params']
      end
      {
        'oauth_callback'         => options[:oauth_callback],
        'oauth_consumer_key'     => options[:consumer].key,
        'oauth_token'            => options[:token] ? options[:token].token : '',
        'oauth_signature_method' => options[:signature_method],
        'oauth_timestamp'        => timestamp,
        'oauth_nonce'            => nonce,
        'oauth_verifier'         => options[:oauth_verifier],
        'oauth_version'          => '1.0'
      }.reject { |k,v| v.to_s == "" }.merge(extra_params)
    end

    def signature(extra_options = {})
      signature = OAuth::Signature.sign(@request, { :uri      => options[:request_uri],
                                                    :consumer => options[:consumer],
                                                    :token    => options[:token] }.merge(extra_options) )
      
      # only send the first 500 chars, because it could be huge.
      @request['X-OAUTH-SBS'] = signature_base_string(@request)[0..500]
      #puts "SBS " + @request['X-OAUTH-SBS']
      signature
    end

  end
end

module BasicClient
  protected

  def parse_xml(xml)
    XmlSimple.xml_in(xml)
  end

  def get_token(consumer_token_params)
    consumer = OAuth::Consumer.new consumer_token_params[:consumer_key], consumer_token_params[:consumer_secret], {:site => @server_url}
    token = OAuth::AccessToken.new consumer
  end

  def do_xml_http(method, url, params, content_type='application/x-www-form-url-encoded')
    do_xml_http_with_token @access_token, method, url, params, content_type
  end

  def do_xml_http_with_token(token, method, url, params, content_type)
    result = do_http_with_token(token, method, url, params, content_type)
    
    if result
      return parse_xml(result.body)
    else
      nil
    end
  end

  def do_http(method, url, params, content_type='application/x-www-form-url-encoded')
    do_http_with_token @access_token, method, url, params, content_type
  end

  def do_http_with_token(token, method, url, params, content_type)
    @logger.debug "Making #{method} request to #{url} with params #{params.inspect}"

    result = case method 
             when :POST
               token.post "#{@server_url}#{url}", params, {'Content-Type' => content_type}
             when :GET
               token.get "#{@server_url}#{url}"
             when :DELETE
               token.delete "#{@server_url}#{url}"
             when :PUT
               token.put "#{@server_url}#{url}", params
             end

    case result
    when Net::HTTPServerError
      @logger.error "Indivo #{method} call to #{url} got server error: #{result.inspect}"
    when Net::HTTPClientError
      @logger.error "Indivo #{method} call to #{url} got client error: #{result.inspect}"
    end

    raise WrappedHTTPError.new(result) unless result.kind_of?(Net::HTTPSuccess)

    # If we made it to here, the response indicated a success (2xx error code)
    result
  end

  def allow_not_found(e)
    # In many contexts, it makes sense to treat a 404 differently from other
    # types of HTTP errors: for instance, it may indicate that a record we're
    # looking for doesn't exist.

    raise e unless e.original_error.kind_of?(Net::HTTPNotFound)
  end
end
