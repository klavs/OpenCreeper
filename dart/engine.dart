part of creeper;

class Mouse {
  int x = 0, y = 0;
  bool active = true;
  Vector dragStart, dragEnd;
  
  Mouse();
}

class Engine {
  num FPS = 60, delta = 1000 / 60, fps_delta, fps_frames, fps_totalTime, fps_updateTime, fps_updateFrames, animationRequest;
  int width, height, halfWidth, halfHeight;
  var fps_lastTime;
  Mouse mouse = new Mouse();
  Mouse mouseGUI = new Mouse();
  Map canvas, sounds, images;
  Timer resizeTimer;

  Engine() {
    canvas = new Map();
    sounds = new Map();
    images = new Map();
    init();
  }

  /**
   * Initializes the canvases and mouse, loads sounds and images.
   */

  void init() {
    width = window.innerWidth;
    height = window.innerHeight;
    halfWidth = (width / 2).floor();
    halfHeight = (height / 2).floor();

    // main
    canvas["main"] = new Canvas(new CanvasElement(), width, height);
    query('#canvasContainer').children.add(canvas["main"].element);
    canvas["main"].top = canvas["main"].element.offsetTop;
    canvas["main"].left = canvas["main"].element.offsetLeft;
    canvas["main"].right = canvas["main"].element.offset.right;
    canvas["main"].bottom = canvas["main"].element.offset.bottom;
    canvas["main"].element.style.zIndex = "1";

    // buffer
    canvas["buffer"] = new Canvas(new CanvasElement(), width, height);

    // gui
    canvas["gui"] = new Canvas(new CanvasElement(), 780, 110);
    query('#gui').children.add(canvas["gui"].element);
    canvas["gui"].top = canvas["gui"].element.offsetTop;
    canvas["gui"].left = canvas["gui"].element.offsetLeft;

    for (int i = 0; i < 10; i++) {
      canvas["level$i"] = new Canvas(new CanvasElement(), 128 * 16, 128 * 16);
    }

    canvas["levelbuffer"] = new Canvas(new CanvasElement(), 128 * 16, 128 * 16);
    canvas["levelfinal"] = new Canvas(new CanvasElement(), width, height);
    query('#canvasContainer').children.add(canvas["levelfinal"].element);

    // collection
    canvas["collection"] = new Canvas(new CanvasElement(), width, height);
    query('#canvasContainer').children.add(canvas["collection"].element);

    // creeper
    canvas["creeperbuffer"] = new Canvas(new CanvasElement(), width, height);
    canvas["creeper"] = new Canvas(new CanvasElement(), width, height);
    query('#canvasContainer').children.add(canvas["creeper"].element);
    
    loadSounds();
  }
  
  void setupEventHandler() {
    query('#terraform').onClick.listen((event) => game.toggleTerraform());
    //query('#slower').onClick.listen((event) => game.slower());
    //query('#faster').onClick.listen((event) => game.faster());
    //query('#pause').onClick.listen((event) => game.pause());
    //query('#resume').onClick.listen((event) => game.resume());
    query('#restart').onClick.listen((event) => game.restart());
    query('#deactivate').onClick.listen((event) => game.deactivateBuilding());
    query('#activate').onClick.listen((event) => game.activateBuilding());

    CanvasElement mainCanvas = canvas["main"].element;
    CanvasElement guiCanvas = canvas["gui"].element;
    mainCanvas.onMouseMove.listen((event) => onMouseMove(event));
    mainCanvas.onDoubleClick.listen((event) => onDoubleClick(event));
    mainCanvas
      ..onMouseDown.listen((event) => onMouseDown(event))
      ..onMouseUp.listen((event) => onMouseUp(event));
    // FIXME: will be implemented in M5: https://code.google.com/p/dart/issues/detail?id=9852
    //mainCanvas
    //  ..onMouseEnter.listen((event) => onEnter)
    //  ..onMouseLeave.listen((event) => onLeave);
    mainCanvas.onMouseWheel.listen((event) => onMouseScroll(event));

    guiCanvas.onMouseMove.listen((event) => onMouseMoveGUI(event));
    guiCanvas.onClick.listen((event) => onClickGUI(event));
    //guiCanvas.onMouseLeave.listen((event) => onLeaveGUI);

    document
      ..onKeyDown.listen((event) => onKeyDown(event))
      ..onKeyUp.listen((event) => onKeyUp(event));
    document.onContextMenu.listen((event) => event.preventDefault());

    window..onResize.listen((event) => onResize(event));
  }

  /**
   * Loads all images.
   *
   * A future is used to make sure the game starts after all images have been loaded.
   * Otherwise some images might not be rendered at all.
   */

