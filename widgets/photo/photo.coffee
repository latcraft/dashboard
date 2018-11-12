class Dashing.Photo extends Dashing.Widget

  onData: (data) ->
    $(@node).fadeOut =>
      @set 'image', data.new_image
      $(@node).fadeIn()
