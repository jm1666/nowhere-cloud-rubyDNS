## Proof of Concept: A DNS Server which can be updated via API.
## 概念実証：DNSサーバ
## 概念驗證：可動態更新的DNS Server

[ ![Codeship Status for jm1666/nowhere-cloud-rubyDNS](https://app.codeship.com/projects/ff2b3060-adba-0134-3cb2-36e7a5ec89be/status?branch=master)](https://app.codeship.com/projects/192557)

This Repository hosts a mini DNS Server, powered by Ruby + MySQL.

このリポジトリは、Ruby言語で書かれ、RDBMSによって駆動されるDNSサーバが含まれています。

此存儲庫包含一個使用Ruby編寫及使用RDBMS作爲數據庫的迷你DNS Server。

---

### Requirements // システム必要条件 // 系統要求
* Ruby >= 2.3.0 w/ Bundler
* Any RDBMS supported by [Sequel ORM](http://sequel.jeremyevans.net/)
* Linux (M$ Windows から残念です、申し訳ございません) (不支援 M$ Windows)

### How To use? // 使い方 (英語のみ) // 食用方法 (English Only)
1. Configure your decided RDBMS Driver in `Gemfile`
  * MySQL should use `mysql2`
2. `$ bundler update`
3. `$ rake config:create`
4. Configure `DATABASE_URL` and various settings in `.env`
3. `$ rake db:migrate`
4. `$ ruby dnsd.rb`
5. Open a new terminal, `$ rackup` to run the API Server. Default on port `9292`, append `-p 1234` to use port `1234`

![Screenshot](screenshot.png?raw=true)
### Acknowledgements
* Developers of [Ruby Sinatra](http://www.sinatrarb.com/)
* [ioquatix](https://github.com/ioquatix/), who develops [RubyDNS](https://github.com/ioquatix/rubydns)

### Documentations
* API
  * Basically, send this payload to `POST /records/new` to create
  ```json
  {
    "type": "A",
    "name": "hostname",
    "ipv4address": "192.0.2.4",
    "ipv6address": "::FFFF:192.0.2.4"
  }
  ```
  * Get all records `GET /records`
  * Update records `PATCH /records/n`, where `n` is record id, No empty records, just leave the field you wanna update
  ```json
  {
    "name": "hostname",
    "ipv4address": "192.0.2.4",
    "ipv6address": "::FFFF:192.0.2.4"
  }
  ```
  * Delete records `DELETE /records/n`, where `n` is record id
  * Search by hostname `GET /search/name/hostname`, where `abc` is hostname
  * Search by IPv4 `GET /search/ip4/192.0.2.4`, where `192.0.2.4` is the recorded IPv4 Address
  * Search by IPv6 `GET /search/ip6/::FFFF:192.0.2.4`, where `::FFFF:192.0.2.4` is the recorded IPv6 Address
* DNS
  * Normal lookup `dig @localhost -p 5300 hostname.yourdesiredzone.local`
  * Reverse lookup `dig @localhost -p 5300 -x 192.0.2.4` or `dig @localhost -p 5300 -x ::FFFF:192.0.2.4`

### Todo
* Implement the API via AMQP, but sorry, no documentations will offered on that version because that is intended for

### Footnote
* All Chinese (Traditional Script) and Japanese descriptions in this document are Machine-Translated Results.
While Japanese results are interpreted afterwards, quality of Chinese descriptions are not assured.
