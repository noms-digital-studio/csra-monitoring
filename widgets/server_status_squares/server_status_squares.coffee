class Dashing.ServerStatusSquares extends Dashing.Widget

  onData: (data) ->
    console.log(data)
    $(@node).fadeOut().fadeIn()
    green = "#96BF48"
    red = "#BF4848"
    result = data.result
    color = if result.status == "OK" then green else red
    $(@get('node')).css('background-color', "#{color}")