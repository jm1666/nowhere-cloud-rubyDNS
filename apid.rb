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
  Records = connection[:dns_records]

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

      if !payload.key?('type') || !payload.key?('name')
        # Pre-check: are the fields here?

        status 409
        json 'Status' => 'Error', 'Description' => 'FIELDS_MISSING'
      elsif (payload.key?('type') && payload['type'].empty?) \
         || (payload.key?('name') && payload['name'].empty?) \
         || (payload.key?('ipv4address') && payload['ipv4address'].empty?) \
         || (payload.key?('ipv6address') && payload['ipv6address'].empty?) \
         || (payload.key?('cname') && payload['cname'].empty?)
        # Pre-check: No Empty Fields

        status 409
        json 'Status' => 'Error', 'Description' => 'FIELDS_EMPTY'
      elsif !(payload['name'] =~ /^[a-zA-Z0-9][a-zA-Z0-9.-]{1,30}[a-zA-Z0-9]$/)
        # Pre-check: is this domain right?
        # http://stackoverflow.com/questions/10306690/domain-name-validation-with-regex

        status 409
        json 'Status' => 'Error', 'Description' => 'INVALID_DOMAIN'
      elsif !IPAddress.valid_ipv4?(payload['ipv4address']) \
         || !IPAddress.valid_ipv6?(payload['ipv6address'])
        # Pre-check: is the IP valid?

        status 409
        json 'Status' => 'Error', 'Description' => 'INVALID_IP'
      else
        return_id = Records.insert(type: payload['type'].to_s,\
                                   name: payload['name'].to_s,\
                                   ipv4address: payload['ipv4address'].to_s,\
                                   ipv6address: IPAddress(payload['ipv6address']).to_s,\
                                   cname: payload['cname'].to_s)
        status 201
        json Records.first(id: return_id)
      end
    end

    # Update record by id
    patch '/:id' do |id|
      payload = JSON.parse(request.body.read)

      if payload.key?('type')
        # Updating Type is not supposed, according to design of CloudFlare

        status 409
        json 'Status' => 'Error', 'Description' => 'ACTION_NOT_PERMITTED'
      elsif (payload.key?('name') && payload['name'].empty?) \
         || (payload.key?('ipv4address') && payload['ipv4address'].empty?) \
         || (payload.key?('ipv6address') && payload['ipv6address'].empty?) \
         || (payload.key?('cname') && payload['cname'].empty?)
        # Pre-check: No Empty Fields

        status 409
        json 'Status' => 'Error', 'Description' => 'FIELDS_EMPTY'
      elsif payload.key?('name') && !(payload['name'] =~ /^[a-zA-Z0-9][a-zA-Z0-9.-]{1,30}[a-zA-Z0-9]$/)
        # Pre-check: is this domain right?
        # http://stackoverflow.com/questions/10306690/domain-name-validation-with-regex

        status 409
        json 'Status' => 'Error', 'Description' => 'INVALID_DOMAIN'
      elsif (payload.key?('ipv4address') && !IPAddress.valid_ipv4?(payload['ipv4address'])) \
         || (payload.key?('ipv6address') && !IPAddress.valid_ipv6?(payload['ipv6address']))
        # Pre-check: is the IP valid?

        status 409
        json 'Status' => 'Error', 'Description' => 'INVALID_IP'
      else
        check_result = Records.first(id: id)

        if check_result.empty?
          status 404
          json 'Status' => 'Error', 'Description' => 'ENTITY_NOT_FOUND'
        else
          name = payload.key?('name') ? payload['name'] : check_result['name']
          ipv4 = payload.key?('ipv4address') ? payload['ipv4address'] : check_result['ipv4address']
          ipv6 = payload.key?('ipv6address') ? IPAddress(payload['ipv6address']).to_s : check_result['ipv6address']
          cname = payload.key?('cname') ? IPAddress(payload['cname']).to_s : check_result['cname']
          json check_result.update(name: name, ipv4address: ipv4, ipv6address: ipv6, cname: cname)
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
        json 'Status' => 'Error', 'Description' => 'INVALID_DOMAIN'
      else
        json Records.where(name: name)
      end
    end

    get '/ip4/:ip' do |ip|
      if !IPAddress.valid_ipv4?(ip)
        # Pre-check: is the IP valid?

        status 409
        json 'Status' => 'Error', 'Description' => 'INVALID_IP'
      else
        json Records.where(ipv4address: ip)
      end
    end

    get '/ip6/:ip' do |ip|
      if !IPAddress.valid_ipv6?(ip)
        # Pre-check: is the IP valid?

        status 409
        json 'Status' => 'Error', 'Description' => 'INVALID_IP'
      else
        json Records.where(ipv6address: IPAddress(ip).to_s)
      end
    end
  end
end
