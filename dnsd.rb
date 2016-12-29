#!/usr/bin/env ruby

require "dotenv"
require "ipaddress"
require "rubydns"
require "sequel"

# Dotenv
# Load Environment Variables.
Dotenv.load

# Class: DNS
# The DNS Server Core
class DNS
  # Confiure Binding and upstream DNS
  def initialize
    @dnsbind = ENV["DNS_PORT"].empty? ? 5300 : ENV["DNS_PORT"]
    @dnssuffix = ENV["DNS_SUFFIX"].empty? ? "local" : ENV["DNS_SUFFIX"]
    @upstreamdnsip1 = ENV["UPSTREAM_DNS_IP1"].empty? ? "208.67.222.222" : ENV["UPSTREAM_DNS_IP1"]
    @upstreamdnsip2 = ENV["UPSTREAM_DNS_IP2"].empty? ? "208.67.220.220" : ENV["UPSTREAM_DNS_IP2"]
    @database = Sequel.connect(ENV["DATABASE_URL"])
  end

  # The real server instance...
  def start
    database = @database[:records]
    dnssuffix = @dnssuffix
    esc_dnssuffix = Regexp.escape(@dnssuffix)
    dnsupstream = RubyDNS::Resolver.new([[:udp, @upstreamdnsip1, 53], [:tcp, @upstreamdnsip1, 53], [:udp, @upstreamdnsip2, 53], [:tcp, @upstreamdnsip2, 53]])
    RubyDNS.run_server(listen: [[:udp, "::", @dnsbind], [:tcp, "::", @dnsbind]], debug: false) do
      # Catch Localhost Request
      match(/localhost/, Resolv::DNS::Resource::IN::A) do |transaction|
        transaction.respond!("127.0.0.1")
      end

      # Catch Localhost Request, on IPv6
      match(/localhost/, Resolv::DNS::Resource::IN::AAAA) do |transaction|
        transaction.respond!("::1")
      end

      # This is used to match the DNS Suffix of the internal zone
      match(/(.+)\.#{esc_dnssuffix}/, Resolv::DNS::Resource::IN::A) do |transaction, match_data|
        answer = database.first(name: match_data[1])
        answer.nil? ? transaction.fail!(:NXDomain) : transaction.respond!(answer[:ipv4address])
      end

      # Psuedo-iPv6 Support using Hybrid Address
      match(/(.+)\.#{esc_dnssuffix}/, Resolv::DNS::Resource::IN::AAAA) do |transaction, match_data|
        answer = database.first(name: match_data[1])
        answer.nil? ? transaction.fail!(:NXDomain) : transaction.respond!("::FFFF:" + answer[:ipv4address])
      end

      # Handling PTR Record
      match(/(.+)\.in-addr.arpa/, Resolv::DNS::Resource::IN::PTR) do |transaction, match_data|
        if IPAddress.valid_ipv4?(match_data[1])
          # Extract the IPv4 Address and reverse it back to normal ones.
          realip_octet = Array.new(4)
          realip_octet[0] = match_data[1].split(".")[3]
          realip_octet[1] = match_data[1].split(".")[2]
          realip_octet[2] = match_data[1].split(".")[1]
          realip_octet[3] = match_data[1].split(".")[0]
          answer = database.first(ipv4address: realip_octet.join("."))
          answer_name = answer[:name] + "." + dnssuffix
          answer.nil? ? transaction.passthrough!(dnsupstream) : transaction.respond!(Resolv::DNS::Name.create(answer_name))
        else
          # Refusing inappropiate requests
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
Thread.start { dns.start }.join
