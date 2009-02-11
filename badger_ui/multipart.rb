require 'net/http'
require 'digest/sha1'
class Net::HTTP::Post
  def set_multipart_form_data(params, boundary=nil)
    boundary ||= Digest::SHA1.hexdigest(params.inspect)
    chunks = params.map { |k,v|
      if(v.is_a?(File))
        %Q{Content-Disposition: form-data; name="#{k}"; filename="#{File.basename(v.path)}"\r\n} +
        %Q{Content-Transfer-Encoding: binary\r\nContent-Type: application/octet-stream\r\n\r\n} +
        %Q{#{v.read}\r\n}
      else 
        %Q{Content-Disposition: form-data; name="#{urlencode(k)}"\r\n} +
        %Q{\r\n#{v}\r\n} 
      end
    }
    self.body = "--#{boundary}\r\n" + chunks.join("--#{boundary}\r\n") + "--#{boundary}--\r\n"
    #puts self.body
    self.content_type = "multipart/form-data; boundary=#{boundary}"
  end
end

# url = URI.parse("http://localhost:4000/overlays.xml")
# req = Net::HTTP::Post.new(url.path)
# p = {"overlay[csv]" => File.open("/Users/prak/code/finder/test/fixtures/data/utah.csv")}
# req.basic_auth 'admin', 'password'
# req.set_multipart_form_data(p)
# res = Net::HTTP.new(url.host, url.port).start {|http| http.request(req)}
# puts res.to_yaml
