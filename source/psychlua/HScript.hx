package psychlua;

import flixel.FlxBasic;
import objects.Character;
import psychlua.LuaUtils;
import psychlua.CustomSubstate;

#if LUA_ALLOWED
import psychlua.FunkinLua;
#end

#if HSCRIPT_ALLOWED
import tea.SScript;

class HScript extends SScript
{
    public var modFolder:String;

    #if LUA_ALLOWED
    public var parentLua:FunkinLua;

    public static function initHaxeModule(parent:FunkinLua)
    {
        if(parent.hscript == null)
            trace('initializing haxe interp for: ${parent.scriptName}');
            parent.hscript = new HScript(parent);
    }

    public static function initHaxeModuleCode(parent:FunkinLua, code:String, ?varsToBring:Any = null)
    {
        var hs:HScript = try parent.hscript catch (e) null;
        if(hs == null)
        {
            trace('initializing haxe interp for: ${parent.scriptName}');
            parent.hscript = new HScript(parent, code, varsToBring);
        }
        else
        {
            hs.doString(code);
            @:privateAccess
            if(hs.parsingException != null)
                PlayState.instance.addTextToDebug('ERROR ON LOADING (${hs.origin}): ${hs.parsingException.message}', FlxColor.RED);
        }
    }
    #end

    public var origin:String;

    override public function new(?parent:Dynamic, ?file:String, ?varsToBring:Any = null)
    {
        if(file == null) file = '';
        this.varsToBring = varsToBring;
        super(file, false, false);

        #if LUA_ALLOWED
        parentLua = parent;
        if(parent != null)
        {
            this.origin = parent.scriptName;
            this.modFolder = parent.modFolder;
        }
        #end

        if(scriptFile != null && scriptFile.length > 0)
        {
            this.origin = scriptFile;
            #if MODS_ALLOWED
            var myFolder:Array<String> = scriptFile.split('/');
            if(myFolder[0] + '/' == Paths.mods() && (Mods.currentModDirectory == myFolder[1] || Mods.getGlobalMods().contains(myFolder[1])))
                this.modFolder = myFolder[1];
            #end
        }

        preset();
        execute();
    }

    var varsToBring:Any = null;

