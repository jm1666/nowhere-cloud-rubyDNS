## Proof of Concept: A DNS Server which can be updated via API.
## 概念実証：DNSサーバの設計
## 概念驗證：可動態更新的DNS Server設計

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
5. Open a new terminal, `$ rackup -p PORT`, Where PORT is any port number you like

![Screenshot](screenshot.png?raw=true)

## License
[Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-nc-sa/4.0/)

## Acknowledgements
* Developers of [Ruby Sinatra](http://www.sinatrarb.com/)
* [ioquatix](https://github.com/ioquatix/), who develops [RubyDNS](https://github.com/ioquatix/rubydns)

## Documentations
* B

### Footnote
* All Chinese (Traditional Script) and Japanese descriptions in this document are Machine-Translated Results.
While Japanese results are interpreted afterwards, quality of Chinese descriptions are not assured.
