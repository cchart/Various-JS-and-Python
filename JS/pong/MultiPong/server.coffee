io = require  'socket.io'
express = require  'express'

_ = require('underscore')._
utils = require('./utils').utils
xy = utils.xy

#Ask for those constants from the server
DIAMETER = 500
RADIUS = DIAMETER / 2
WALL_THICK = 5
INIT_PLAYER_SIZE_PORTION = 0.3 #percent
HALF_WALL_THICK = WALL_THICK / 2
BALL_SIZE = 10 #diameter
SPEED_RANGE = [200, 400]
FPS = 60
SIDES = 4

TWOPI = Math.PI * 2


class Game
  constructor: ->
    @state = state = new State()

    @startMainLoop()

    io.sockets.on  'connection', (socket) ->
      ID = Math.round  Math.random() * 10000000

      console.log  "Connection recieved. ID: #{ID}"

      socket.emit  'constants',
        DIAMETER: DIAMETER
        RADIUS: RADIUS
        WALL_THICK: WALL_THICK
        BALL_SIZE: BALL_SIZE

      socket.on  'addNewUser', (name, cb) ->
        console.log  "User with ID:#{ID} got name -> #{name}"
        player = new Player(name, ID, state)
        socket.set  'name', name, -> cb name:"#{name} (#{ID})", side:player.side

      socket.on  'userMoves', (clientX) =>
        state.update 0, clientX, ID

      disconnectUser = ->
        socket.get  'name', (err, name) ->
          state.removePlayer ID
          console.log "#{name} (#{ID}) disconnected"

      socket.on  'disconnect', disconnectUser
      socket.on  'user disconnect', disconnectUser

  updateAndSend: (timeLeft, clientX) ->
    @state.update timeLeft / 1000, clientX
    io.sockets.volatile.emit  'stateUpdate', @state.serialize()

  startMainLoop: ->
    @reqInterval = setInterval  (=> @updateAndSend(1000 / FPS)), 1000 / FPS

#  stopMainLoop: ->
#    clearRequestInterval @reqInterval


class State
  constructor: ->
    @ball = new Ball(this)
    @players = (null for i in [1..SIDES])
    @playersIdMap = {}
    @arena = new Arena(RADIUS, this)

  addPlayer: (newPlayer) ->
    #Find slot in array and put into first free
    #Assign it's side accordint to slot
    emptySlots = _.filter [0..@players.length-1], (i) => not @players[i]?
    nextIndex = utils.randomFromArray  emptySlots
    nextIndex = @players.length if emptySlots.length is 0
    console.log  "Empty slots: ", emptySlots, nextIndex

    newPlayer.side = nextIndex
    @players[nextIndex] = newPlayer
    @playersIdMap[newPlayer.id] = nextIndex
    @arena.updateSolidWalls()

    return newPlayer

  removePlayer: (id) ->
    i = @playersIdMap[id]
    @players[i] = null
    delete @playersIdMap[id]
    @arena.updateSolidWalls()

  update: (timeleft, clientX, ID) ->
    player = @players[@playersIdMap[ID]]
    if clientX and player
      player.move  clientX
      @arena.updateSolidWalls()

    if timeleft
      unless @ball.move  timeleft
        game.state.ball.randomInit()

  serialize: (perspectivePlayerId) ->
    ball: @ball?.serialize()
    arena: @arena?.serialize()
    players: _.map(@players, (p) -> p?.serialize())


class Ball
  constructor: (@state, @pos, @angle, @speed) ->
    unless @pos and @angle and @speed
      @randomInit()

  randomInit: ->
    @pos = xy  DIAMETER/2, DIAMETER/2
    @angle = utils.randomInRange  0, 360
    @acceleration = 2 #pixels per sec ** 2

    @normalSpeed = utils.randomInRange  SPEED_RANGE...
    @speed = @normalSpeed
    @kickSpeed = @normalSpeed * 0.4
    @maxSpeed = @normalSpeed * 4

  move: (time) ->
    if @speed >= @maxSpeed
      @acceleration = -2

    if @speed < @normalSpeed and @acceleration < 0
      @acceleration = -0.05

    if @speed < SPEED_RANGE[0]
      @acceleration = 0

    @speed += @acceleration * (time * 1000)
    newPos = @findNextPoint  time

    oldAngle = @angle
    [intPoint, @angle, usersKick] = @findIntersectionPoint newPos

    unless intPoint
      @pos = newPos
    else
      io.sockets.emit if usersKick then 'kick!' else 'wall!'
      @speed += utils.randomGauss  @kickSpeed, 30
      @acceleration = -1

      @pos = @findNextPoint  time
      isInside = @isPointInside()

      k = 0
      loop
        break if isInside or k++ > 100
        @pos = intPoint
        @angle = utils.randomInRange  0, 360
        @pos = @findNextPoint  time
        isInside = @isPointInside()

    return @isPointInside()

  isPointInside: (point=@pos) ->
    pointOnTheLeftOfLine = (line) ->
      [x0,y0,x1,y1,x,y] = utils.unfoldPoints  line[0], line[1], point
      (y - y0) * (x1 - x0) - (x - x0) * (y1 - y0) <= 0

    _.all(
      pointOnTheLeftOfLine(wall) for wall in @state.arena.areaWalls
      , _.identity)

  findIntersectionPoint: (nextPoint) ->
    intPoint = null
    userIndex = null
    newAngle = @angle
    for wall, i in @state.arena.solidWalls
      intPoint = utils.lineIntersections  @pos, nextPoint, wall...
      if intPoint
        anglBet = utils.radToDeg  utils.angleBetweenLines  @pos, nextPoint, wall...
        newAngle += anglBet * 2

        randomness = utils.randomGauss  0, anglBet * 0.1
        newAngle += randomness
        userIndex = i if @state.players[i]?
        break
    return [intPoint, newAngle, userIndex]

  findNextPoint: (time, angle=@angle, pos=@pos) ->
    utils.radialMove pos, @speed * time, angle

  serialize: ->
    pos: @pos.round()


