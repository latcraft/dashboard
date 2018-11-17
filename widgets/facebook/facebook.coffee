class Dashing.Facebook extends Dashing.Widget

  ready: ->
    @currentIndex = 0
    @ratingElem = $(@node).find('.fb-container')
    @nextRating()
    @startCarousel()

  onData: (data) ->
    @currentIndex = 0

  startCarousel: ->
    setInterval(@nextRating, 10000)

  nextRating: =>
    ratings = @get('ratings')
    console.log(ratings)
    if ratings
      @ratingElem.fadeOut =>
        currentRating = ratings[@currentIndex]
        @currentIndex = (@currentIndex + 1) % ratings.length
        @set 'facebookRating', currentRating
        @ratingElem.fadeIn()
