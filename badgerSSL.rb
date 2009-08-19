#!/usr/bin/env ruby

#--
# Upload script for Finder!
# Version 2.0.1 beta
# Copyright (c) 2008 FortiusOne
# Copyright (c) 2005 Bill Stilwell (bill@marginalia.org)
#++

require 'net/http'
require 'net/https'
require 'rexml/document'
require 'uri'
require 'cgi'
require 'optparse'
require 'ostruct'
require 'yaml'
require 'multipart'

BATCH_FILE_FORMAT = "shp"

class Net::HTTP
  alias_method :old_initialize, :initialize
  def initialize(*args)
    old_initialize(*args)
    @ssl_context = OpenSSL::SSL::SSLContext.new
    @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
end

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

def upload( query,cookie = nil )
  url = URI.parse($finder_path)
  res = Net::HTTP.new(url.host, url.port)
  res.use_ssl = (url.scheme == 'https')
  req = Net::HTTP::Post.new("/overlays.xml")
  req["Cookie"] = cookie  
  req.set_multipart_form_data(query)
  res = res.start {|http| http.request(req) }
end

def metadata(resource, params, cookie=nil)
  url = URI.parse($finder_path+"/overlays/"+resource)
  res = Net::HTTP.new(url.host, url.port)
  res.use_ssl = (url.scheme == 'https')
  req = Net::HTTP::Put.new(url.path)
  req["Cookie"] = cookie
  req.set_form_data(params)
  res = res.start {|http| http.request(req) }
  if res.is_a?(Net::HTTPSuccess) || res.is_a?(Net::HTTPRedirection)
    return res
  else
    raise StandardError, "Metadata Fail: #{res.body} for #{resource}"
  end
end

if __FILE__ == $0

  # Parse the command line options
  options = OpenStruct.new
  opts = OptionParser.new
  opts.banner = "Usage: badger.rb [options] filename"
  opts.on("-e [USERNAME]", "--user [USERNAME]", "GeoCommons account username") {|username| options.username = username }
  opts.on("-p [PASSWORD]", "--password [PASSWORD]", "GeoCommons password") {|password| options.password = password }
  opts.on("-f FILE", "--file FILE", "--overlay FILE", "File to upload") {|overlay| options.overlay = overlay }
  opts.on("-t=[TITLE]", "--title=[TITLE]", "Title of the overlay") {|title| options.title = title }
  opts.on("-d=[DESCRIPTION]", "--description=[DESCRIPTION]", "--desc=[DESCRIPTION]", "Description of the overlay") {|description| options.description = description }
  opts.on("--tags=[TAGS]", Array, "Tags to be applied (comma separated)") {|tags| options.tags = tags}
  opts.on("--is-private", "Set visibility to private") {|private| options.private = private}
  opts.on("-s", "Store the credentials to a configuration file") {|save| options.save = save}
  opts.on("--meta=[METAFILE]", "Metadata Filename") {|metadata| options.metadata = metadata}
  opts.on("--batch=[DIRECTORY]", "Batch upload a directory") {|batch| options.batch = batch}
  opts.on("--finder=[FINDER URL]", "Finder web address") {|finder| options.finder = finder; $finder_path = finder}
  opts.on("-c", "Provide a terminal interface to get username and password") {|terminal| options.terminal = terminal}
  
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
  
  files = opts.parse(ARGV)
  if options.batch
    files = Dir.glob(options.batch.gsub(/\/$/,'') + "/*.xml")
  elsif files.length == 0
    raise "You must specify at least one file or a batch upload directory!"
  end

  # Split the tags
  if options.tags
    options.tags.each do |tag|
      tag.gsub!(/^(.*) (.*)$/, '"\1 \2"')
    end
  end

  # if options.terminal
  #   options.username = ask("Enter your Finder! username: ") {|q| q.echo = false} unless options.username
  #   options.password = ask("Enter your Finder! password: ") {|q| q.echo = false} unless options.password
  #   options.finder = ask("Enter the URL to Finder!: ") {|q| q.echo = false} unless options.finder
  #   options.batch = ask("Batch upload directory?: ") {|q| q.echo = false} unless options.batch
  # end
  
  # Optionally load or save the login credentials to a stored file
  # TODO: store the password as a hash
  if test ?r, "#{ENV['HOME']}/.geocommonsrc"
    config = YAML.load(File.open("#{ENV['HOME']}/.geocommonsrc"))
    options.username = config['username'] if ! options.username
    options.password = config['password'] if ! options.password
  else
    # puts "No config file, consider running with -s to create one."
  end

  if options.save
    conf = {
      "username" => options.username,
      "password" => options.password,
    }
    File.open("#{ENV['HOME']}/.geocommonsrc", "w") { |f| YAML.dump(conf, f)}
    puts "Config file saved."
  end

  ids=[]
  cookie = options.username.nil? ? nil : login(options.username, options.password)
  for overlay in files
    if options.batch
      options.metadata = overlay
      overlay = options.metadata.gsub(/\.xml/,'')
    else
      overlay = overlay.gsub(/\.shp/, '')
    end
    
    shp = "#{overlay}.shp"
    shx = "#{overlay}.shx"
    dbf = "#{overlay}.dbf"
    xml = "#{overlay}.xml"
    
    puts "Overlay: #{overlay}"
    
    # Upload the overlay file
    raise "File #{overlay} doesn't exist or isn't readable." if ! test ?r, shp
    shpfile = File.open( shp )
    shxfile = File.open( shx )
    dbffile = File.open( dbf )
    #xmlfile = File.open( xml )
    params = {}
    params["overlay[shp]"] = shpfile
    params["overlay[shx]"] = shxfile
    params["overlay[dbf]"] = dbffile
   
    response = upload(params, cookie)
    
    shpfile.close
    shxfile.close
    dbffile.close
    
    case response
    when Net::HTTPCreated
      ids << response.header["location"]
    else
      puts "error uploading file: #{response.body}."
      next
    end
    puts response.message.inspect
    overlay_id = response.header["location"].match(/(\d+)\.xml/)[1]
    
    # Upload the overlay metadata
    params = {}    
    mapping = {"overlay_meta"=>["lineage", "metadata_url", "contact_address", "contact_phone", 
                      "citation_url", "shared", "description", "contact_name", 
                      "english_reference_date"], "overlay"=>["name"]}
    
    if options.metadata
      f = File.open(xml)
      overlay = REXML::Document.new(f)
      f.close()
      
      mapping.each do |set, attributes|
        attributes.each do |attribute| 
          value = overlay.elements["//#{set.gsub(/_/,'-')}/#{attribute.gsub(/_/,'-')}"]
          params["#{set}[#{attribute}]"] = value.text unless value.nil?
        end
      end

      tags = REXML::XPath.match(overlay, "//tag/name").collect { |t| t.text }
      params["overlay[tag_list]"] = tags.join(",")      
      
    else
      params["overlay[name]"] = options.title if options.title
      params["overlay_meta[description]"] = options.description if options.description
      params["overlay[tag_list]"] = options.tags.join(",") if options.tags
      params["overlay_meta[shared]"] = options.private ? false : true
    end
    
    response = metadata(overlay_id, params, cookie)

#    case response
#    when Net::HTTPOK
#      puts "Uploaded! #{ids.last.gsub(/\.xml/,'')}"
#
#    else

      puts "Uploaded! #{ids.last.gsub(/\.xml/,'')}"
#      puts response.body
#    end
  end


end
