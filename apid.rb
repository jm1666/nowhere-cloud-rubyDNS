#!/usr/bin/env ruby

require 'dotenv'
require 'ipaddress'
require 'json'
require 'sequel'
require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/namespace'

# Class: API
# Inherits from Sinatra::Application, the Application core.
class API < Sinatra::Base
  register Sinatra::JSON
  register Sinatra::Namespace

  Dotenv.load
  # Establishing database connection
  connection = Sequel.connect(ENV['DATABASE_URL'])
  Records = connection[:records]

  # Namespace: /records
  # To Provide Records manipulation
  namespace '/records' do
    get '' do
      redirect to('/records/'), 303
    end

    # Show the records in the database
    get '/' do
      json Records.all
    end

    # Get domain by id
    get '/:id' do |id|
      json Records.first(id: id)
    end

    # Create new entry
    post '/new' do
      payload = JSON.parse(request.body.read)

      if !payload.key?('name') || !payload.key?('ipv4address') || !payload.key?('ipv6address')
        # Pre-check: are the fields here?

        status 409
        json error: 'Invalid Request', description: 'The required fields are not found.'
      elsif (payload.key?('ipv4address') && payload['ipv4address'].empty?) || (payload.key?('ipv6address') && payload['ipv6address'].empty?) || (payload.key?('name') && payload['name'].empty?)
        # Pre-check: No Empty Fields

        status 409
        json error: 'Invalid Request', description: 'Empty Fields discovered.'
      elsif !(payload['name'] =~ /^[a-zA-Z0-9][a-zA-Z0-9.-]{1,30}[a-zA-Z0-9]$/)
        # Pre-check: is this domain right?
        # http://stackoverflow.com/questions/10306690/domain-name-validation-with-regex

        status 409
        json error: 'Invalid Domain', description: 'Domain rule incorrect.'
      elsif !IPAddress.valid_ipv4?(payload['ipv4address']) || !IPAddress.valid_ipv6?(payload['ipv6address'])
        # Pre-check: is the IP valid?

        status 409
        json error: 'Invalid Address', description: 'Not a valid IP address.'
      else
        check_result = Records.where(name: payload['name'])

        if !check_result.empty?
          status 409
          json error: 'Occupied', description: 'This Hostname has been used.'
        else
          return_id = Records.insert(name: payload['name'].to_s, ipv4address: payload['ipv4address'].to_s, ipv6address: IPAddress(payload['ipv6address']).to_s)
          status 201
          json Records.first(id: return_id)
        end
      end
    end

    # Update record by id
    patch '/:id' do |id|
      payload = JSON.parse(request.body.read)

      if (payload.key?('ipv4address') && payload['ipv4address'].empty?) || (payload.key?('ipv6address') && payload['ipv6address'].empty?) || (payload.key?('name') && payload['name'].empty?)
        # Pre-check: No Empty Fields

        status 409
        json error: 'Invalid Request', description: 'Empty Fields discovered.'
      elsif payload.key?('name') && !(payload['name'] =~ /^[a-zA-Z0-9][a-zA-Z0-9.-]{1,30}[a-zA-Z0-9]$/)
        # Pre-check: is this domain right?
        # http://stackoverflow.com/questions/10306690/domain-name-validation-with-regex

        status 409
        json error: 'Invalid Domain', description: 'Domain rule incorrect.'
      elsif (payload.key?('ipv4address') && !IPAddress.valid_ipv4?(payload['ipv4address'])) || (payload.key?('ipv6address') && !IPAddress.valid_ipv6?(payload['ipv6address']))
        # Pre-check: is the IP valid?

        status 409
        json error: 'Invalid Address', description: 'Not a valid IP address.'
      else
        check_result = Records.first(id: id)

        if check_result.empty?
          status 404
          json error: 'Not Found', description: 'The requested entry not found.'
        else
          name = payload.key?('name') ? payload['name'] : check_result['name']
          ipv4 = payload.key?('ipv4address') ? payload['ipv4address'] : check_result['ipv4address']
          ipv6 = payload.key?('ipv6address') ? IPAddress(payload['ipv6address']).to_s : check_result['ipv6address']
          puts name
          puts ipv4
          puts ipv6
          puts check_result
          json check_result.update(name: name, ipv4address: ipv4, ipv6address: ipv6)
        end
      end
    end

    # Delete Record
    delete '/:id' do |id|
      status 200
      body Records.where(id: id).delete.to_s
    end
  end

  # Namespace: /search
  # To Provide search based on hostname and IP
  namespace '/search' do
    get '/name/:name' do |name|
      if !(name =~ /^[a-zA-Z0-9][a-zA-Z0-9.-]{1,30}[a-zA-Z0-9]$/)
        # Pre-check: is this domain right?
        # http://stackoverflow.com/questions/10306690/domain-name-validation-with-regex

        status 409
        json error: 'Invalid Domain', description: 'Domain rule incorrect.'
      else
        json Records.where(name: name)
      end
    end

    get '/ip4/:ip' do |ip|
      if !IPAddress.valid_ipv4?(ip)
        # Pre-check: is the IP valid?

        status 409
        json error: 'Invalid Address', description: 'Not a valid IP address.'
      else
        json Records.first(ipv4address: ip)
      end
    end

    get '/ip6/:ip' do |ip|
      if !IPAddress.valid_ipv6?(ip)
        # Pre-check: is the IP valid?

        status 409
        json error: 'Invalid Address', description: 'Not a valid IP address.'
      else
        json Records.first(ipv6address: IPAddress(ip).to_s)
      end
    end
  end
end
