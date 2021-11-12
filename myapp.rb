require 'sinatra'
require 'net/http'
require 'json'

get('/') do
  pets.filter_map { |pet| "#{pet['name']}<br />" unless pet['name'].nil? }
end

def pets
  url = 'https://petstore.swagger.io/v2/pet/findByStatus?status=available'
  uri = URI(url)
  response = Net::HTTP.get(uri)
  JSON.parse(response)
end
