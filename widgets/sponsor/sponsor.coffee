class Dashing.Sponsor extends Dashing.Widget

  ready: ->
    @sponsors = [ 'amazon', '4finance', 'askfm', 'cloudreach' ]
    @currentIndex = 0
    @sponsorElem = $(@node).find('.sponsor-container')
    @nextSponsor()
    @startCarousel()

  startCarousel: ->
    setInterval(@nextSponsor, 8000)

  nextSponsor: =>
    @sponsorElem.fadeOut =>
      @currentIndex = (@currentIndex + 1) % @sponsors.length
      @set 'current_sponsor', @sponsors[@currentIndex]
      @sponsorElem.fadeIn()
