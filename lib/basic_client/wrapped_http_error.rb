# For some reason (or maybe no reason), Net::HTTP errors aren't subclasses of
# Exception, so we can't actually raise them.  This is pretty typical of the
# sad state of Net::HTTP in general; it's ironic that Ruby became known 
# primarily for Web applications.
#
# Polemics aside, IndivoHTTPError is a lightweight wrapper for Net::HTTP 
# errors that actually is an exception.

class WrappedHTTPError < Exception
  def initialize(http_response)
    @original_error = http_response
  end

  def status_code
    @original_error.code
  end

  def to_s
    "<WrappedHTTPError #{@original_error.inspect}>"
  end

  attr_reader :original_error
end

