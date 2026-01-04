package states;

import flixel.FlxSubState;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import lime.app.Application;
import flixel.addons.transition.FlxTransitionableState;

class FlashingState extends MusicBeatState
{
    public static var leftState:Bool = false;

    var warnText:FlxText;
    var bg:FlxSprite;

    override function create()
    {
        super.create();

        // Fundo preto com fade-in suave
        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0;
        add(bg);
        FlxTween.tween(bg, { alpha: 1 }, 0.5, { ease: FlxEase.quadOut });

        // Texto de aviso
        #if mobile
        var warningStr:String = "Hey, watch out!\nThis Mod contains flashing lights!\nPress A to disable them or go to Options.\nPress B to ignore.\nYou've been warned!";
        #else
        var warningStr:String = "Hey, watch out!\nThis Mod contains flashing lights!\nPress ENTER to disable them or go to Options.\nPress ESCAPE to ignore.\nYou've been warned!";
        #end

        warnText = new FlxText(0, 0, FlxG.width, warningStr, 32);
        warnText.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER);
        warnText.alpha = 0; // Começa invisível
        warnText.screenCenter(Y);
        add(warnText);

        // Fade-in do texto
        FlxTween.tween(warnText, { alpha: 1 }, 1, { ease: FlxEase.quadOut });

        controls.isInSubstate = false;

        #if mobile
        addTouchPad("NONE", "A_B");
        #end
    }

    override function update(elapsed:Float)
    {
        if (!leftState)
        {
            var back:Bool = controls.BACK;
            if (controls.ACCEPT || back)
            {
                leftState = true;
                FlxTransitionableState.skipNextTransIn = true;
                FlxTransitionableState.skipNextTransOut = true;

                if (!back)
                {
                    ClientPrefs.data.flashing = false;
                    ClientPrefs.saveSettings();
                    FlxG.sound.play(Paths.sound('confirmMenu'));

                    // Suaviza a saída com um pequeno flicker + fade
                    FlxFlicker.flicker(warnText, 1, 0.1, false, true, function(flk:FlxFlicker)
                    {
                        FlxTween.tween(bg, { alpha: 0 }, 0.5);
                        FlxTween.tween(warnText, { alpha: 0 }, 0.5, {
                            onComplete: function(twn:FlxTween)
                            {
                                MusicBeatState.switchState(new TitleState());
                            }
                        });
                    });
                }
                else
                {
                    FlxG.sound.play(Paths.sound('cancelMenu'));

                    // Apenas fade-out suave
                    FlxTween.tween(bg, { alpha: 0 }, 0.5);
                    FlxTween.tween(warnText, { alpha: 0 }, 0.5, {
                        onComplete: function(twn:FlxTween)
                        {
                            MusicBeatState.switchState(new TitleState());
                        }
                    });
                }
            }
        }

        super.update(elapsed);
    }
}