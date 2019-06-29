/*
 * cc-angler - Mod to provide specific controller inputs
 * Written starting in 2019 by contributors (see CREDITS.txt)
 * To the extent possible under law, the author(s) have dedicated all copyright and related and neighboring rights to this software to the public domain worldwide. This software is distributed without any warranty.
 * You should have received a copy of the CC0 Public Domain Dedication along with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 */

/*
 * Angler Configuration File
 * This configures the angles available to you, and how they're accessed,
 *  in the form angler.angles["KeyX"] = ["left", 90];
 * Valid sticks are "left" and "right".
 * An angle of 0 is directly to the right.
 */

angler.angles["KeyT"] = ["left", -90];
angler.angles["KeyF"] = ["left", -180];
angler.angles["KeyG"] = ["left", 90];
angler.angles["KeyH"] = ["left", 0];
angler.angles["KeyI"] = ["right", -90];
angler.angles["KeyJ"] = ["right", -180];
angler.angles["KeyK"] = ["right", 90];
angler.angles["KeyL"] = ["right", 0];

// If enabled, Angler will tell you about keys being pressed.
angler.tellMeAboutKeys = false;

// To get rid of this line, get rid of this line.
alert("Please edit the assets/angler-config.js file to set the angles you want to use (and get rid of this text!)");