class Player
  constructor: (@name, @id, @state) ->
    @side = 0
    @sideLength = @state.arena.getFullWallLength()
    @size = INIT_PLAYER_SIZE_PORTION * @sideLength
    @centerPos = 0.5 #center point position in percents
    @updateSegment()
    @state.addPlayer  this

  move: (clientX) ->
    @updateCenterPosition  clientX
    @updateSegment()

  updateCenterPosition: (clientX) ->
    clientX -= @state.arena.areaWalls[0][0].x + @size / 2
    @centerPos = clientX / (@sideLength - @size)
    @centerPos = 1 if @centerPos > 1
    @centerPos = 0 if @centerPos < 0

  updateSegment: ->
    centerPx = @centerPos * (@sideLength - @size)
    segmentStart = centerPx / @sideLength
    segmentEnd = (centerPx + @size) / @sideLength
    @segment = seg  segmentStart, segmentEnd

  serialize: ->
    id: @id
    name: @name
    side: @side


class Arena
  constructor: (@radius, @state) ->
    @players = @state.players
    @solidWalls = @areaWalls = @updateAreaWalls()

  updateSolidWalls: ->
    unless @players.length is @portions.length
      @updateAreaWalls()
    else
      @updatePortions()

    @solidWalls =
      for [start, end], i in @areaWalls
        {start: startPortion, end: endPortion} = @portions[i]
        xd = end.x - start.x
        yd = end.y - start.y
        start = xy  start.x + xd * startPortion, start.y + yd * startPortion
        end = xy  end.x - xd * (1-endPortion), end.y - yd * (1-endPortion)
        [start, end]

  updateAreaWalls: ->
    @updatePortions()
    @updateCorners()
    @areaWalls = ([@corners[i-1..i-1][0], corner] for corner, i in @corners)

  updatePortions: ->
    @portions = _.map  @players, (p) -> if p then p.segment else seg(0, 1)

  getFullWallLength: -> utils.distance  @areaWalls[0]...

  updateCorners: ->
    sidesNum = @portions.length
    center = xy  @radius, @radius
    sectorAngle = 360 / sidesNum
    angle = 270 - sectorAngle / 2
    @corners =
      for sideIndex in [0..sidesNum-1]
        angle += sectorAngle
        utils.radialMove  center, @radius, angle

  serialize: ->
    solidWalls: ([start.round(), end.round()] for [start, end] in @solidWalls)



#TODO Better name is range
class Segment
  constructor: (@start, @end) ->


seg = (vars...) -> new Segment(vars...)

app = express.createServer()
io = io.listen  app

io.configure  'production', ->
  io.enable  'browser client etag'
  io.set  'log level', 1
  io.set  'transports', [
    'xhr-polling'
    'websocket'
    'htmlfile'
    'jsonp-polling'
  ]
  io.set  "polling duration", 5

io.configure  'development', ->
  io.set  'log level', 1
  io.set  'transports', ['websocket', 'xhr-polling']


port = process.env.PORT or 8080
app.listen  port
console.log  "Started listening on port #{port}"

dir = __dirname.replace /\/js$/, ''
app.get  '/', (req, res) ->
  console.log dir + '/index.html'
  res.sendfile  dir + '/index.html'

app.get  '/sides/:sides', (req, res) ->
  SIDES = parseInt  req.params.sides, 10
  game.state = new State()
  res.send("OK")

app.configure  ->
  app.use  "/node_modules", express.static  dir + '/node_modules'
  app.use  "/js", express.static  dir + '/js'
  app.use  "/libs", express.static  dir + '/libs'
  app.use  "/sounds", express.static  dir + '/sounds'

game = new Game()