require 'net/http'
require 'uri'
require 'json'

class Article < ActiveRecord::Base
  def self.translate
    # 現在の記事数を取得
    current_articles_num = Article.all.length
    # 翻訳する記事のURLを取得
    agent = Mechanize.new
    links = []
    current_page = agent.get("https://gizmodo.com/")
    elements = current_page.search('.headline.entry-title a')

    elements.each do |ele|
      links << ele.get_attribute('href')
    end

    links.each do |link|
      article = Article.where(url: link).first_or_initialize
      article.url = link
      article.save
    end
    # スクレイピング後の記事数を取得
    new_articles_num = Article.all.length
    # 差分があればテーブルのデータを保存
    if current_articles_num < new_articles_num
      i = new_articles_num - current_articles_num
      username = ENV["WATSON_APP_USERNAME"]
      password = ENV["WATSON_APP_PASSWORD"]
    # 差分のレコードを取得
      articles = Article.last(i)
    # 翻訳する記事のタイトルとボディを取得し保存
      articles.each do |article|
        url = article.url
        agent = Mechanize.new
        page = agent.get(url)
        en_title = page.at('.entry-title').inner_text if page.at('.entry-title')
        en_body = page.search('.entry-content p').inner_text if page.at('.entry-content p')
        page_time = page.at('time a') if page.at('time a')
        date  = page_time.get_attribute('title') if page.at('time a')
        article.en_title = en_title
        article.en_body = en_body
        article.date = date

        # タイトルを翻訳し保存
        en_title = article.en_title
        uri = URI.parse("https://gateway.watsonplatform.net/language-translator/api/v2/translate")
        request = Net::HTTP::Post.new(uri)
        request.basic_auth("#{username}", "#{password}")
        request.content_type = "application/json"
        request["Accept"] = "application/json"
        request["X-Watson-Technology-Preview"] = "2017-07-01"
        request.body = JSON.dump({
          "text": "#{en_title}",
          "model_id": "en-ja"
        })

        req_options = {
          use_ssl: uri.scheme == "https",
        }

        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
          http.request(request)
        end

        obj = JSON.parse(response.body)
        if 401 == obj['code']
          article.destroy
        else
          ja_title = obj['translations'][0]['translation']
          article.ja_title = ja_title

          # ボディを翻訳し保存
          en_body = article.en_body
          uri = URI.parse("https://gateway.watsonplatform.net/language-translator/api/v2/translate")
          request = Net::HTTP::Post.new(uri)
          request.basic_auth("#{username}", "#{password}")
          request["Accept"] = "application/json"
          request["X-Watson-Technology-Preview"] = "2017-07-01"
          request.body = JSON.dump({
            "text": "#{en_body}",
            "model_id": "en-ja"
          })
          req_options = {
            use_ssl: uri.scheme == "https",
          }

          response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
            http.request(request)
          end

          obj = JSON.parse(response.body)
          ja_body = obj['translations'][0]['translation']
          article.ja_body = ja_body
          article.save
        end
      end
    end
  end
end
