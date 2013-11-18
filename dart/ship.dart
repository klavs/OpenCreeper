part of creeper;

class Ship {
  Vector speed = new Vector(0, 0), targetPosition = new Vector(0, 0);
  String type, status = "IDLE"; // ATTACKING, RETURNING, RISING, FALLING
  bool remove = false, hovered = false, selected = false;
  int maxEnergy = 15, energy = 0, trailCounter = 0, weaponCounter = 0, flightCounter = 0;
  Building home;
  Sprite sprite, targetSymbol;
  Circle hoverCircle, selectedCircle;
  static final int baseSpeed = 1;
  static List<Ship> ships = new List<Ship>();

  Ship(position, imageID, this.type, this.home) {
    sprite = new Sprite(4, engine.images[imageID], position, 48, 48);
    sprite.anchor = new Vector(0.5, 0.5);
    engine.canvas["buffer"].addDisplayObject(sprite);

    hoverCircle = new Circle(5, position, 24, 2, "#f00");
    engine.canvas["buffer"].addDisplayObject(hoverCircle);

    selectedCircle = new Circle(5, position, 24, 2, "#fff");
    selectedCircle.visible = false;
    engine.canvas["buffer"].addDisplayObject(selectedCircle);

    targetSymbol = new Sprite(0, engine.images["targetcursor"], position, 48, 48);
    targetSymbol.anchor = new Vector(0.5, 0.5);
    targetSymbol.alpha = 0.5;
    targetSymbol.visible = false;
    engine.canvas["buffer"].addDisplayObject(targetSymbol);
  }
  
  static void clear() {
    ships.clear();
  }
  
  static void add(Ship ship) {
    ships.add(ship);
  }
  
  static void update() {
    for (int i = 0; i < ships.length; i++) {
      ships[i].move();
    }
  }
  
  static void select() {
    // select a ship if hovered
    for (int i = 0; i < ships.length; i++) {
      if (ships[i].hovered) {
        ships[i].selected = true;
      }
    }
    game.targetCursor.visible = true;
  }
  
  static void deselect() {
    for (int i = 0; i < ships.length; i++) {
      ships[i].selected = false;
      ships[i].selectedCircle.visible = false;
    }
    game.targetCursor.visible = false;
  }
  
  static void updateHoverState() {
    for (int i = 0; i < ships.length; i++) {
      Vector realPosition = ships[i].sprite.position.real2screen();
      ships[i].hovered = (engine.mouse.position.x > realPosition.x - 24 && engine.mouse.position.x < realPosition.x + 24 && engine.mouse.position.y > realPosition.y - 24 && engine.mouse.position.y < realPosition.y + 24);
      ships[i].hoverCircle.visible = ships[i].hovered;
    }
  }

  void turnToTarget() {
    Vector delta = targetPosition - sprite.position;
    double angleToTarget = engine.rad2deg(atan2(delta.y, delta.x));

    num turnRate = 1.5;
    num absoluteDelta = (angleToTarget - sprite.rotation).abs();

    if (absoluteDelta < turnRate)
      turnRate = absoluteDelta;

    if (absoluteDelta <= 180)
      if (angleToTarget < sprite.rotation)
        sprite.rotation -= turnRate;
      else
        sprite.rotation += turnRate;
    else
      if (angleToTarget < sprite.rotation)
        sprite.rotation += turnRate;
      else
        sprite.rotation -= turnRate;

    if (sprite.rotation > 180)
      sprite.rotation -= 360;
    if (sprite.rotation < -180)
      sprite.rotation += 360;
  }

  void calculateVector() {
    num x = cos(engine.deg2rad(sprite.rotation));
    num y = sin(engine.deg2rad(sprite.rotation));

    speed.x = x * Ship.baseSpeed * game.speed;
    speed.y = y * Ship.baseSpeed * game.speed;
  }
  