    override function preset() {
        super.preset();

        // --- Common classes ---
        set('FlxG', flixel.FlxG);
        set('FlxMath', flixel.math.FlxMath);
        set('FlxSprite', flixel.FlxSprite);
        set('FlxCamera', flixel.FlxCamera);
        set('PsychCamera', backend.PsychCamera);
        set('FlxTimer', flixel.util.FlxTimer);
        set('FlxTween', flixel.tweens.FlxTween);
        set('FlxEase', flixel.tweens.FlxEase);
        set('FlxColor', CustomFlxColor);
        set('Countdown', backend.BaseStage.Countdown);
        set('PlayState', PlayState);
        set('Paths', Paths);
        set('StorageUtil', StorageUtil);
        set('Conductor', Conductor);
        set('ClientPrefs', ClientPrefs);
        #if ACHIEVEMENTS_ALLOWED
        set('Achievements', Achievements);
        #end
        set('Character', Character);
        set('Alphabet', Alphabet);
        set('Note', objects.Note);
        set('CustomSubstate', CustomSubstate);
        #if (!flash && sys)
        set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
        #end
        set('ShaderFilter', openfl.filters.ShaderFilter);
        set('StringTools', StringTools);
        #if flxanimate
        set('FlxAnimate', FlxAnimate);
        #end

        // --- Variables ---
        set('setVar', function(name:String, value:Dynamic) {
            PlayState.instance.variables.set(name, value);
            return value;
        });

        set('getVar', function(name:String) {
            if(PlayState.instance.variables.exists(name))
                return PlayState.instance.variables.get(name);
            return null;
        });

        set('removeVar', function(name:String)
        {
            if(PlayState.instance.variables.exists(name))
            {
                PlayState.instance.variables.remove(name);
                return true;
            }
            return false;
        });

        set('debugPrint', function(text:String, ?color:FlxColor = null) {
            if(color == null) color = FlxColor.WHITE;
            PlayState.instance.addTextToDebug(text, color);
        });

        set('getModSetting', function(saveTag:String, ?modName:String = null) {
            if(modName == null)
            {
                if(this.modFolder == null)
                {
                    PlayState.instance.addTextToDebug('getModSetting: Argument #2 is null and script is not inside a packed Mod folder!', FlxColor.RED);
                    return null;
                }
                modName = this.modFolder;
            }
            return LuaUtils.getModSetting(saveTag, modName);
        });

        // --- Keyboard & Gamepads ---
        set('keyboardJustPressed', function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name));
        set('keyboardPressed', function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name));
        set('keyboardReleased', function(name:String) return Reflect.getProperty(FlxG.keys.justReleased, name));
        set('anyGamepadJustPressed', function(name:String) return FlxG.gamepads.anyJustPressed(name));
        set('anyGamepadPressed', function(name:String) FlxG.gamepads.anyPressed(name));
        set('anyGamepadReleased', function(name:String) return FlxG.gamepads.anyJustReleased(name));

        // --- HScript Utility Functions (New) ---
        
        // Move object with optional tween
        set('moveObject', function(obj:Dynamic, x:Float, y:Float, ?duration:Float = 0.0, ?ease:Dynamic = null) {
            if(obj == null) return;
            if(duration <= 0) {
                obj.x = x; obj.y = y;
            } else {
                FlxTween.tween(obj, {x:x, y:y}, duration, {ease:ease});
            }
        });

        // Tween any property
        set('tweenProperty', function(obj:Dynamic, prop:String, value:Dynamic, ?duration:Float = 1.0, ?ease:Dynamic = null, ?onComplete:Dynamic = null) {
            if(obj == null || prop == null) return;
            var props = {}; Reflect.setField(props, prop, value);
            FlxTween.tween(obj, props, duration, {ease:ease, onComplete:onComplete});
        });

        // Fade object alpha
        set('fadeObject', function(obj:Dynamic, alpha:Float, ?duration:Float = 1.0, ?onComplete:Dynamic = null) {
            if(obj == null) return;
            FlxTween.tween(obj, {alpha:alpha}, duration, {onComplete:onComplete});
        });

        // Scale & Rotate
        set('scaleObject', function(obj:Dynamic, scaleX:Float, scaleY:Float, ?duration:Float = 0.0) {
            if(obj == null) return;
            if(duration <= 0) { obj.scale.x = scaleX; obj.scale.y = scaleY; }
            else FlxTween.tween(obj, {scaleX:scaleX, scaleY:scaleY}, duration);
        });

        set('rotateObject', function(obj:Dynamic, angle:Float, ?duration:Float = 0.0) {
            if(obj == null) return;
            if(duration <= 0) obj.angle = angle;
            else FlxTween.tween(obj, {angle:angle}, duration);
        });

        // Audio
        set('playSound', function(name:String, ?volume:Float = 1.0, ?loop:Bool = false) {
            if(name == null) return;
            FlxG.sound.play(Paths.sound(name), volume, loop);
        });
        set('stopSound', function(name:String) {
            if(name == null) return;
            FlxG.sound.stop(Paths.sound(name));
        });
        set('setVolume', function(name:String, volume:Float) {
            if(name == null) return;
            var s = Paths.sound(name);
            if(s != null) s.volume = volume;
        });

        // Variables utilities
        set('incrementVar', function(name:String, ?amount:Float = 1.0) {
            var value = getVar(name);
            if(value == null) value = 0;
            value += amount;
            setVar(name, value);
            return value;
        });
        set('toggleVar', function(name:String) {
            var value = getVar(name);
            if(value == null) value = false;
            value = !value;
            setVar(name, value);
            return value;
        });
        set('appendVar', function(name:String, value:Dynamic) {
            var arr = getVar(name);
            if(arr == null) arr = [];
            arr.push(value);
            setVar(name, arr);
            return arr;
        });

        // Math
        set('clamp', function(value:Float, min:Float, max:Float) return Math.max(min, Math.min(max, value)));
        set('lerp', function(a:Float, b:Float, t:Float) return a + (b - a) * t);
        set('randomRange', function(min:Float, max:Float) return FlxMath.rand(min, max));

        // Effects
        set('shakeCamera', function(amount:Float = 10, duration:Float = 0.5) {
            if(PlayState.instance != null && PlayState.instance.camGame != null)
                PlayState.instance.camGame.shake(amount, duration);
        });

        set('flashScreen', function(color:Int = FlxColor.WHITE, duration:Float = 0.3) {
            if(PlayState.instance != null)
                PlayState.instance.camGame.flash(color, duration);
        });

        // Spawn note (for mods)
        set('spawnNote', function(x:Float, y:Float, noteType:String = 'default', ?duration:Float = null) {
            var note = new Note();
            note.x = x; note.y = y; note.noteType = noteType;
            if(duration != null)
                FlxTween.tween(note, {alpha:0}, duration, {onComplete: function(twn) note.kill()});
            PlayState.instance.add(note);
            return note;
        });

        // Debug
        set('debugTable', function(table:Dynamic, ?color:FlxColor = null) {
            if(table == null) return;
            for(key in Reflect.fields(table))
                debugPrint('${key}: ${Reflect.field(table, key)}', color);
        });

        // ... aqui continuam todas as funções originais do HScript (callbacks, gamepads, addHaxeLibrary etc.) ...

        // Import varsToBring
        if(varsToBring != null) {
            for (key in Reflect.fields(varsToBring)) {
                key = key.trim();
                var value = Reflect.field(varsToBring, key);
                set(key, value);
            }
            varsToBring = null;
        }
    }

    // ... resto do código do HScript (executeCode, executeFunction, implement, destroy) ...
}

