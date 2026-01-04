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
    #end
    public var origin:String;
    var varsToBring:Dynamic = null;

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

    override function preset()
    {
        super.preset();

        // Common classes
        set('FlxG', flixel.FlxG);
        set('FlxMath', flixel.math.FlxMath);
        set('FlxSprite', flixel.FlxSprite);
        set('FlxCamera', flixel.FlxCamera);
        set('PsychCamera', backend.PsychCamera);
        set('FlxTimer', flixel.util.FlxTimer);
        set('FlxTween', flixel.tweens.FlxTween);
        set('FlxEase', flixel.tweens.FlxEase);
        set('FlxColor', CustomFlxColor);
        set('PlayState', PlayState);
        set('Paths', Paths);
        set('ClientPrefs', ClientPrefs);
        set('Character', Character);
        set('Note', objects.Note);
        set('CustomSubstate', CustomSubstate);

        // Functions & variables
        set('setVar', function(name:String, value:Dynamic) { PlayState.instance.variables.set(name,value); return value; });
        set('getVar', function(name:String) { return PlayState.instance.variables.exists(name) ? PlayState.instance.variables.get(name) : null; });
        set('removeVar', function(name:String) { if(PlayState.instance.variables.exists(name)){ PlayState.instance.variables.remove(name); return true; } return false; });
        set('debugPrint', function(text:String, ?color:FlxColor = null) { if(color == null) color = FlxColor.WHITE; PlayState.instance.addTextToDebug(text,color); });

        // Extra helper functions
        set('randomFloat', function(min:Float, max:Float) return FlxMath.randomFloat(min, max));
        set('randomInt', function(min:Int, max:Int) return FlxMath.rand(min, max));
        set('clamp', function(value:Float, min:Float, max:Float) return FlxMath.clamp(value,min,max));
        set('lerp', function(from:Float, to:Float, ratio:Float) return FlxMath.lerp(from,to,ratio));

        // Keyboard
        set('keyJustPressed', function(name:String='') {
            name = name.toLowerCase();
            switch(name)
            {
                case 'left': return Controls.instance.NOTE_LEFT_P;
                case 'down': return Controls.instance.NOTE_DOWN_P;
                case 'up': return Controls.instance.NOTE_UP_P;
                case 'right': return Controls.instance.NOTE_RIGHT_P;
                default: return Controls.instance.justPressed(name);
            }
        });
        set('keyPressed', function(name:String='') {
            name = name.toLowerCase();
            switch(name)
            {
                case 'left': return Controls.instance.NOTE_LEFT;
                case 'down': return Controls.instance.NOTE_DOWN;
                case 'up': return Controls.instance.NOTE_UP;
                case 'right': return Controls.instance.NOTE_RIGHT;
                default: return Controls.instance.pressed(name);
            }
        });
        set('keyReleased', function(name:String='') {
            name = name.toLowerCase();
            switch(name)
            {
                case 'left': return Controls.instance.NOTE_LEFT_R;
                case 'down': return Controls.instance.NOTE_DOWN_R;
                case 'up': return Controls.instance.NOTE_UP_R;
                case 'right': return Controls.instance.NOTE_RIGHT_R;
                default: return Controls.instance.justReleased(name);
            }
        });

        #if LUA_ALLOWED && mobile
        // Mobile touchpad functions
        var fJustPressed = function(button:Dynamic):Bool {
            if(PlayState.instance.luaTouchPad == null) return false;
            return PlayState.instance.luaTouchPadJustPressed(button);
        };
        var fPressed = function(button:Dynamic):Bool {
            if(PlayState.instance.luaTouchPad == null) return false;
            return PlayState.instance.luaTouchPadPressed(button);
        };
        var fJustReleased = function(button:Dynamic):Bool {
            if(PlayState.instance.luaTouchPad == null) return false;
            return PlayState.instance.luaTouchPadJustReleased(button);
        };

        set("touchPadJustPressed", fJustPressed);
        set("touchPadPressed", fPressed);
        set("touchPadJustReleased", fJustReleased);
        #end

        // Bring variables if provided
        if(varsToBring != null)
        {
            for(key in Reflect.fields(varsToBring))
            {
                key = key.trim();
                set(key, Reflect.field(varsToBring, key));
            }
            varsToBring = null;
        }
    }

    public function executeCode(?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):TeaCall
    {
        if(funcToRun == null) return null;
        if(!exists(funcToRun))
        {
            #if LUA_ALLOWED
            FunkinLua.luaTrace(origin + " - No HScript function named: " + funcToRun, false,false,FlxColor.RED);
            #else
            PlayState.instance.addTextToDebug(origin + " - No HScript function named: " + funcToRun, FlxColor.RED);
            #end
            return null;
        }

        var callValue = call(funcToRun, funcArgs);
        if(!callValue.succeeded)
        {
            var e = callValue.exceptions[0];
            if(e != null)
            {
                var msg:String = e.toString();
                #if LUA_ALLOWED
                if(parentLua != null) FunkinLua.luaTrace(origin + ":" + parentLua.lastCalledFunction + " - " + msg,false,false,FlxColor.RED);
                #end
                PlayState.instance.addTextToDebug(origin + " - " + msg, FlxColor.RED);
            }
            return null;
        }
        return callValue;
    }

    public function executeFunction(funcToRun:String = null, funcArgs:Array<Dynamic>):TeaCall
    {
        if(funcToRun == null) return null;
        return call(funcToRun, funcArgs);
    }

    override public function destroy()
    {
        origin = null;
        #if LUA_ALLOWED
        parentLua = null;
        #end
        super.destroy();
    }
}

class CustomFlxColor
{
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

    public static function fromInt(Value:Int):Int return cast FlxColor.fromInt(Value);
    public static function fromRGB(Red:Int, Green:Int, Blue:Int, Alpha:Int=255):Int return cast FlxColor.fromRGB(Red,Green,Blue,Alpha);
    public static function fromRGBFloat(Red:Float, Green:Float, Blue:Float, Alpha:Float=1):Int return cast FlxColor.fromRGBFloat(Red,Green,Blue,Alpha);
    public static function fromHSB(Hue:Float, Sat:Float, Brt:Float, Alpha:Float=1):Int return cast FlxColor.fromHSB(Hue,Sat,Brt,Alpha);
    public static function fromHSL(Hue:Float, Sat:Float, Light:Float, Alpha:Float=1):Int return cast FlxColor.fromHSL(Hue,Sat,Light,Alpha);
    public static function fromString(str:String):Int return cast FlxColor.fromString(str);
}
#end