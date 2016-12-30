#!/usr/bin/env ruby

require 'dotenv'
require 'ipaddress'
require 'rubydns'
require 'sequel'

# Dotenv
# Load Environment Variables.
Dotenv.load

# Class: DNS
# The DNS Server Core
class DNS
  # Confiure Binding and upstream DNS
  def initialize
    @dnsbind = ENV['DNS_PORT'].empty? ? 5300 : ENV['DNS_PORT']
    @dnssuffix = ENV['DNS_SUFFIX'].empty? ? 'local' : ENV['DNS_SUFFIX']
    @upstreamdnsip1 = ENV['UPSTREAM_DNS_IP1'].empty? ? '208.67.222.222' : ENV['UPSTREAM_DNS_IP1']
    @upstreamdnsip2 = ENV['UPSTREAM_DNS_IP2'].empty? ? '208.67.220.220' : ENV['UPSTREAM_DNS_IP2']
    @database = Sequel.connect(ENV['DATABASE_URL'])
  end

  # The real server instance...
  def start
    records = @database[:records]
    dnssuffix = @dnssuffix
    esc_dnssuffix = Regexp.escape(@dnssuffix)
    dnsupstream = RubyDNS::Resolver.new([[:udp, @upstreamdnsip1, 53], [:tcp, @upstreamdnsip1, 53], [:udp, @upstreamdnsip2, 53], [:tcp, @upstreamdnsip2, 53]])
    RubyDNS.run_server(listen: [[:udp, '::', @dnsbind], [:tcp, '::', @dnsbind]], debug: false) do
      # Catch Localhost Request
      match(/localhost/, Resolv::DNS::Resource::IN::A) do |transaction|
        transaction.respond!('127.0.0.1')
      end

      # Catch Localhost Request, on IPv6
      match(/localhost/, Resolv::DNS::Resource::IN::AAAA) do |transaction|
        transaction.respond!('::1')
      end

      # This is used to match the DNS Suffix of the internal zone
      match(/(.+)\.#{esc_dnssuffix}/, Resolv::DNS::Resource::IN::A) do |transaction, match_data|
        answer = records.first(name: match_data[1])
        answer.nil? ? transaction.fail!(:NXDomain) : transaction.respond!(answer[:ipv4address])
      end

      match(/(.+)\.#{esc_dnssuffix}/, Resolv::DNS::Resource::IN::AAAA) do |transaction, match_data|
        answer = records.first(name: match_data[1])
        answer.nil? ? transaction.fail!(:NXDomain) : transaction.respond!(answer[:ipv6address])
      end

      # Handling PTR Record
      match(/(.+)\.in-addr.arpa/, Resolv::DNS::Resource::IN::PTR) do |transaction, match_data|
        realip = match_data[1].split('.').reverse.join('.')
        if IPAddress.valid_ipv4?(realip)
          answer = records.first(ipv4address: realip)
          answer.nil? ? transaction.passthrough!(dnsupstream) : transaction.respond!(Resolv::DNS::Name.create(answer[:name] + '.' + dnssuffix))
        else
          # Refusing inappropiate requests, inappropiate IPv6 requests also goes here.
          transaction.fail!(:Refused)
        end
      end

      # Handling IPv6 PTR Record
      match(/(.+)\.ip6.arpa/, Resolv::DNS::Resource::IN::PTR) do |transaction, match_data|
        incoming = match_data[1].split('.').reverse.join
        if incoming =~ /^[0-9a-fA-F]+$/
          realip6 = IPAddress::IPv6.parse_hex(match_data[1].split('.').reverse.join).to_s
          realip4 = (IPAddress::IPv6::Mapped.new(realip6).mapped? ? '::FFFF:' + IPAddress::IPv6::Mapped.new(realip6).ipv4.address : '').to_s
          answer = records.first(ipv6address: [realip6, realip4])
          answer.nil? ? transaction.passthrough!(dnsupstream) : transaction.respond!(Resolv::DNS::Name.create(answer[:name] + '.' + dnssuffix))
        else
          transaction.fail!(:Refused)
        end
      end

      # Default DNS handler, forward outside address to upstream DNS
      otherwise do |transaction|
        transaction.passthrough!(dnsupstream)
      end
    end
  end
end

dns = DNS.new
dns.start
