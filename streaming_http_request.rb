require 'em-http'
require 'yajl'

class StreamingHttpRequest < EventMachine::HttpRequest
  attr_accessor :parser

  def post_init
    @parser = Yajl::Parser.new
  end

  def object_parsed(obj)
    puts "*** object_parsed"
    puts obj.inspect
  end

  def connection_completed
    # once a full JSON object has been parsed from the stream
    # object_parsed will be called, and passed the constructed object
    @parser.on_parse_complete = method(:object_parsed)
  end

  def receive_data(data)
    puts "*** received_data"
    # continue passing chunks
    @parser << data
  end
end
