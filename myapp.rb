require 'sinatra'
require 'net/http'
require 'json'

get('/') do
  available_pets.filter_map { |pet| "#{pet['name']}<br />" unless pet['name'].nil? }.prepend('<h2>Available</h2>')
end

get('/new') do
  new_pets.filter_map { |pet| "#{pet['name']}<br />" unless pet['name'].nil? }.prepend('<h2>New</h2>')
end

def available_pets
  get_json "#{petstore_url}pet/findByStatus?status=available"
end

def new_pets
  get_json "#{petstore_url}pet/findByStatus?status=new"
end

def get_json(url)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.instance_of? URI::HTTPS
  request = Net::HTTP::Get.new(uri.request_uri)
  request['Accept'] = 'application/json'
  request['authorization'] = 'Bearer YOUR_ACCESS_TOKEN'
  response = http.request(request)
  JSON.parse(response.body)
end

def petstore_url
  petstore_url = ENV['PETSTORE_URL']
  puts "Petstore URL is #{petstore_url}"
  petstore_url
end
