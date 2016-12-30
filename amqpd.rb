#!/usr/bin/env ruby

require 'dotenv'
require 'sequel'
require 'ipaddress'
require 'bunny'

# Dotenv
# Load Environment Variables from .env file
Dotenv.load

# Class: Rabbit
# A class to manage the DNS AMQP API
class Rabbit
  # initialize by define and start connection
  def initialize
    @connection = Bunny.new(ENV['AMQP_URI'] || 'amqp://localhost')
    @connection.start
    @channel = @connection.create_channel
    @actions = ['all', 'search.*', 'new', 'update', 'delete']
  end

  # Core
  def start
    topic = @channel.topic('dns')
    queue_in = @channel.queue('')
    @actions.each do |actions|
      queue_in.bind(topic, routing_key: actions)
    end

    puts ' [!] Waiting for messages. To exit press CTRL+C'
    begin
      queue_in.subscribe(block: true) do |delivery_info, properties, body|
        Thread.new { Processor.process(delivery_info.routing_key, body, properties.correlation_id) }
      end
    rescue Interrupt => _
      @channel.close
      @connection.close
    end
  end

  # Message Queue Publisher
  def publish(message, corr)
    @channel.default_exchange.publish(message, routing_key: queue_out.name, correlation_id: corr)
    puts ' [x] SENT @ #{corr}'
    @channel.close
    @connection.close
  end

  private

  def queue_out
    @channel.queue('out', durable: true)
  end
end

# Class: Processor
# The main work logic.
class Processor
  # Process the Stuff.
  def self.process(job_type, body, msg_id)
    connection = Sequel.connect(ENV['DATABASE_URL'])
    records = connection[:records]
    rabbit = Rabbit.new
    parsed = JSON.parse(body)
    puts ' [x] Task : ' + job_type
    case job_type
    when 'all'
      msg = records.all
    when 'search.name'
      if !(parsed['payload'] =~ /^[a-zA-Z0-9][a-zA-Z0-9.-]{1,30}[a-zA-Z0-9]$/)
        # Pre-check: is this domain right?
        # http://stackoverflow.com/questions/10306690/domain-name-validation-with-regex

        msg = { message: 'Invalid Domain', description: 'Domain rule incorrect.' }
      else
        msg = records.where(name: name)
      end
    when 'search.ip4'
      if !IPAddress.valid_ipv4?(parsed['payload'])
        msg = { message: 'Invalid Address', description: 'Not a valid IP address.' }
      else
        msg = records.where(ipv4address: parsed['payload'])
      end
    when 'search.ip6'
      if !IPAddress.valid_ipv6?(ip)
        msg = { message: 'Invalid Address', description: 'Not a valid IP address.' }
      else
        msg = records.where(ipv6address: IPAddress(parsed['payload']).to_s)
      end
    when 'search.id'
      msg = records.first(id: parsed['payload'])
    when 'update'
      payload = parsed['payload']

      if !payload.key?('id')
        msg = { message: 'Invalid Request', description: 'Specify ID.' }
      elsif (payload.key?('id') && payload['id'].empty?) || (payload.key?('ipv4address') && payload['ipv4address'].empty?) || (payload.key?('ipv6address') && payload['ipv6address'].empty?) || (payload.key?('name') && payload['name'].empty?)
        msg = { message: 'Invalid Request', description: 'Empty Fields discovered.' }
      elsif payload.key?('name') && !(payload['name'] =~ /^[a-zA-Z0-9][a-zA-Z0-9.-]{1,30}[a-zA-Z0-9]$/)
        msg = { message: 'Invalid Domain', description: 'Domain rule incorrect.' }
      elsif (payload.key?('ipv4address') && !IPAddress.valid_ipv4?(payload['ipv4address'])) || (payload.key?('ipv6address') && !IPAddress.valid_ipv6?(payload['ipv6address']))
        msg = { message: 'Invalid Address', description: 'Not a valid IP address.' }
      else
        check_result = records.first(id: payload['id'])

        if check_result.empty?
          msg = { message: 'Not Found', description: 'The requested entry not found.' }
        else
          name = payload.key?('name') ? payload['name'] : check_result['name']
          ipv4 = payload.key?('ipv4address') ? payload['ipv4address'] : check_result['ipv4address']
          ipv6 = payload.key?('ipv6address') ? IPAddress(payload['ipv6address']).to_s : check_result['ipv6address']
          json check_result.update(name: name, ipv4address: ipv4, ipv6address: ipv6)
        end
      end
    when 'delete'
      records.where(id: parsed['payload']).delete
      msg = { message: 'Done', description: 'Record has been deleted.' }
    else
      msg = { message: 'Ouch', description: 'Job is not defined.' }
    end
    rabbit.publish(JSON.generate(msg), msg_id)
  end
end

rabbit = Rabbit.new
rabbit.start
