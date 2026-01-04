package psychlua;

import flixel.FlxBasic;
import objects.Character;
import psychlua.LuaUtils;
import psychlua.CustomSubstate;
import flixel.FlxG;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.addons.display.FlxRuntimeShader;
import openfl.filters.ShaderFilter;
import objects.Note;

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
        if(parent != null) {
            this.origin = parent.scriptName;
            this.modFolder = parent.modFolder;
        }
        #end

        if(scriptFile != null && scriptFile.length > 0) {
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

        // --- CLASSES ---
        set('FlxG', FlxG);
        set('FlxMath', FlxMath);
        set('FlxSprite', flixel.FlxSprite);
        set('FlxCamera', flixel.FlxCamera);
        set('PsychCamera', backend.PsychCamera);
        set('FlxTimer', FlxTimer);
        set('FlxTween', FlxTween);
        set('FlxEase', FlxEase);
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
        set('Note', Note);
        set('CustomSubstate', CustomSubstate);
        #if (!flash && sys)
        set('FlxRuntimeShader', FlxRuntimeShader);
        #end
        set('ShaderFilter', ShaderFilter);
        set('StringTools', StringTools);

        #if flxanimate
        set('FlxAnimate', FlxAnimate);
        #end

        // --- VARIABLES / FUNCTIONS ---
        var getVar = function(name:String) {
            return if(PlayState.instance.variables.exists(name)) PlayState.instance.variables.get(name) else null;
        };

        var setVar = function(name:String, value:Dynamic) {
            PlayState.instance.variables.set(name, value);
            return value;
        };

        var removeVar = function(name:String) {
            if(PlayState.instance.variables.exists(name)) {
                PlayState.instance.variables.remove(name);
                return true;
            }
            return false;
        };

        var debugPrint = function(text:String, ?color:Int = FlxColor.WHITE) {
            PlayState.instance.addTextToDebug(text, color);
        };

        // --- MOD SETTINGS ---
        var getModSetting = function(saveTag:String, ?modName:String = null) {
            if(modName == null) {
                if(this.modFolder == null) {
                    debugPrint('getModSetting: Argument #2 is null and script is not inside a packed Mod folder!', FlxColor.RED);
                    return null;
                }
                modName = this.modFolder;
            }
            return LuaUtils.getModSetting(saveTag, modName);
        };

        // --- RANDOM RANGE ---
        set('randomRange', function(min:Float, max:Float) {
            return min + Math.random() * (max - min);
        });

        // --- SOUND HELPERS ---
        set('playSound', function(name:String, ?volume:Float = 1, ?loop:Bool = false) {
            if(name == null) return null;
            var s:FlxSound = FlxG.sound.play(Paths.sound(name), volume, loop);
            return s;
        });

        set('stopSound', function(sound:FlxSound) {
            if(sound != null) sound.stop();
        });

        set('setVolume', function(sound:FlxSound, volume:Float) {
            if(sound != null) sound.volume = volume;
        });

        // --- VARIABLE HELPERS ---
        set('getVar', getVar);
        set('setVar', setVar);
        set('removeVar', removeVar);
        set('debugPrint', debugPrint);
        set('getModSetting', getModSetting);

        // --- KEYS ---
        set('keyJustPressed', function(name:String = '') {
            name = name.toLowerCase();
            switch(name) {
                case 'left': return Controls.instance.NOTE_LEFT_P;
                case 'down': return Controls.instance.NOTE_DOWN_P;
                case 'up': return Controls.instance.NOTE_UP_P;
                case 'right': return Controls.instance.NOTE_RIGHT_P;
                default: return Controls.instance.justPressed(name);
            }
        });

        set('keyPressed', function(name:String = '') {
            name = name.toLowerCase();
            switch(name) {
                case 'left': return Controls.instance.NOTE_LEFT;
                case 'down': return Controls.instance.NOTE_DOWN;
                case 'up': return Controls.instance.NOTE_UP;
                case 'right': return Controls.instance.NOTE_RIGHT;
                default: return Controls.instance.pressed(name);
            }
        });

        set('keyReleased', function(name:String = '') {
            name = name.toLowerCase();
            switch(name) {
                case 'left': return Controls.instance.NOTE_LEFT_R;
                case 'down': return Controls.instance.NOTE_DOWN_R;
                case 'up': return Controls.instance.NOTE_UP_R;
                case 'right': return Controls.instance.NOTE_RIGHT_R;
                default: return Controls.instance.justReleased(name);
            }
        });

        // --- GAMEPAD ---
        set('anyGamepadJustPressed', function(name:String) return FlxG.gamepads.anyJustPressed(name));
        set('anyGamepadPressed', function(name:String) return FlxG.gamepads.anyPressed(name));
        set('anyGamepadReleased', function(name:String) return FlxG.gamepads.anyJustReleased(name));

        set('gamepadAnalogX', function(id:Int, ?leftStick:Bool = true) {
            var c = FlxG.gamepads.getByID(id);
            if(c == null) return 0.0;
            return c.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
        });

        set('gamepadAnalogY', function(id:Int, ?leftStick:Bool = true) {
            var c = FlxG.gamepads.getByID(id);
            if(c == null) return 0.0;
            return c.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
        });

        set('gamepadJustPressed', function(id:Int, name:String) {
            var c = FlxG.gamepads.getByID(id);
            return c != null && Reflect.getProperty(c.justPressed, name) == true;
        });

        set('gamepadPressed', function(id:Int, name:String) {
            var c = FlxG.gamepads.getByID(id);
            return c != null && Reflect.getProperty(c.pressed, name) == true;
        });

        set('gamepadReleased', function(id:Int, name:String) {
            var c = FlxG.gamepads.getByID(id);
            return c != null && Reflect.getProperty(c.justReleased, name) == true;
        });

        // --- TOUCHPAD (MOBILE) ---
        #if LUA_ALLOWED && mobile
        set("addTouchPad", (DPadMode:String, ActionMode:String) -> {
            PlayState.instance.makeLuaTouchPad(DPadMode, ActionMode);
            PlayState.instance.addLuaTouchPad();
        });

        set("removeTouchPad", () -> {
            PlayState.instance.removeLuaTouchPad();
        });

        set("touchPadJustPressed", function(button:Dynamic):Bool {
            if(PlayState.instance.luaTouchPad == null) return false;
            return PlayState.instance.luaTouchPadJustPressed(button);
        });

        set("touchPadPressed", function(button:Dynamic):Bool {
            if(PlayState.instance.luaTouchPad == null) return false;
            return PlayState.instance.luaTouchPadPressed(button);
        });

        set("touchPadJustReleased", function(button:Dynamic):Bool {
            if(PlayState.instance.luaTouchPad == null) return false;
            return PlayState.instance.luaTouchPadJustReleased(button);
        });
        #end

        // --- IMPORT VARS ---
        if(varsToBring != null) {
            for(key in Reflect.fields(varsToBring)) {
                key = key.trim();
                set(key, Reflect.field(varsToBring, key));
            }
            varsToBring = null;
        }
    }

    public function executeCode(?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):TeaCall {
        if(funcToRun == null) return null;
        if(!exists(funcToRun)) return null;
        return call(funcToRun, funcArgs);
    }

    public function executeFunction(funcToRun:String = null, funcArgs:Array<Dynamic>):TeaCall {
        if(funcToRun == null) return null;
        return call(funcToRun, funcArgs);
    }

    override public function destroy() {
        origin = null;
        #if LUA_ALLOWED parentLua = null; #end
        super.destroy();
    }
}

class CustomFlxColor {
    public static var TRANSPARENT(default, null):Int = FlxColor.TRANSPARENT;
    public static var BLACK(default, null):Int = FlxColor.BLACK;
    public static var WHITE(default, null):Int = FlxColor.WHITE;
    public static var RED(default, null):Int = FlxColor.RED;
    public static var GREEN(default, null):Int = FlxColor.GREEN;
    public static var BLUE(default, null):Int = FlxColor.BLUE;

    public static function fromRGB(Red:Int, Green:Int, Blue:Int, Alpha:Int = 255):Int {
        return cast FlxColor.fromRGB(Red, Green, Blue, Alpha);
    }

    public static function fromRGBFloat(Red:Float, Green:Float, Blue:Float, Alpha:Float = 1):Int {
        return cast FlxColor.fromRGBFloat(Red, Green, Blue, Alpha);
    }
}
#end