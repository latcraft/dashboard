class Dashing.Backer extends Dashing.Widget

  ready: ->
    container = $(@node).parent()
    @backers = container.data("backers").split ' '
    @currentIndex = 0
    @backerElem = $(@node).find('.backer-container')
    @nextBacker()
    @startCarousel()

  startCarousel: ->
    setInterval(@nextBacker, 8000)

  nextBacker: =>
    @backerElem.fadeOut =>
      @currentIndex = (@currentIndex + 1) % @backers.length
      @set 'current_backer', @backers[@currentIndex]
      @backerElem.fadeIn()
