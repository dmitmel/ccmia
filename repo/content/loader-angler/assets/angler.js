/*
 * cc-angler - Mod to provide specific controller inputs
 * Written starting in 2019 by contributors (see CREDITS.txt)
 * To the extent possible under law, the author(s) have dedicated all copyright and related and neighboring rights to this software to the public domain worldwide. This software is distributed without any warranty.
 * You should have received a copy of the CC0 Public Domain Dedication along with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 */

window.angler = {};

(function () {
 // A table from keys to their corresponding angles.
 angler.angles = {};
 angler.tellMeAboutKeys = false;
 angler.gamepad = {
  index: 0,
  id: "Geometrix 5-A Advanced Gaming Control Unit",
  buttons: [],
  axes: []
 };

 var sticks = {
  left: 0,
  right: 2
 };

 for (var i = 0; i < 16; i++)
  angler.gamepad.buttons.push(0);
 for (var i = 0; i < 4; i++)
  angler.gamepad.axes.push(0);

 var stickActiveAngles = {
  left: {},
  right: {}
 };

 var recalculateStick = function (stick) {
  var totals = [0, 0];
  for (n in stickActiveAngles[stick]) {
   var vec = stickActiveAngles[stick][n];
   for (var i = 0; i < totals.length; i++)
    totals[i] += vec[i];
  }
  for (var i = 0; i < totals.length; i++)
   angler.gamepad.axes[sticks[stick] + i] = totals[i];
 };

 window.addEventListener("keydown", function (ev) {
  if (angler.tellMeAboutKeys) {
   alert(ev.code);
   return;
  }
  if (ev.code in angler.angles) {
   ev.preventDefault();
   var angle = angler.angles[ev.code];
   var angleRad = (angle[1] / 180) * Math.PI;
   stickActiveAngles[angle[0]][ev.code] = [Math.cos(angleRad), Math.sin(angleRad)];
   recalculateStick(angle[0]);
  }
 }, false);

 window.addEventListener("keyup", function (ev) {
  if (ev.code in angler.angles) {
   ev.preventDefault();
   var angle = angler.angles[ev.code];
   delete stickActiveAngles[angle[0]][ev.code];
   recalculateStick(angle[0]);
  }
 }, false);

 if (navigator.getGamepads) {
  navigator.anglerRealGetGamepads = navigator.getGamepads;
 } else if (navigator.webkitGetGamepads) {
  navigator.anglerRealGetGamepads = navigator.webkitGetGamepads;
 }

 navigator.getGamepads = function () {
  var x = [];
  var y = navigator.anglerRealGetGamepads();
  for (var xd = 0; xd < y.length; xd++)
   x.push(y[xd]);
  angler.gamepad.index = y.length;
  x.push(angler.gamepad);
  return x;
 };

})();
