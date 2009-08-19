#!/usr/bin/env ruby

require 'rubygems'
require 'csv'
require 'net/http'
require 'zip/zip'

def usage
  return "Usage: csver.rb <file> <finder_url> [directory]"
end

def main
  return usage unless check_args
  file = get_file 
  ids = get_ids(file)
  download_csvs(ids)
end

def check_args
  return (!ARGV[0].nil? && !ARGV[1].nil?)
end

def get_file
  return ARGV[0]
end

def get_ids(file)
  csv = CSV::Reader.parse(File.read(file))
  return csv.entries[1..csv.entries.length].map { |row| row[0].to_i }
end

def download_csvs(ids)
  ids.each { |id| download_and_extract(id) }
end

def download_and_extract(id)
  path = "/overlays/download/"
  puts "Working on overlay #{id}"
  url = URI.parse("#{finder_url}#{path}#{id}.zip")
  res = Net::HTTP.get_response(url)
  
  temp_zip = Tempfile.new("shpi", directory)
  temp_zip.write res.read_body
  temp_zip.close
  
  Zip::ZipFile.open(temp_zip.path) do |zf|
    zf.each do |file|
      suffix = file.name[-4..file.name.length]
      file.extract("#{directory}#{id}#{suffix}") unless file.name.include? "README"
    end
  end
  url_xml = finder_url + "/overlays/#{id}.xml"
  system "curl #{url_xml} -o #{directory}#{id}.xml"
rescue Zip::ZipError
  puts "Warning: Overlay #{id} was not valid"
end

def directory
  return (ARGV[2] || './')
end

def finder_url
  return ARGV[1]
end

main