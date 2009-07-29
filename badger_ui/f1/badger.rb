require 'net/http'
require 'net/https'
require 'rexml/document'
require 'uri'
require 'cgi'
require 'optparse'
require 'ostruct'
require 'yaml'
require 'open-uri'
require 'f1/multipart'


class Badger
  def initialize(finder_path,login,password)
    @finder_path = finder_path
    @login = login
    @password = password
    @cookie = login(login, password)
    raise "Login Failure" if @cookie.nil?
  end
  
  def process(stem)
    overlay_url = upload_shapefile(stem)
    metadata = metadata_params(stem)
    upload_metadata(overlay_url, metadata, @cookie)
    attribute_data = attribute_params(overlay_url, stem, @cookie)
    update_attributes("#{overlay_url.sub(/\.xml$/,'')}/attributes", attribute_data, @cookie)
  end
  
  private
  def login( username, password )
    uri = URI.parse($finder_path)
    res = Net::HTTP.new(uri.host, uri.port)
    res.use_ssl = (uri.scheme= 'https')
    post = Net::HTTP::Post.new("/sessions")
    post.set_form_data( {'login' => username, 'password' => password} )
  #  post.verify_mode = OpenSSL::SSL::VERIFY_NONE
  #  post.use_ssl = (uri.scheme == 'https')

    res.start do |https|
  #          if File.exist? RootCA
  #           http.ca_file = RootCA
  #           http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  #           http.verify_depth = 5
  #          else
  #          end

      #make the initial get to get the JSESSION cookie

      response = https.request(post)
      case response
      when Net::HTTPFound
        puts "Badger got a cookie (logged in)"
      else
        puts "No cookies for badger (login failed)"
      end    
      # get original cookie contains _f1gc_session=blahblahblah
      cookie = response.response['set-cookie']  
    end
  end
 

  def metadata_params(stem)
    mapping = {"overlay_meta"=>["lineage", "metadata_url", "contact_address", "contact_phone", 
                      "citation_url", "shared", "description", "contact_name", 
                      "english_reference_date"], "overlay"=>["name", "tag_cache"]}
    
    # read in the metadata
    xml = "#{stem}.xml"
    raise IOError, "Metadata XML not found: #{xml}" unless File.exists?(xml)
    f = File.open(xml)
    metadata = REXML::Document.new(f)
    f.close()
    
    params = Hash.new
    mapping.each do |set, attributes|
      attributes.each do |attribute| 
        value = metadata.elements["//#{set.gsub(/_/,'-')}/#{attribute.gsub(/_/,'-')}"]
        params["#{set}[#{attribute}]"] = value.text unless value.nil?
        if(attribute == "tag_cache")
          params["#{set}[tag_list]"] = value.text unless value.nil?          
        end
      end
    end
    return params
  end

  def attribute_params(resource, stem, cookie=nil)
    # read in the metadata
    xml = "#{stem}.xml"
    raise IOError, "Metadata XML not found: #{xml}" unless File.exists?(xml)
    f = File.open(xml)
    metadata = REXML::Document.new(f)
    f.close()
    
    url = URI.parse(resource)
    req = Net::HTTP::Get.new(url.path)
    req["Cookie"] = cookie
    response = Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
    
    current_metadata = REXML::Document.new(response.body)
    
    new_attributes = metadata.root.elements["overlay-meta"].elements["data-attributes"]
    current_attributes = current_metadata.root.elements["overlay-meta"].elements["data-attributes"]
    
    # now we actually need to build the request
    params = {}
    attributes = []
    # yes... I know
    current_attributes.elements.each do |child|
      a = {"original_name" => child.elements["original-name"].text, "id" => child.elements["id"].text}
      new_attributes.elements.each do |new_child|
        if new_child.elements["original-name"].text == child.elements["original-name"].text
          attributes << a.merge({"name" => new_child.elements["name"].text, "description" => new_child.elements["description"].text})
          break
        end
      end
    end
    
    attributes.each_with_index do |a,i|
      a.each_pair do |k,v|
        params["data_attributes[#{i}][#{k}]"] = v
      end
    end

    return params
  end

  def upload_shapefile(stem)
    # generate the filenames
    shp = "#{stem}.shp"; shx = "#{stem}.shx"; dbf = "#{stem}.dbf"
    raise IOError, "File not found: #{shp}" unless File.exists?(shp)
    total_file_size = File.size(shp) + File.size(dbf) + File.size(shx)
    raise StandardError, "File is too large to upload: #{shp}" if (total_file_size > 10485760) # 10 MB
    # open the shapefile components
    shpfile = File.open(shp); shxfile = File.open(shx); dbffile = File.open(dbf)
    response = upload({"overlay[shp]" => shpfile, "overlay[dbf]" => dbffile, "overlay[shx]" => shxfile}, @cookie)
    shpfile.close; shxfile.close; dbffile.close
    if response.is_a?(Net::HTTPCreated)
      return response.header["location"]
    else
      raise StandardError, "Upload Failure: #{response.body} for #{stem}"
    end
  end

  def upload( query,cookie = nil )
    url = URI.parse(@finder_path)
    req = Net::HTTP::Post.new("/overlays.xml")
    req["Cookie"] = cookie  
    req.set_multipart_form_data(query)
    res = Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
  end

  def upload_metadata(resource, params, cookie=nil)
    url = URI.parse(resource)
    req = Net::HTTP::Put.new(url.path)
    req["Cookie"] = cookie
    req.set_form_data(params)
    response = Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
    if response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection)
      return response
    else
      raise StandardError, "Metadata Fail: #{response.body} for #{resource}"
    end
  end
  
  def update_attributes(resource, params, cookie=nil)
    upload_metadata(resource, params, cookie)
  end  
end