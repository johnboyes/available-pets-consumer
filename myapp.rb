require 'sinatra'
require 'net/http'
require 'json'

get('/') do
  pets.filter_map { |pet| "#{pet['name']}<br />" unless pet['name'].nil? }
end

def pets
  url = "#{ENV['PETSTORE_URL']}pet/findByStatus?status=available"
  response = Net::HTTP.get(URI(url))
  JSON.parse(response)
end
