require 'json'
require 'jep/message'

module JEP

module MessageHelper

# serialize message object +message+ into a JEP message string
def serialize_message(message)
  obj = message.object
  bin = message.binary

  escape_all_strings(obj)
  result = object_to_json(obj)
  # the JSON conversion outputs data in UTF-8 encoding and
  # the JEP protocol expects message lengths measured in bytes;
  # there shouldn't be any non-ascii-7-bit characters, though, so json.size would also be ok
  json_len = result.bytesize

  bin.force_encoding("binary")
  binary_len = bin.size

  result.prepend("#{json_len+binary_len}:#{json_len}") 
  result.concat(bin)
  result
end

# extracts a full message from the beginning of +data+ and cuts down +data+ accordingly;
# returns the message object or nil if +data+ doesn't contain a (complete) message
def extract_message(data)
  # interpret input data as binary
  data.force_encoding("binary")
  obj = nil
  bin = nil
  if data =~ /^(\d+):(\d+)\{/
    length_length = $1.size + 1 + $2.size
    overall_length, json_length = $1.to_i, $2.to_i

    if data.size >= length_length + overall_length
      data.slice!(0..(length_length-1))

      json = data.slice!(0..json_length-1)
      # there shouldn't be any non ascii-7-bit characters, transcode just to be sure
      # encode from binary to utf-8 with :undef => :replace turns all non-ascii-7-bit bytes
      # into the replacement character (\uFFFD)
      json.encode!("utf-8", :undef => :replace)
      obj = json_to_object(json)

      # we already forced data to be binary encoded
      bin = data.slice!(0..(overall_length-json_length)-1)
    end
  end
  if obj
    unescape_all_strings(obj)
    Message.new(obj, bin)
  else
    nil
  end
end

# override this method to use other JSON implementations
def object_to_json(obj)
  JSON(obj)
end

# override this method to use other JSON implementations
def json_to_object(json)
  JSON(json)
end

def escape_all_strings(obj)
  each_json_object_string(obj) do |s|
    s.force_encoding("binary")
    bytes = s.bytes.to_a
    s.clear
    bytes.each do |b|
      if b >= 128 || b == 0x25 # %
        s << "%#{b.to_s(16)}".force_encoding("binary")
      else
        s << b.chr("binary")
      end
    end
    # there are no non ascii-7-bit characters left
    s.force_encoding("utf-8")
  end
end

def unescape_all_strings(obj)
  each_json_object_string(obj) do |s|
    # change encoding back to binary 
    # there could still be replacement characters (\uFFFD), turn them into "?"
    s.encode!("binary", :undef => :replace)
    s.gsub!(/%[0-9a-fA-F][0-9a-fA-F]/){|m| m[1..2].to_i(16).chr("binary")}
    s.force_encoding("binary")
  end
end

def each_json_object_string(object, &block)
  if object.is_a?(Hash)
    object.each_pair do |k, v|
      # don't call block for hash keys
      each_json_object_string(v, &block)
    end
  elsif object.is_a?(Array)
    object.each do |v|
      each_json_object_string(v, &block)
    end
  elsif object.is_a?(String)
    yield(object)
  else
    # ignore
  end
end

end

end
