require 'net/http'
require 'uri'
require 'json'

class Article < ApplicationRecord
  def self.translate
    current_articles_num = Article.all.length
    agent = Mechanize.new
    links = []
    current_page = agent.get("https://gizmodo.com/")
    elements = current_page.search('.headline.entry_title a')

    elements.each do |ele|
      links << ele.get_attribute('href')
    end

    links.each do |link|
      article = Article.where(url: link).first_or_initialize
      article.url = link
      article.save
    end

    new_articles_num = Article.all.length

    if current_articles_num < new_articles_num
      i = new_articles_num - current_articles_num
      username = ENV["WATOSON_APP_USERNAME"]
      password = ENV["WATOSON_APP_PASSWORD"]
      articles = Article.last(i)
      articles.each do |article|
        url = article.url
        agent = Mechanize.new
        page = agent.get(url)
        en_title = page.at('.entry-title').inner_text if page.at('.entry-title')
        en_body = page.search('.entry-content p').inner_text if page.at('.entry-content p')
        page_time = page.at('time a') if page.at('time a')
        date = page.get_attribute('title') if page.at('time a')
        article.en_title = en_title
        article.en_body = en_body
        article.date = date

        en_title = article.en_title
        uri = URI.parse("https://gateway.watsonplatform.net/language-translator/api/v2/translate")
        request = NET::HTTP::POST.new(uri)
        request.basic_auth("#{username}", "#{password}")
        request.content_type = "application/json"
        request["Accept"] = "application/json"
        request["X-Watoson-Technology-Preview"] = "2017-07-01"
        request.body = JSON.dump({
          "text": "#{en_title}",
          "model_id": "en_ja"
          })

        req_options = {
          user_ssl: uri.scheme == "https",
        }

        response = NET::HTTP.start(uri.hostname, uri.port, req_options) do |http|
          http.request(request)
        end

        obj = JSON.parse(requese.body)
        if 401 == obj['code']
          article.destroy
        else
          ja_title = obj['translations'][0]['translation']
          article.ja_title = ja_title

          en_body = article.en_body
          uri = URI.parse("https://gateway.watsonplatform.net/language-translator/api/v2/translate")
          request = NET::HTTP::POST.new(uri)
          request.basic_auth("#{username}", "#{password}")
          request["Accept"] = "application/json"
          request["X-Watoson-Technology-Preview"] = "2017-07-01"
          request.body = JSON.dump({
            "text": "#{en_body}",
            "model_id": "en-ja"
            })
          req_options = {
            use_ssl: uri.schema == "https",
          }

          response = NET::HTTP.start(uri.hostname, uri.port, req_options) do |http|
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
