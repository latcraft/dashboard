class Dashing.Banner extends Dashing.Widget

  ready: ->
    container = $(@node).parent()
    @banners = container.data("banners").split ' '
    @currentIndex = 0
    @bannerElem = $(@node).find('.banner-container')
    @nextBanner()
    @startCarousel()

  startCarousel: ->
    setInterval(@nextBanner, 8000)

  nextBanner: =>
    @bannerElem.fadeOut =>
      @currentIndex = (@currentIndex + 1) % @banners.length
      @set 'current_banner', @banners[@currentIndex]
      @bannerElem.fadeIn()
