require 'sinatra/base'
require 'haml'
require 'builder'
require 'rexml/document'
require 'digest/md5'
require 'digest/sha1'
require 'date'
require 'time'

module Atomos
  class NotFound < Sinatra::NotFound; end
  class Application < Sinatra::Base

    # overrides Sinatra::Base's!
    def self.compile(path)
      keys = []
      if path.respond_to? :to_str
        special_chars = %w{. + ( )}
        patterns = {'year' => /\d{4}/, 'month' => /\d{2}/, 'day' => /\d{2}/}
        pattern =
          path.to_str.gsub(/(:(\w+)|[\*#{special_chars.join}])/) do |match|
            case match
            when "*"
              keys << 'splat'
              "(.*?)"
            when *special_chars
              Regexp.escape(match)
            else
              keys << $2
              "(#{patterns[$2] || '[^/?&#]+'})"
            end
          end
        [/^#{pattern}$/, keys]
      elsif path.respond_to?(:keys) && path.respond_to?(:match)
        [path, path.keys]
      elsif path.respond_to? :match
        [path, keys]
      else
        raise TypeError, path
      end
    end

    def render(engine, data, options={}, locals={}, &block)
      @page_id ||= data.to_s if data.is_a? Symbol
      super
    end

    # default settings
    configure do
      set :root,   File.expand_path('../..', File.dirname(__FILE__))
      set :static, true
      set :url,    ''
      set :title,  'Atomos Blog'
      set :author, 'Anonymous'
      set :username, 'admin'
      set :password, 'password'
      set :per_page, 10
      set :timezone, nil
      set :haml, :escape_html => true, :ugly => false, :attr_wrapper => '"'
    end

    before do
      @config = settings
      @title  = settings.title.dup
    end

    get '/' do
      @page = 1
      @pages = (Entry.count + @config.per_page - 1) / @config.per_page
      @entries = Entry.all(:limit => @config.per_page)
      haml :home
    end

    get '/page/:page' do
      @page = params[:page].to_i
      @pages = (Entry.count + @config.per_page - 1) / @config.per_page
      @entries = Entry.all(:offset => (@page-1) * @config.per_page, :limit => @config.per_page)
      raise NotFound if @entries.empty?
      haml :home
    end

    get '/tag/:tag' do
      @entries = Entry.tagged(params[:tag])
      raise NotFound if @entries.empty?
      @title.insert(0, params[:tag] + ' | ')
      haml :list
    end

    get '/:year/' do
      @entries = Entry.circa(params[:year])
      raise NotFound if @entries.empty?
      @title.insert(0, @entries.first.published.strftime('%Y | '))
      haml :list
    end

    get '/:year/:month/' do
      @entries = Entry.circa(params[:year], params[:month])
      raise NotFound if @entries.empty?
      @title.insert(0, @entries.first.published.strftime('%Y %B | '))
      haml :list
    end

    get '/:year/:month/:day/' do
      @entries = Entry.circa(params[:year], params[:month], params[:day])
      raise NotFound if @entries.empty?
      @title.insert(0, @entries.first.published.strftime('%Y %B %d | ').sub(/ 0/, ' '))
      haml :list
    end

    get '/:year/:month/:day/:slug' do
      date = Entry.circa(params[:year], params[:month], params[:day])
      @entry = date.first(:slug => params[:slug]) or raise NotFound
      @title.insert(0, @entry.title + ' | ')
      haml :entry
    end

    get '/service' do
      content_type 'application/atomsvc+xml', :charset => 'utf-8'
      builder :service, :layout => false
    end

    get '/atom/' do
      @entries = Entry.all(:order => [:updated.desc], :limit => 10)
      etag Digest::MD5.hexdigest(request.url + @entries.map {|e| e.updated }.join)
      content_type 'application/atom+xml', :charset => 'utf-8'
      builder :feed, :layout => false
    end

    post '/atom/' do
      authorize!
      @entry = Entry.new(parse_xml(request.body.read))
      slug = request.env['HTTP_SLUG'].to_s
      slug = @entry.title.downcase.scan(/[a-z0-9]+/).join('-') if slug.empty?
      slug = @entry.published.strftime('%H%M') if slug.empty?
      @entry.slug = slug
      @entry.save or halt 400, 'Bad Reqest'
      status 201
      content_type 'application/atom+xml;type=entry', :charset => 'utf-8'
      response['Location'] = @entry.url
      builder :entry, :layout => false
    end

    get '/atom/:year/:month/:day/:slug' do
      authorize!
      date = Entry.circa(params[:year], params[:month], params[:day])
      @entry = date.first(:slug => params[:slug]) or raise NotFound
      content_type 'application/atom+xml;type=entry', :charset => 'utf-8'
      etag Digest::MD5.hexdigest(request.url + @entry.updated.to_s)
      builder :entry, :layout => false
    end

    put '/atom/:year/:month/:day/:slug' do
      authorize!
      date = Entry.circa(params[:year], params[:month], params[:day])
      @entry = date.first(:slug => params[:slug]) or raise NotFound
      @entry.update(parse_xml(request.body.read)) or halt 400, 'Bad Reqest'
      content_type 'application/atom+xml;type=entry', :charset => 'utf-8'
      builder :entry, :layout => false
    end

    delete '/atom/:year/:month/:day/:slug' do
      authorize!
      date = Entry.circa(params[:year], params[:month], params[:day])
      @entry = date.first(:slug => params[:slug]) or raise NotFound
      @entry.destroy
      ''
    end

    error 404 do
      @message = "sorry, nothig found for <code>#{request.env['REQUEST_URI']}</code>."
      content_type 'text/html', :charset => 'utf-8'
      haml :error
    end

    helpers do
      def authorize
        case request.env['HTTP_X_WSSE']
        when /\AUsernameToken\s*/
          header = {}
          $'.scan(/\w+\=(?:"[^"]+"|[^,]+)/) do |param|
            k, v = param.split('=', 2)
            header[k] = (/\A"(.*)"\Z/ =~ v) ? $1 : v
          end

          if header['Username'] == @config.username &&
             (Time.now - Time.iso8601(header['Created'])) < 60

            digest = Digest::SHA1.digest([
              header['Nonce'].unpack('m')[0],
              header['Created'],
              @config.password
            ].join)
            digest == header['PasswordDigest'].unpack('m')[0]
          end
        end
      rescue
      end

      def authorize!
        return if @authorized ||= authorize
        halt 401, 'Authorization Required'
      end

      def parse_xml(xml)
        now = DateTime.now
        if @config.timezone
          now = now.new_offset(@config.timezone.to_f / 1440)
        end

        root = REXML::Document.new(xml).root
        root.elements.to_a.inject({'updated' => now}) do |entry, element|
          case element.name
          when 'title', 'content'
            entry[element.name] = element.text
          when 'updated', 'published'
            entry[element.name] = DateTime.strptime(element.text)
          when 'category'
            (entry['tags'] ||= []) << element.attributes['term']
          end
          entry
        end
      rescue
        halt 400, 'Bad Reqest'
      end
    end

  end
end
