#!/usr/bin/env ruby

require 'dotenv'
require 'ipaddress'
require 'rubydns'
require 'sequel'

# Dotenv
# Load Environment Variables.
Dotenv.load

# Class: Core
# The DNS Server Core
class Core
  # Used to reduce code redundancy
  IN = Resolv::DNS::Resource::IN
  Name = Resolv::DNS::Name

  # These are meant to be useless to put at initialize, so I moved them away
  DNS_SUFFIX = ENV['DNS_SUFFIX'].empty? ? 'local' : ENV['DNS_SUFFIX']
  DNS_BIND   = ENV['DNS_PORT'].empty? ? 5300 : ENV['DNS_PORT']
  UPSTREAM_1 = ENV['UPSTREAM_DNS_IP1'].empty? ? '208.67.222.222' : ENV['UPSTREAM_DNS_IP1']
  UPSTREAM_2 = ENV['UPSTREAM_DNS_IP2'].empty? ? '208.67.220.220' : ENV['UPSTREAM_DNS_IP2']
  TTL_VALUE  = (ENV['DNS_TTL'].empty? ? 10 : ENV['DNS_TTL']).to_i

  # Confiure Binding and upstream DNS
  def initialize
    @database = Sequel.connect(ENV['DATABASE_URL'])
  end

  # The real server instance...
  def start
    # These "Just copy assignment" is not preventable ...

    records = @database[:records]
    esc_dnssuffix = Regexp.escape(DNS_SUFFIX)
    upstreamdns = RubyDNS::Resolver.new([[:udp, UPSTREAM_1, 53], [:tcp, UPSTREAM_1, 53], [:udp, UPSTREAM_2, 53], [:tcp, UPSTREAM_2, 53]])
    RubyDNS.run_server(listen: [[:udp, '::', DNS_BIND], [:tcp, '::', DNS_BIND]]) do
      # Catch Localhost Request
      match(/localhost/, IN::A) do |transaction|
        transaction.respond!('127.0.0.1')
      end

      # Catch Localhost Request, on IPv6
      match(/localhost/, IN::AAAA) do |transaction|
        transaction.respond!('::1')
      end

      # This is used to match the DNS Suffix of the internal zone
      match(/(.+)\.#{esc_dnssuffix}/, IN::A) do |transaction, match_data|
        answers = records.where(name: match_data[1], type: 'A')
        if answers.nil? || answers.empty?
          transaction.fail!(:NXDomain)
        else
          answers.each do |answer|
            transaction.respond!(answer[:ipv4address], ttl: TTL_VALUE)
          end
        end
      end

      match(/(.+)\.#{esc_dnssuffix}/, IN::AAAA) do |transaction, match_data|
        answers = records.where(name: match_data[1], type: 'A')
        if answers.nil? || answers.empty?
          transaction.fail!(:NXDomain)
        else
          answers.each do |answer|
            transaction.respond!(answer[:ipv6address], ttl: TTL_VALUE)
          end
        end
      end

      match(/(.+)\.#{esc_dnssuffix}/, IN::CNAME) do |transaction, match_data|
        answers = records.first(name: match_data[1], type: 'CNAME')
        if answers.nil? || answers.empty?
          transaction.fail!(:NXDomain)
        else
          transaction.respond!(answer[:cname], ttl: TTL_VALUE)
        end
      end

      match(/(.+)\.#{esc_dnssuffix}/, IN::MX) do |transaction, match_data|
        answers = records.where(name: match_data[1], type: 'MX')
        if answers.nil? || answers.empty?
          transaction.fail!(:NXDomain)
        else
          answers.each do |answer|
            transaction.respond!(answer[:cname], ttl: TTL_VALUE)
          end
        end
      end

      # Handling PTR Record
      match(/(.+)\.in-addr.arpa/, IN::PTR) do |transaction, match_data|
        realip = match_data[1].split('.').reverse.join('.')
        if IPAddress.valid_ipv4?(realip)
          answers = records.where(ipv4address: realip)
          if answers.nil? || answers.empty?
            transaction.passthrough!(upstreamdns)
          else
            answers.each do |answer|
              transaction.respond!(Name.create(answer[:name] + '.' + DNS_SUFFIX), ttl: TTL_VALUE)
            end
          end
        else
          # Refusing inappropiate requests, inappropiate IPv6 requests also goes here.
          transaction.fail!(:Refused)
        end
      end

      # Handling IPv6 PTR Record
      match(/(.+)\.ip6.arpa/, IN::PTR) do |transaction, match_data|
        incoming = match_data[1].split('.').reverse.join
        if incoming =~ /^[0-9a-fA-F]+$/
          realip6 = IPAddress::IPv6.parse_hex(incoming).to_s
          realip4 = (IPAddress::IPv6::Mapped.new(realip6).mapped? ? '::FFFF:' + IPAddress::IPv6::Mapped.new(realip6).ipv4.address : '').to_s
          answers = records.where(ipv6address: [realip6, realip4])
          if answers.nil? || answers.empty?
            transaction.passthrough!(upstreamdns)
          else
            answers.each do |answer|
              transaction.respond!(Name.create(answer[:name] + '.' + DNS_SUFFIX), ttl: TTL_VALUE)
            end
          end
        else
          transaction.fail!(:Refused)
        end
      end

      # Default DNS handler, forward outside address to upstream DNS
      otherwise do |transaction|
        transaction.passthrough!(upstreamdns)
      end
    end
  end
end

dns = Core.new
dns.start