  static void control(Vector position) {
    position = position * game.tileSize;
    position += new Vector(8, 8);
    
    for (int i = 0; i < ships.length; i++) {
      
      // select ship
      if (ships[i].hovered) {
        ships[i].selected = true;
        ships[i].selectedCircle.visible = true;
      }
      
      // control if selected
      if (ships[i].selected) {
        game.mode = "SHIP_SELECTED";
  
        if (ships[i].status == "IDLE") {
          if (position != ships[i].home.sprite.position) {         
            // leave home
            ships[i].energy = ships[i].home.energy;
            ships[i].home.energy = 0;
            ships[i].targetPosition = position;
            ships[i].targetSymbol.position = ships[i].targetPosition;
            ships[i].status = "RISING";
          }
        }
        
        if (ships[i].status == "ATTACKING" || ships[i].status == "RETURNING") {      
          if (position == ships[i].home.sprite.position) {
            // return home
            ships[i].targetPosition = position;
            ships[i].status = "RETURNING";
          }
          else {
            // attack again
            ships[i].targetPosition = position;
            ships[i].targetSymbol.position = ships[i].targetPosition;
            ships[i].status = "ATTACKING";
          }
        }
  
      }
    }
  }

  void move() {
    if (status == "ATTACKING" || status == "RETURNING") {
      trailCounter++;
      if (trailCounter == 10) {
        trailCounter = 0;
        Smoke.add(new Vector(sprite.position.x, sprite.position.y - 16));
      }
    }

    if (status == "RISING") {
      if (flightCounter < 25) {
        flightCounter++;
        sprite.scale = sprite.scale * 1.01;
        hoverCircle.scale *= 1.01;
        selectedCircle.scale *= 1.01;
      }
      if (flightCounter == 25) {
        status = "ATTACKING";
      }
    }
    
    else if (status == "FALLING") {
      if (flightCounter > 0) {
        flightCounter--;
        sprite.scale = sprite.scale / 1.01;
        hoverCircle.scale /= 1.01;
        selectedCircle.scale /= 1.01;
      }
      if (flightCounter == 0) {
        status = "IDLE";
        targetPosition.x = 0;
        targetPosition.y = 0;
        energy = 5;
        sprite.scale = new Vector(1.0, 1.0);
        hoverCircle.scale = 1.0;
        selectedCircle.scale = 1.0;
      }
    }
    
    else if (status == "ATTACKING") {
      weaponCounter++;

      turnToTarget();
      calculateVector();

      sprite.position += speed;
      hoverCircle.position += speed;
      selectedCircle.position += speed;

      if (sprite.position.x > targetPosition.x - 2 && sprite.position.x < targetPosition.x + 2 && sprite.position.y > targetPosition.y - 2 && sprite.position.y < targetPosition.y + 2) {
        if (weaponCounter >= 10) {
          weaponCounter = 0;
          Explosion.add(targetPosition);
          energy -= 1;

          for (int i = (targetPosition.x / game.tileSize).floor() - 3; i < (targetPosition.x / game.tileSize).floor() + 5; i++) {
            for (int j = (targetPosition.y / game.tileSize).floor() - 3; j < (targetPosition.y / game.tileSize).floor() + 5; j++) {
              if (game.world.contains(new Vector(i, j))) {
                num distance = pow((i * game.tileSize + game.tileSize / 2) - (targetPosition.x + game.tileSize), 2) + pow((j * game.tileSize + game.tileSize / 2) - (targetPosition.y + game.tileSize), 2);
                if (distance < pow(game.tileSize * 3, 2)) {
                  game.world.tiles[i][j].creep -= 5;
                  if (game.world.tiles[i][j].creep < 0) {
                    game.world.tiles[i][j].creep = 0;
                  }
                  game.world.tiles[i][j].newcreep -= 5;
                  if (game.world.tiles[i][j].newcreep < 0) {
                    game.world.tiles[i][j].newcreep = 0;
                  }
                }
              }
            }
          }

          if (energy == 0) {
            // return to base
            status = "RETURNING";
            targetPosition = home.sprite.position;
          }
        }
      }
    }
    
    else if (status == "RETURNING") {
      turnToTarget();
      calculateVector();

      sprite.position += speed;
      hoverCircle.position += speed;
      selectedCircle.position += speed;

      if (sprite.position.x > targetPosition.x - 2 && sprite.position.x < targetPosition.x + 2 && sprite.position.y > targetPosition.y - 2 && sprite.position.y < targetPosition.y + 2) {
        sprite.position = home.sprite.position;
        status = "FALLING";
      }
    }

    targetSymbol.visible = ((status == "ATTACKING" || status == "RISING") && selected);
  }
}