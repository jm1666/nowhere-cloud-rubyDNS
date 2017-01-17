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
  end

  # Core
  def start
    puts ' [!] Waiting for messages. To exit press CTRL+C'
    begin
      queue_in.subscribe(block: true) do |_, properties, body|
        Thread.new { Processor.process(body, properties.correlation_id) }
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

  # Set up the ingoing queue
  def queue_in
    @channel.queue('dns', durable: true)
  end

  # Set up the outgoing queue
  def queue_out
    @channel.queue('out', durable: true)
  end
end

# Class: Processor
# The main work logic.
class Processor
  # Process the Stuff.
  def self.process(body, msg_id)
    connection = Sequel.connect(ENV['DATABASE_URL'])
    records = connection[:records]
    rabbit = Rabbit.new
    parsed = JSON.parse(body)
    payload = parsed['payload']
    puts ' [x] Task : ' + parsed['task']
    msg = {
      payload: nil,
      seq: parsed['id'],
      taskid: parsed['uuid']
    }
    msg['payload'] = case parsed['task']
                     when 'all'
                       records.all
                     when 'search.name'
                       if !(payload =~ /^[a-zA-Z0-9][a-zA-Z0-9.-]{1,30}[a-zA-Z0-9]$/)
                         # Pre-check: is this domain right?
                         # http://stackoverflow.com/questions/10306690/domain-name-validation-with-regex

                         { message: 'Invalid Domain', description: 'Domain rule incorrect.' }
                       else
                         records.where(name: name)
                       end
                     when 'search.ip4'
                       if !IPAddress.valid_ipv4?(payload)
                         { message: 'Invalid Address', description: 'Not a valid IP address.' }
                       else
                         records.where(ipv4address: payload)
                       end
                     when 'search.ip6'
                       if !IPAddress.valid_ipv6?(payload)
                         { message: 'Invalid Address', description: 'Not a valid IP address.' }
                       else
                         records.where(ipv6address: IPAddress(payload).to_s)
                       end
                     when 'search.id'
                       records.first(id: payload)
                     when 'new'
                       if !payload.key?('type') || !payload.key?('name')
                         # Pre-check: are the fields here?

                         { message: 'Invalid Request', description: 'The required fields are not found.' }
                       elsif (payload.key?('type') && payload['type'].empty?) \
                          || (payload.key?('name') && payload['name'].empty?) \
                          || (payload.key?('ipv4address') && payload['ipv4address'].empty?) \
                          || (payload.key?('ipv6address') && payload['ipv6address'].empty?) \
                          || (payload.key?('cname') && payload['cname'].empty?)
                         # Pre-check: No Empty Fields

                         { message: 'Invalid Request', description: 'Empty Fields discovered.' }
                       elsif !(payload['name'] =~ /^[a-zA-Z0-9][a-zA-Z0-9.-]{1,30}[a-zA-Z0-9]$/)
                         # Pre-check: is this domain right?
                         # http://stackoverflow.com/questions/10306690/domain-name-validation-with-regex

                         { message: 'Invalid Domain', description: 'Domain rule incorrect.' }
                       elsif !IPAddress.valid_ipv4?(payload['ipv4address']) \
                          || !IPAddress.valid_ipv6?(payload['ipv6address'])
                         # Pre-check: is the IP valid?

                         { message: 'Invalid Address', description: 'Not a valid IP address.' }
                       else
                         return_id = Records.insert(type: payload['type'].to_s,\
                                                    name: payload['name'].to_s,\
                                                    ipv4address: payload['ipv4address'].to_s,\
                                                    ipv6address: IPAddress(payload['ipv6address']).to_s,\
                                                    cname: payload['cname'].to_s)
                         Records.first(id: return_id)
                       end
                     when 'update'
                       if payload.key?('type')
                         { message: 'Invalid Request', description: 'Changing the type of the record is not allowed.' }
                       elsif !payload.key?('id')
                         { message: 'Invalid Request', description: 'Specify ID.' }
                       elsif (payload.key?('name') && payload['name'].empty?) \
                          || (payload.key?('ipv4address') && payload['ipv4address'].empty?) \
                          || (payload.key?('ipv6address') && payload['ipv6address'].empty?) \
                          || (payload.key?('cname') && payload['cname'].empty?)

                         { message: 'Invalid Request', description: 'Empty Fields discovered.' }
                       elsif payload.key?('name') && !(payload['name'] =~ /^[a-zA-Z0-9][a-zA-Z0-9.-]{1,30}[a-zA-Z0-9]$/)
                         { message: 'Invalid Domain', description: 'Domain rule incorrect.' }
                       elsif (payload.key?('ipv4address') && !IPAddress.valid_ipv4?(payload['ipv4address'])) \
                          || (payload.key?('ipv6address') && !IPAddress.valid_ipv6?(payload['ipv6address']))

                         { message: 'Invalid Address', description: 'Not a valid IP address.' }
                       else
                         check_result = records.first(id: payload['id'])

                         if check_result.empty?
                           { message: 'Not Found', description: 'The requested entry not found.' }
                         else
                           name = payload.key?('name') ? payload['name'] : check_result['name']
                           ipv4 = payload.key?('ipv4address') ? payload['ipv4address'] : check_result['ipv4address']
                           ipv6 = payload.key?('ipv6address') ? IPAddress(payload['ipv6address']).to_s : check_result['ipv6address']
                           cname = payload.key?('cname') ? IPAddress(payload['cname']).to_s : check_result['cname']
                           check_result.update(name: name, ipv4address: ipv4, ipv6address: ipv6, cname: cname)
                         end
                       end
                     when 'delete'
                       records.where(id: parsed['payload']).delete
                       { message: 'Done', description: 'Record has been deleted.' }
                     else
                       { message: 'Ouch', description: 'Job is not defined.' }
                     end
    rabbit.publish(JSON.generate(msg), msg_id)
  end
end

rabbit = Rabbit.new
rabbit.start
