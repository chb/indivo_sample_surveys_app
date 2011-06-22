
require 'indivo'
require 'ruby-debug'

#
# test out the indivo client against a real server
# this needs to be far better modularized
#

server_url = "http://localhost:8000"
chrome_auth = {:consumer_key => 'chrome', :consumer_secret => 'chrome'}
tudiabetes_auth = {:consumer_key => 'tudiabetes@apps.indivo.org', :consumer_secret => 'tudiabetes'}

Indivo = IndivoClient.new(server_url, chrome_auth)

# create an account
max_id, secret = Indivo.create_account('Max Adida', 'max@adida.net', 'max@adida.net')

# get info
puts Indivo.get_account_info('max@adida.net')
# puts Indivo.get_account_info('max2@adida.net')

# add the mychildren's auth
Indivo.account_add_password_auth('max@adida.net', 'max', 'test')

# create a record, make it owned by account ben@adida.net
record = Indivo.create_record('Adida', 'Max', 'max@adida.net', '617-395-8535', '1 west street', '02115', 'Boston', 'MA', 'USA')
Indivo.record_set_owner(record, 'max@adida.net')

# get a request token
TDIndivo = IndivoClient.new(server_url, tudiabetes_auth)

# get a request token
rt = TDIndivo.oauth_consumer.get_request_token({:oauth_callback => 'oob'})
puts rt.token

# prime tudiabetes for the record
# tudiabetes_user_token = Indivo.setup(record, 'tudiabetes@apps.indivo.org', nil)

# log in as the account max/test
session_auth = Indivo.session_create('max', 'test')
Indivo.set_token_from_string(session_auth)

current_id = CGI::parse(session_auth)['account_id']
print "current ID is #{current_id}"

# claim the request token
Indivo.request_token_claim(rt.token)

# get info about it
print Indivo.request_token_info(rt.token)

# list of recordsss
records = Indivo.record_list(current_id)

# approve it
print Indivo.request_token_approve(rt.token, records[0])

puts records
documents = Indivo.document_list(records[0])
print documents

record = records[0]

# authorize the tudiabetes app as admin
AdminIndivo = IndivoClient.new(server_url, chrome_auth)
tudiabetes_user_token = AdminIndivo.setup(record, 'tudiabetes@apps.indivo.org', nil)

puts "tudiabetes #{tudiabetes_user_token}"

# authenticate as the TuDiabetes app
PHAIndivo = IndivoClient.new(server_url, tudiabetes_auth)
PHAIndivo.set_token(tudiabetes_user_token)

# prime another PHA
survey_user_token = PHAIndivo.setup(record, 'surveys@apps.indivohealth.org', nil)

puts "survey authorized: #{survey_user_token}"