  Future loadImages() {
    var completer = new Completer();
    
    // image names
    List filenames = ["analyzer", "numbers", "level0", "level1", "level2", "level3", "level4", "level5", "level6", "level7", "level8", "level9", "borders", "mask", "cannon",
                       "cannongun", "base", "collector", "reactor", "storage", "terp", "packet_collection", "packet_energy", "packet_health", "relay", "emitter", "creeper",
                       "mortar", "shell", "beam", "spore", "bomber", "bombership", "smoke", "explosion", "targetcursor", "sporetower", "forcefield", "shield", "projectile"];    
    int loadedImages = 0;

    filenames.forEach((filename) {
      images[filename] = new ImageElement(src: "images/" + filename + ".png");
      images[filename].onLoad.listen((event) {
        if (++loadedImages == filenames.length) {
          completer.complete();
        }
      });
    });
    return completer.future; 
  }

  void loadSounds() {
    List filenames = ["shot.wav", "click.wav", "explosion.wav", "failure.wav", "energy.wav", "laser.wav"];
    
    filenames.forEach((filename) {
      var name = filename.split(".")[0];
      sounds[name] = new List();
      for (int j = 0; j < 5; j++) {
        sounds[name].add(new AudioElement("sounds/" + filename));
      }
    });
  }

  void playSound(String name, [Vector position]) {
    // adjust sound volume based on the current zoom as well as the position

    num volume = 1;
    if (position != null) {
      Vector screenCenter = new Vector(game.scroll.x, game.scroll.y);
      /*Vector screenCenter = new Vector(
          (halfWidth ~/ (game.tileSize * game.zoom)) + game.scroll.x,
          (halfHeight ~/ (game.tileSize * game.zoom)) + game.scroll.y);*/
      num distance = position.distanceTo(screenCenter);
      volume = (game.zoom / pow(distance / 20, 2)).clamp(0, 1);
    }

    for (int i = 0; i < 5; i++) {
      if (sounds[name][i].ended == true || sounds[name][i].currentTime == 0) {
        sounds[name][i].volume = volume;
        sounds[name][i].play();
        return;
      }
    }
  }

  void updateMouse(MouseEvent evt) {
    //if (evt.pageX > canvas["main"].left && evt.pageX < canvas["main"].right && evt.pageY > canvas["main"].top && evt.pageY < canvas["main"].bottom) {
    mouse.x = (evt.client.x - canvas["main"].element.getBoundingClientRect().left).toInt(); //evt.pageX - canvas["main"].left;
    mouse.y = (evt.client.y - canvas["main"].element.getBoundingClientRect().left).toInt(); //evt.pageY - canvas["main"].top;
    if (game != null) {
      Vector position = game.getHoveredTilePosition();
      mouse.dragEnd = new Vector(position.x, position.y);
    }

    //$("#mouse").innerHtml = ("Mouse: " + mouse.x + "/" + mouse.y + " - " + position.x + "/" + position.y);
    //}
  }

  void updateMouseGUI(MouseEvent evt) {
    //if (evt.pageX > canvas["gui"].left && evt.pageX < canvas["gui"].right && evt.pageY > canvas["gui"].top && evt.pageY < canvas["gui"].bottom) {
    mouseGUI.x = (evt.client.x - canvas["gui"].element.getBoundingClientRect().left).toInt();
    mouseGUI.y = (evt.client.y - canvas["gui"].element.getBoundingClientRect().top).toInt();
    
    //query("#mouse").innerHtml = ("Mouse: " + mouseGUI.x.toString() + "/" + mouseGUI.y.toString());
    
    //}
  }

  void reset() {
    // reset FPS variables
    fps_lastTime = new DateTime.now();
    fps_frames = 0;
    fps_totalTime = 0;
    fps_updateTime = 0;
    fps_updateFrames = 0;
  }

  void update() { // FIXME
    // update FPS
    var now = new DateTime.now();
    fps_delta = now.millisecond - fps_lastTime;
    fps_lastTime = now;
    fps_totalTime += fps_delta;
    fps_frames++;
    fps_updateTime += fps_delta;
    fps_updateFrames++;

    // update FPS display
    if (fps_updateTime > 1000) {
      //query("#fps").innerHtml = "FPS: " + (1000 * fps_frames / fps_totalTime).floor().toString() + " average, " + (1000 * fps_updateFrames / fps_updateTime).floor().toString() + " currently, " + (game.speed * FPS).toString() + " desired";
      fps_updateTime -= 1000;
      fps_updateFrames = 0;
    }
  }

  /**
   * Checks if an object with a given [position] and [size]
   * is visible on the screen. Returns true or false.
   */
  bool isVisible(Vector position, Vector size) {
    Rectangle object = new Rectangle(position.x, position.y, size.x, size.y);
    
    Rectangle view = new Rectangle(game.scroll.x * game.tileSize - engine.halfWidth * game.zoom,
                                   game.scroll.y * game.tileSize - engine.halfHeight * game.zoom,
                                   engine.width * game.zoom, 
                                   engine.height * game.zoom);
    
    return view.intersects(object);
  }
  
  int randomInt(num from, num to, [num seed]) {
    var random = new Random(seed);
    return (random.nextInt(to - from + 1) + from);
  }
  
  num rad2deg(num angle) {
    return angle * 57.29577951308232;
  }
  
  num deg2rad(num angle) {
    return angle * .017453292519943295;
  }
}