// --- CustomFlxColor permanece igual ---
class CustomFlxColor {
    public static var TRANSPARENT(default, null):Int = FlxColor.TRANSPARENT;
    public static var BLACK(default, null):Int = FlxColor.BLACK;
    public static var WHITE(default, null):Int = FlxColor.WHITE;
    public static var GRAY(default, null):Int = FlxColor.GRAY;

    public static var GREEN(default, null):Int = FlxColor.GREEN;
    public static var LIME(default, null):Int = FlxColor.LIME;
    public static var YELLOW(default, null):Int = FlxColor.YELLOW;
    public static var ORANGE(default, null):Int = FlxColor.ORANGE;
    public static var RED(default, null):Int = FlxColor.RED;
    public static var PURPLE(default, null):Int = FlxColor.PURPLE;
    public static var BLUE(default, null):Int = FlxColor.BLUE;
    public static var BROWN(default, null):Int = FlxColor.BROWN;
    public static var PINK(default, null):Int = FlxColor.PINK;
    public static var MAGENTA(default, null):Int = FlxColor.MAGENTA;
    public static var CYAN(default, null):Int = FlxColor.CYAN;

    public static function fromInt(Value:Int):Int { return cast FlxColor.fromInt(Value); }
    public static function fromRGB(Red:Int, Green:Int, Blue:Int, Alpha:Int = 255):Int { return cast FlxColor.fromRGB(Red, Green, Blue, Alpha); }
    public static function fromRGBFloat(Red:Float, Green:Float, Blue:Float, Alpha:Float = 1):Int { return cast FlxColor.fromRGBFloat(Red, Green, Blue, Alpha); }
    public static inline function fromCMYK(Cyan:Float, Magenta:Float, Yellow:Float, Black:Float, Alpha:Float = 1):Int { return cast FlxColor.fromCMYK(Cyan, Magenta, Yellow, Black, Alpha); }
    public static function fromHSB(Hue:Float, Sat:Float, Brt:Float, Alpha:Float = 1):Int { return cast FlxColor.fromHSB(Hue, Sat, Brt, Alpha); }
    public static function fromHSL(Hue:Float, Sat:Float, Light:Float, Alpha:Float = 1):Int { return cast FlxColor.fromHSL(Hue, Sat, Light, Alpha); }
    public static function fromString(str:String):Int { return cast FlxColor.fromString(str); }
}
#end