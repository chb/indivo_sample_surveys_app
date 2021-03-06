# Indivo Sample Surveys App

## About
This is an  [Indivo](http://indivohealth.org/) app that allows users to take surveys stored on their records using the [Indivo Survey Client](https://github.com/chb/survey_client).  Survey state and answers are stored in the user's record, so they can complete the survey at a later time, or review answers they have submitted.  If a user does not have any Survey documents on their record, the application will allow them to take an example survey, which does not have its state or answers stored on the record.

## Installation (Ubuntu)
* You will need to have the following installed for a basic setup
 * Ruby 1.8.7 
 * Rails 2.3.4+
 * SQLite
 * git

*  clone this repository
 * <code>git clone --recursive git://github.com/chb/indivo_sample_surveys_app.git</code>
 * Instruction from here on will use $APP_HOME to refer to the location you cloned to

* install required packages
 * <code>sudo apt-get install libsqlite3-0 libsqlite3-dev sqlite3 openssl libssl-dev libxml2 libxml2-dev libxslt1.1 libxslt1-dev</code>

* install required gems
 * <code>sudo gem install sqlite3 xml-simple libxml-ruby ruby-xslt</code>

* create config files from sample ones
 * <code>cp $APP_HOME/config/database.yml.sample database.yml</code>
 * <code>cp $APP_HOME/config/indivo.yml.sample indivo.yml</code>

* Create and migrate the database
  * <code>$APP_HOME/rake db:migrate</code>

## Configuration
* You will need an instance of [Indivo Server](https://github.com/chb/indivo_server) and [Indivo UI Server](https://github.com/chb/indivo_ui_server) installed, and have generated credentials for the Indivo Sample Surveys App.  See the [Indivo](http://indivohealth.org/) website for more information.
* edit <code>$APP_HOME/config/indivo.yml</code> to configure the app's credentials, and the location of your Indivo X and Indivo UI Servers
* A sample user app configuration for your Indivo installation bootstrap is
 <pre>&lt;user_app name='Surveys' email='survey_server@apps.chip.org'&gt;
      &lt;consumer_key&gt;survey_server&lt;/consumer_key&gt;
      &lt;secret&gt;survey_server&lt;/secret&gt;
      &lt;has_ui&gt;True&lt;/has_ui&gt;
      &lt;frameable&gt;True&lt;/frameable&gt;
      &lt;start_url_template&gt;http://mymachine:3000/user/go_add?record_id={record_id}&lt;/start_url_template&gt;
      &lt;callback_url&gt;http://mymachine:3000/user/after&lt;/callback_url&gt;
      &lt;description&gt;Take Surveys&lt;/description&gt;
    &lt;/user_app&gt;</pre>

## Running 
* To launch the Sample Surveys App on localhost port 3000, run the following
 * <code>$APP_HOME/script/server</code>
