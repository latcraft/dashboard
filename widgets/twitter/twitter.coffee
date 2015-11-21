class Dashing.Twitter extends Dashing.Widget

  ready: ->
    @currentIndex = 0
    @tweetElem = $(@node).find('.tweet-container')
    @nextTweet()
    @startCarousel()

  onData: (data) ->
    @currentIndex = 0

  startCarousel: ->
    setInterval(@nextTweet, 10000)

  nextTweet: =>
    tweets = @get('tweets')
    if tweets
      @tweetElem.fadeOut =>
        @set 'visible_tweets', tweets.slice(@currentIndex, @currentIndex + 3).concat(tweets.slice(0, Math.max(0, @currentIndex + 3 - tweets.length)))
        @currentIndex = (@currentIndex + 3) % tweets.length
        @tweetElem.fadeIn()
