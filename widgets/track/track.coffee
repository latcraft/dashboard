class Dashing.Track extends Dashing.Widget

  ready: ->
    @trackElem = $(@node).find('.session-container')
    @startCarousel()
    @refreshData()

  startCarousel: ->
    setInterval(@refreshData, 8000)

  refreshData: =>    
    session = @get 'session'
    @trackElem.fadeOut =>
      @set 'current_session', session
      @trackElem.fadeIn()
