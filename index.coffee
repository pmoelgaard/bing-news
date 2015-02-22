util = require 'util'
request = require 'request'
extend = require 'extend'
Loki = require 'lokijs'
FeedParser = require('feedparser')
EventEmitter = require('events').EventEmitter;

class NewsProvider

  @DATA: 'news.data'
  @ERROR: 'news.error'
  @ATOM: 'atom'
  @RSS: 'rss'

  constructor: (options = {}) ->

    options = extend {}, options, {
      cacheFileName: 'bing-news.json'
    }

    this.cacheProvider = new Loki(options.cacheFileName)


  stream: (track, callback) ->

    class NewsStream

      util.inherits(NewsStream, EventEmitter);

      constructor: (context, track) ->
        this.context = context
        this.track = track
        this.options = extend({}, context.options,
          pollInterval: 1000 * 60 * 15
          protocol: 'https'
          host: 'www.bing.com'
          service: 'news/search'
          params:
            format: NewsProvider.RSS
        )
        this.cache = context.cacheProvider.addCollection(this.options.host)
        ### Every 1 min ###
        this.connectTrigger = setInterval(this.connect, this.options.pollInterval)
        ### Trigger at start ###
        this.connect()


      connect: () =>

        feedParser = new FeedParser()

        feedParser.on 'readable', () =>
          while( item = feedParser.read() )
            existingItems = this.cache.find( { guid:item.guid } )
            if existingItems.length is 0
              this.cache.insert(item)
              this.onData(item)

        feedParser.on 'error', (error) =>
          this.onError(error)

        args =
          qs: extend {}, this.options.params, { q: this.track }
          uri: "#{this.options.protocol}://#{this.options.host}/#{this.options.service}"

        feed = request(args)
        feed.on 'response', () =>
          feed.pipe(feedParser);


      disconnect: () =>
        clearInterval(this.checkTrigger)


      onData: (data) =>
        this.emit(NewsProvider.DATA, data)

      onError: (error) =>
        this.emit(NewsProvider.ERROR, error)


    stream = new NewsStream(this, track)
    callback(stream)


    return


module.exports = NewsProvider