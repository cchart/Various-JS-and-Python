(function() {
  var BALL_SIZE, Ball, Canvas, Game, HALF_WALL_THICK, INIT_PLAYER_SIZE, INNER_SIDE, Player, Point, SIDE, SPEED_RANGE, State, TWOPI, WALL_THICK, degToRad, randomInRange, xy;

  INNER_SIDE = 500;

  WALL_THICK = 5;

  SIDE = INNER_SIDE + WALL_THICK * 2;

  INIT_PLAYER_SIZE = 0.1 * INNER_SIDE;

  HALF_WALL_THICK = WALL_THICK / 2;

  BALL_SIZE = 10;

  SPEED_RANGE = [200, 400];

  TWOPI = Math.PI * 2;

  $(function() {
    var game;
    console.log("ready");
    game = new Game();
    return $("#button").bind('click', function() {
      if (this.innerHTML === 'Start') {
        game.startMainLoop();
        return this.innerHTML = 'Stop';
      } else {
        game.stopMainLoop();
        return this.innerHTML = 'Start';
      }
    });
  });

  Game = (function() {

    function Game() {
      console.log("constructor");
      this.state = new State();
      this.canvas = new Canvas(this);
      this.state.addPlayer(new Player());
      this.initHandlers();
      this.canvas.repaint();
    }

    Game.prototype.initHandlers = function() {
      var _this = this;
      return this.canvas.el.bind("mousemove", function(e) {
        return _this.updateAndRepaint(0, e.offsetX);
      });
    };

    Game.prototype.updateAndRepaint = function(timeLeft, clientX) {
      this.state.update(timeLeft / 1000, clientX);
      return this.canvas.repaint();
    };

    Game.prototype.startMainLoop = function() {
      var prevTimestamp, requestAnimationFrame, step,
        _this = this;
      this.shouldStop = false;
      requestAnimationFrame = window.requestAnimationFrame || window.mozRequestAnimationFrame || window.webkitRequestAnimationFrame || window.msRequestAnimationFrame;
      prevTimestamp = Date.now();
      step = function(timestamp) {
        if (!_this.shouldStop) {
          _this.updateAndRepaint(timestamp - prevTimestamp);
          requestAnimationFrame(step);
        }
        return prevTimestamp = timestamp;
      };
      return requestAnimationFrame(step);
    };

    Game.prototype.stopMainLoop = function() {
      return this.shouldStop = true;
    };

    return Game;

  })();

  Canvas = (function() {

    function Canvas(game) {
      this.state = game.state;
      this.prepare();
    }

    Canvas.prototype.prepare = function() {
      var _ref;
      this.el = $('#canvas');
      this.el.attr('width', SIDE);
      this.el.attr('height', SIDE);
      this.context = (_ref = this.el[0]) != null ? typeof _ref.getContext === "function" ? _ref.getContext('2d') : void 0 : void 0;
      return console.log(this.context);
    };

    Canvas.prototype.repaint = function() {
      this.clearAll();
      this.drawWalls();
      return this.drawBall();
    };

    Canvas.prototype.clearAll = function() {
      return this.el.attr('width', SIDE);
    };

    Canvas.prototype.drawWalls = function() {
      var from, to, _i, _len, _ref, _ref2, _results;
      _ref = this.state.walls();
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        _ref2 = _ref[_i], from = _ref2[0], to = _ref2[1];
        this.context.lineWidth = WALL_THICK;
        this.context.beginPath();
        this.context.moveTo(from.x, from.y);
        this.context.lineTo(to.x, to.y);
        this.context.closePath();
        this.context.stroke();
        _results.push(this.context.lineWidth = 1);
      }
      return _results;
    };

    Canvas.prototype.drawBall = function() {
      var x, y, _ref;
      _ref = [this.state.ball.pos.x, this.state.ball.pos.y], x = _ref[0], y = _ref[1];
      this.context.fillStyle = 'red';
      this.context.beginPath();
      this.context.moveTo(x, y);
      this.context.arc(x, y, BALL_SIZE, 0, TWOPI, true);
      this.context.closePath();
      this.context.fill();
      return this.context.fillStyle = 'black';
    };

    return Canvas;

  })();

  Ball = (function() {

    function Ball(pos, angle, speed) {
      this.pos = pos;
      this.angle = angle;
      this.speed = speed;
      if (!(this.pos && this.angle && this.speed)) this.randomInit();
    }

    Ball.prototype.randomInit = function() {
      this.pos = xy(SIDE / 2, SIDE / 2);
      this.angle = randomInRange(0, 360);
      this.speed = randomInRange(SPEED_RANGE[0], SPEED_RANGE[1]);
      return console.log('Ball setup', this.pos, this.angle, this.speed);
    };

    Ball.prototype.getBoundingBox = function() {};

    Ball.prototype.move = function(time, walls) {
      var newPos;
      newPos = this.findNextPoint(time);
      return this.pos = newPos;
    };

    Ball.prototype.findNextPoint = function(time) {
      var deltaX, deltaY, distance, radians, x, y;
      distance = Math.round(this.speed * time);
      radians = degToRad(this.angle);
      deltaY = Math.sin(radians) * distance;
      deltaX = Math.cos(radians) * distance;
      x = this.pos.x + deltaX;
      y = this.pos.y - deltaY;
      return xy(x, y);
    };

    return Ball;

  })();

  State = (function() {

    State.playerIndexSideMap = ['bottom', 'top', 'right', 'left'];

    function State() {
      var a;
      this.ball = new Ball();
      this.players = (function() {
        var _results;
        _results = [];
        for (a = 1; a <= 4; a++) {
          _results.push(null);
        }
        return _results;
      })();
    }

    State.prototype.walls = function() {
      var i, side, wallEnd, wallStart, _len, _ref, _ref2, _results;
      _ref = State.playerIndexSideMap;
      _results = [];
      for (i = 0, _len = _ref.length; i < _len; i++) {
        side = _ref[i];
        _results.push((_ref2 = (function() {
          if (this.players[i]) {
            return this.players[i].getWallPosition();
          } else {
            switch (side) {
              case 'bottom':
                return [xy(0, SIDE - HALF_WALL_THICK), xy(SIDE, SIDE - HALF_WALL_THICK)];
              case 'top':
                return [xy(0, HALF_WALL_THICK), xy(SIDE, HALF_WALL_THICK)];
              case 'right':
                return [xy(SIDE - HALF_WALL_THICK, 0), xy(SIDE - HALF_WALL_THICK, SIDE)];
              case 'left':
                return [xy(HALF_WALL_THICK, 0), xy(HALF_WALL_THICK, SIDE)];
              default:
                return [xy(0, 0), xy(0, 0)];
            }
          }
        }).call(this), wallStart = _ref2[0], wallEnd = _ref2[1], _ref2));
      }
      return _results;
    };

    State.prototype.addPlayer = function(newPlayer) {
      var i, player, _len, _ref;
      _ref = this.players;
      for (i = 0, _len = _ref.length; i < _len; i++) {
        player = _ref[i];
        if (!player) {
          newPlayer.side = State.playerIndexSideMap[i];
          return this.players[i] = newPlayer;
        }
      }
    };

    State.prototype.update = function(timeleft, clientX) {
      if (clientX) this.players[0].move(clientX);
      if (timeleft) return this.ball.move(timeleft, this.walls);
    };

    return State;

  })();

  Player = (function() {

    function Player(name) {
      this.name = name;
      this.side = State.playerIndexSideMap[0];
      this.size = INIT_PLAYER_SIZE;
      this.pos = 0.5;
    }

    Player.prototype.getWallPosition = function() {
      var from, to, wallCenter, _ref;
      wallCenter = (INNER_SIDE - this.size) * this.pos;
      _ref = [wallCenter + WALL_THICK, wallCenter + this.size + WALL_THICK], from = _ref[0], to = _ref[1];
      switch (this.side) {
        case 'bottom':
          return [xy(from, SIDE - HALF_WALL_THICK), xy(to, SIDE - HALF_WALL_THICK)];
        case 'top':
          return [xy(from, HALF_WALL_THICK), xy(to, HALF_WALL_THICK)];
        case 'right':
          return [xy(SIDE - HALF_WALL_THICK, from), xy(SIDE - HALF_WALL_THICK, to)];
        case 'left':
          return [xy(HALF_WALL_THICK, from), xy(HALF_WALL_THICK, to)];
      }
    };

    Player.prototype.move = function(clientX) {
      clientX -= this.size / 2;
      this.pos = clientX / (INNER_SIDE - this.size);
      if (this.pos > 1) this.pos = 1;
      if (this.pos < 0) return this.pos = 0;
    };

    return Player;

  })();

  randomInRange = function(from, to) {
    return Math.random() * (to - from) + from;
  };

  degToRad = function(deg) {
    return deg * (Math.PI / 180);
  };

  xy = function(x, y) {
    return new Point(x, y);
  };

  Point = (function() {

    function Point(x, y) {
      this.x = x;
      this.y = y;
    }

    Point.prototype.toString = function() {
      return "(" + this.x + ", " + this.y + ")";
    };

    return Point;

  })();

}).call(this);